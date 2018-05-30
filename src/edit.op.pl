#!/usr/bin/perl -w
#
# LICENSE: This software was developed at the Maryland State Department
# of Education by employees of the State Government in the course of their
# official duties. Pursuant to Title 17 Section 105 of the U.S. Code,
# this software is not subject to copyright protection in the United
# States and is in the public domain.
#
# To the extent that any copyright protections may be considered to be
# held by the authors of this software in jurisdictions outside the U.S.,
# the authors hereby waive those protections and dedicate the software to
# the public domain. According to Gnu.org, public domain is compatible
# with the GNU General Public License (GPL).
#
use strict ;
use warnings ;
use QtiXml ;

my $start_at = shift ;
if ( !defined $start_at || $start_at eq '-help')  {
	print "Usage: $0 start-number\n" ;
	print "Example: $0 0 (starts at the beginning)\n" ;
	print "Purpose: review (and edit) raw text files to prepare for building content packages.\n" ;
	print "(Run from the directory where in.csv and the raw text files are located.)\n" ;
	exit ( 0) ;
}

#
# the in.csv file must exist and be readable in the directory from which the script is run
# the current directory, where raw text files are located, must be writeable (croak if not)
my $csv_in = 'in.csv' ;
my $lnum = 0 ;

# for items:
my %inbound = () ;									  # key = identifier (for all). content = line number in original CSV file
my %rootfile = () ;									 # content = original source of the file that should be used ... if not TXT, make one
my %correct = () ;									  # content = {responseDeclaration} -> {correctResponse} -> {value}
my %error_identifiers = () ;			# content = the error that occurred (package won't be built if any error exists)

# for shared stimuli and other dependencies:
my %shared_stimulus = () ;					  # key = stimulus identifier, content = list of MDV IDENTs (comma-delimited) that use it in this package
my %shared_rootfile = () ;					  # content = source of the file that should be used ... if not TXT, make one
my %dependent_item = () ;					   # key = IDENT of item (key of inbound): shared stimulus that it uses (reverse of shared_stimulus)

#
# read in.csv for the list of identifiers we need to check
# and then call edit_txt_file() on each file, possibly picking up in
# the middle for a very large number of item or shared stimulus files.
#
open ( my $fh, "<", $csv_in) or die "Can't open $csv_in: $!. You must start from the raw text file directory.\n" ;
while ( <$fh>)  {
	my $s = $_ ;
	$s =~ s/^\s+//g ;	   # strip leading and trailing white space,
	$s =~ s/\s+$//g ;	   # but otherwise assume CSV format is valid
	$lnum++ ;
	my ( $item, $correct, $passage) = split ( /\,/, $s, 3) ;
	#
	# file layout (CSV):
	# column 1: the item identifier (in our case, this was something like MDV22221)
	# column 2: the correct answer for multiple-choice items (integer: A=1, B=2, C=3, D=4) or 0 if constructed response
	# column 3: shared stimulus, if any, to attach to the item (0 if no shared stimulus)
	#
	$inbound  {$item} = $lnum ;
	$correct  {$item} = $correct ;						  # not needed in edit.op.pl, but preserved
	$rootfile {$item} = need_ident ( $item) ;
}
close ( $fh) || warn "$csv_in close failed: $!" ;

#
# Here, all items need to be text files that can be edited: scan for shared stimuli
#
check_shared_stimuli_in_txt () ;
for my $el ( keys %shared_stimulus)  {
	$shared_rootfile{$el} = need_stimulus_ident ( $el) ;
}

#
# check content in text files initially
#
( keys %inbound > 0 || keys %shared_stimulus > 0) && do {
	my ( $i, $move_forward) = ( 1, 1) ;

	ITEM: for my $k ( sort keys %inbound)  {
		my $nKeys = keys %inbound ;
		syswrite STDERR, "\r$i of $nKeys: $k " ; $i++ ;
		#
		# advance to the argument number so we can pick up in the middle
		# (useful if many items are being edited)
		next ITEM if ( $move_forward == 1 && $start_at ne '0' && $k ne $start_at) ;
		$move_forward = 0 if ( $k eq $start_at) ;
		#
		# we are here: $k is the file we want to edit
		if ( $rootfile{$k} =~ m/\.o$/ && $rootfile{$k} !~ m/\//)  {
			syswrite STDERR, "\n" ;
			edit_txt_file ( $rootfile{$k}) ;		# function is exported from QtiXml.pm
			syswrite STDERR, "\n" ;
		}
	}
	$i = 1 ;
	STIM: for my $k ( sort keys %shared_stimulus)  {
		my $nKeys = keys %shared_stimulus ;
		syswrite STDERR, "\r$i of $nKeys: $k " ; $i++ ;
		next STIM if ( $move_forward == 1 && $start_at ne '0' && $k ne $start_at) ;
		$move_forward = 0 if ( $k eq $start_at) ;

		if ( $shared_rootfile{$k} =~ m/\.p$/ && $shared_rootfile{$k} !~ m/\//)  {
			syswrite STDERR, "\n" ;
			edit_txt_file ( $shared_rootfile{$k}) ;
			syswrite STDERR, "\n" ;
		}
	}
} ;

#
# get each text file (it must be .txt in current directory) and look for USE
#
sub check_shared_stimuli_in_txt {
	for my $k ( keys %inbound)  {
		#
		# loop throught each of the ITEMS and read the text to see if a shared stimulus is used
		# in the .o file (item raw text from OCR output), this must be (at the beginning of a line):
		# USE MDVS0001 (the identifier for the stimulus is MDVS0001, which should match the in.csv)
		#
		my $start = index ( $rootfile{$k}, '/') ;
		if ( $start < 0)  {															 # has to be in the same directory
			if ( $rootfile{$k} !~ m/\.(o|p)$/)  {
				syswrite STDERR, "\n* ERROR: Upon examining $k, " . $rootfile{$k} . " is not a standard file.\n" ;
				#
				# The extension is checked: ITEM raw text files should be IDENT.o, stimuli should be IDENT.p
				#
				$error_identifiers{$k} = 'rootfile not a text file' ;
			} else {
				my $in = get_file_content ( $rootfile{$k}) ;
				#
				# read the file (get_file_content is self-expanatory, defined in QtiXml.pm)
				#
				( $in =~ m/^USE (\S+)/m) && do {
					my $this_stimulus = $1 ;						# non-white space after the word USE at line beginning
					$dependent_item{$k} = $this_stimulus ;
					if ( exists $shared_stimulus{$this_stimulus}) {
						$shared_stimulus{$this_stimulus} .= ',' . $k ;		  # possibly more than one
					} else {
						$shared_stimulus{$this_stimulus} = $k ;						 # not in our case, but keep it in mind
					}
				} ;
			}
		} else {
			syswrite STDERR, "\n* ERROR: Upon examining $k, " . $rootfile{$k} . " is not in the current directory.\n" ;
			$error_identifiers{$k} = 'rootfile not in current directory;' ;
		}
	}
}

#
# the file that defines the stimulus must be located
#
sub need_stimulus_ident {
	my $ident = shift ;
	return "$ident.p" if ( -f "$ident.p") ;
	syswrite STDERR, "\nsorry ... stimulus not found, and we can't continue without a description\n" ;
	exit ( 1) ;
}

#
# the item file that defines the identifier must be located
#
sub need_ident {
	my $ident = shift ;
	return "$ident.o" if ( -f "$ident.o") ;
	syswrite STDERR, "\n*** sorry ... item $ident not found, and we can't continue without an item description\n" ;
	exit ( 1) ;
}
