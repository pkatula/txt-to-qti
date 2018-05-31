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

use POSIX ;
use Image::Size ;
use QtiXml ;

my $job_name = shift ;
if ( ! defined $job_name || $job_name eq '-help')  {
	print "Usage: $0 job_name\n" ;
	print "Example: $0 MadeUpName\n" ;
	print "Purpose: Build a QTI content package from raw text files\n" ;
	print "(Start from the directory where in.csv and the raw text files are located.)\n" ;
	exit ( 0) ;
} else {
	print "START RUN ", $0, ' for [', $job_name, '], ', strftime ( "%A, %B %d, %H:%M %Z, %Y", localtime), "\n" ;
}

my $csv_in = 'in.csv' ;
#
# script will do all its checking and all its work first and build the package afterwards
# it will optionally include a style sheet if one if provided (but it SHOULD be provided)
#
my @work_queue = () ;
push @work_queue, 'touch style.css' if ( ! -f 'style.css') ;
push @work_queue, 'cp style.css out/asset' if ( -f 'style.css') ;


#
# use system calls to create the out directory (and item, etc., subdirectories)
check_startup_out () ;

my $lnum = 0 ;
my $epochseconds = int ( time) ;
my $epochdays = int ( $epochseconds / 86400) ;

# for all objects on import
my %res_id = () ;						# key = MDV identifier, content is the RES-number used in the manifest for import
my %manifest_resource = () ;			# key = MDV identifier, content must start with alpha and be unnique within the package
my %manifest_file_href = () ;			# identifies the file href="" for this resource, from root directory, where manifest is stored

# for items:
my %inbound = () ;						# key = identifier (for all). content = line number in original CSV file
my %rootfile = () ;						# content = original source of the file that should be used ... if not TXT, make one
my %correct = () ;						# content = {responseDeclaration} -> {correctResponse} -> {value}
my %bodytype = () ;						# content = choiceInteraction or extendedTextInteraction
my %error_identifiers = () ;			# content = the error that occurred (package won't be built if any error exist)

# for shared stimuli and other dependencies:
my %shared_stimulus = () ;				# key = stimulus identifier, content = list of MDV identifiers (comma-delimited) that use it in this package
my %shared_rootfile = () ;				# content = source of the file that should be used ... if not TXT, make one
my %dependent_image = () ;				# key = ID of the resource item or shared stimulus, content = graphic file (change dot's to - so it's a resource identifier)
my %dependent_item = () ;				# key = MDV of item (key of inbound): shared stimulus that it uses (reverse of shared_stimulus)


open ( my $fh, "<", $csv_in) or die "Can't open $csv_in: $!. You must start from the package directory.\n" ;
while ( <$fh>)  {
	chomp ;
	my $s = $_ ;
	$s =~ s/^\s+//g ;
	$s =~ s/\s+$//g ;
	$lnum++ ;
	my ( $item, $correct, $passage) = split ( /\,/, $s, 3) ;

	$inbound {$item} = $lnum ;
	$correct {$item} = $correct ;
	$res_id {$item} = "RES-OCR2-$epochdays-$lnum-$item" ;
	$res_id {$item} =~ s/\./-/g ;
	print "$item on line $lnum has resource ID " . $res_id{$item} . ": " ;
	$rootfile{$item} = need_ident ( $item) ;
	if ( item_flagged ( $rootfile{$item}))  {
		delete $inbound{$item} ;
		print $rootfile{$item}, " is flagged and will NOT be included.\n" ;
		delete $correct{$item} ;
		delete $res_id{$item} ;
		delete $rootfile{$item} ;
	} else {
		print "Using " . $rootfile{$item} . "\n" ;
	}
}
close ( $fh) || warn "$csv_in close failed: $!" ;

#
# Here, all items need to be text files that can be edited: scan for shared stimuli
#
sharing_of_stimuli:
check_shared_stimuli_in_txt () ;
for my $el ( keys %shared_stimulus)  {
	print "\n** Found shared stimulus reference: $el: " . $shared_stimulus{$el} . " **\n" ;
	$shared_rootfile{$el} = need_stimulus_ident ( $el) ;
}

#
# enforce alt tags (and existence) of all graphics
#
for my $k ( keys %inbound)  {
	my @e_array = () ;
	print "checking image dependencies for $k: " ;
	open ( my $fh, "<", $rootfile{$k}) || die "Can't open " . $rootfile{$k} . ": $!" ;
	while ( <$fh>)  {
		my $line_in = $_ ;
		( $line_in =~ m/^GRAPHIC\s+(\S+)\s/) && do {
			my $this_image = $1 ;
			$this_image =~ s/\.eps/.svg/ if ( ! -e $this_image) ;
			print ' ' . $this_image . ', ' ;
			if ( ! -e $this_image)  {
				my $msg = ' requires missing graphic: ' . $this_image . ';' ;
				print $msg ;
				if ( exists $error_identifiers{$k}) { $error_identifiers{$k} .= $msg ; } else { $error_identifiers{$k} = $msg ; }
			} else {
				$dependent_image{$k} = ( exists $dependent_image{$k}) ? $dependent_image{$k} . ',' . $this_image : $this_image ;
			}
		} ;
		( $line_in =~ m/OPTION_IMAGE\s+(\S+)\s/) && do {
			my $this_image = $1 ;
			$this_image =~ s/\.eps/.svg/ if ( ! -e $this_image) ;
			print ' ' . $this_image . ', ' ;
			if ( ! -e $this_image)  {
				my $msg = ' requires missing graphic: ' . $this_image . ';' ;
				print $msg ;
				if ( exists $error_identifiers{$k}) { $error_identifiers{$k} .= $msg ; } else { $error_identifiers{$k} = $msg ; }
			} else {
					$dependent_image{$k} = ( exists $dependent_image{$k}) ? $dependent_image{$k} . ',' . $this_image : $this_image ;
			}
		} ;
	}
	close ( $fh) ;
	print " done.\n" ;
}
for my $k ( keys %shared_stimulus)  {
	my @e_array = () ;
	print "checking image dependencies for $k: " ;
	open ( my $fh, "<", $shared_rootfile{$k}) || die "Can't open " . $shared_rootfile{$k} . ": $!" ;
	while ( <$fh>)  {
		my $line_in = $_ ;
		( $line_in =~ m/^GRAPHIC\s+(\S+)\s/) && do {
			my $this_image = $1 ;
			print $this_image . ', ' ;
			if ( ! -e $1)  {
				my $msg = ' requires missing graphic: ' . $this_image . ';' ;
				print $msg ;
				if ( exists $error_identifiers{$k}) { $error_identifiers{$k} .= $msg ; } else { $error_identifiers{$k} = $msg ; }
			} else {
				$dependent_image{$k} = ( exists $dependent_image{$k}) ? $dependent_image{$k} . ',' . $this_image : $this_image ;
			}
		} ;
		( $line_in =~ m/[ABCDEFGHJ]\s+OPTION_IMAGE\s+(\S+)\s/) && do {
			my $this_image = $1 ;
			print $this_image . ', ' ;
			if ( ! -e $this_image)  {
				my $msg = ' requires missing graphic: ' . $this_image . ';' ;
				print $msg ;
				if ( exists $error_identifiers{$k}) { $error_identifiers{$k} .= $msg ; } else { $error_identifiers{$k} = $msg ; }
			} else {
				$dependent_image{$k} = ( exists $dependent_image{$k}) ? $dependent_image{$k} . ',' . $this_image : $this_image ;
			}
		} ;
	}
	close ( $fh) ;
	print " done.\n" ;
}

#
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# all checks passed ... build package (very fast and automated)
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
if ( my $hash_count = keys %error_identifiers)  {
	print "\*\n*\n* Cannot continue because of fatal errors:\n*\n" ;
	for my $k ( keys %error_identifiers)  {
		print "  - $k has error(s): " . $error_identifiers{$k} . "\n" ;
	}
} else {
	print "*\n*\n* Creating output:\n*\n" ;

	# build each item
	for my $k ( keys %inbound) { print " - Item $k: " ; write_item_file ( $k) ; print "\n" ; }

	# build each shared stimulus
	for my $k ( keys %shared_stimulus) {print " - Shared Stimulus $k: " ; write_rubric_block ( $k) ; print "\n" ; }

	# create the manifest ... image blocks ... standalone items ... shared stimuli with dependent items ... assessment sections
	my $tmp_resource_block = '' ;

	# images used in this package

	for my $k ( keys %dependent_image) {
		my @im = split ( /\,/, $dependent_image{$k}) ;
		for my $m ( @im) {
			# filename: $m
			$res_id{$m} = $m ;
			$res_id{$m} =~ s/(\.|\_)/-/g ;		  # how we create resource identifiers for images
			# need a resource node in manifest for each of these images
			my $image_resource_block = interplay_string ( source => $manifest_template{'image_resource_block'},
				RES_ID_ON_IMPORT => $res_id{$m}, PATH_TO_IMAGE_JPG => 'asset/' . $m) ;
			$tmp_resource_block .= $image_resource_block . "\n" ;
		}
	}
	#
	# add resource for stylesheet if available
	#
	$tmp_resource_block .= interplay_string ( source => $manifest_template{'image_resource_block'},
		RES_ID_ON_IMPORT => "STY-CSS3-$epochdays-$epochseconds", PATH_TO_IMAGE_JPG => 'asset/style.css')
			if ( -f 'style.css') ;

	#
	# standalone items
	#
	for my $k ( keys %inbound)  {
		if ( ! exists $dependent_item{$k})  {
			my $dependency_refs = interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'},
				RES_OF_USED_RESOURCE => "STY-CSS3-$epochdays-$epochseconds") ;
			# doesn't use a common (shared) stimulus, but may have image dependencies
			if ( exists $dependent_image{$k})  {
				my @im = split ( /\,/, $dependent_image{$k}) ;
				for my $m ( @im)  {
					$dependency_refs .= interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'}, RES_OF_USED_RESOURCE => $res_id{$m}) ;
				}
			}
			$tmp_resource_block .= interplay_string ( source => $manifest_template{'item_resource_block'},
				RES_ID_ON_IMPORT => $res_id{$k},
				PATH_TO_ITEM_QTI_XML => 'item/' . $k . '.qti.xml',
				ITEM_INTERACTION_TYPE => $bodytype{$k},
				MDV_ITEM_ID => $k,
				DEPENDENCY_IDENTIFIERREFS => $dependency_refs) ;
		}
	}

	#
	# shared stimuli in this package
	#
	for my $k ( keys %shared_stimulus) {
		# possible that a shared stimulus has an image dependency

		my $dependency_refs = interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'},
			RES_OF_USED_RESOURCE => "STY-CSS3-$epochdays-$epochseconds") ;
		if ( exists $dependent_image{$k})  {
			my @im = split ( /\,/, $dependent_image{$k}) ;
			for my $m ( @im)  {
				$dependency_refs .= interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'}, RES_OF_USED_RESOURCE => $res_id{$m}) ;
			}
		}
		$tmp_resource_block .= interplay_string ( source => $manifest_template{'stimulus_resource_block'},
			RES_ID_ON_IMPORT => $res_id{$k},
			PATH_TO_PASSAGE_QTI_XML => 'passage/' . $k . '.qti.xml',
			MDV_ITEM_ID => $k,
			DEPENDENCY_IDENTIFIERREFS => $dependency_refs) ;
	}

	#
	# items that use a shared stimulus passage
	#
	for my $k ( keys %inbound)  {
		if ( exists $dependent_item{$k})  {
			my $dependency_refs = interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'},
				RES_OF_USED_RESOURCE => "STY-CSS3-$epochdays-$epochseconds") ;
			# doesn't use a common (shared) stimulus, but may have image dependencies
			if ( exists $dependent_image{$k})  {
				my @im = split ( /\,/, $dependent_image{$k}) ;
				for my $m ( @im)  {
					$dependency_refs .= interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'}, RES_OF_USED_RESOURCE => $res_id{$m}) ;
				}
			}
			$tmp_resource_block .= interplay_string ( source => $manifest_template{'item_resource_block'},
				RES_ID_ON_IMPORT => $res_id{$k},
				PATH_TO_ITEM_QTI_XML => 'item/' . $k . '.qti.xml',
				ITEM_INTERACTION_TYPE => $bodytype{$k},
				MDV_ITEM_ID => $k,
				DEPENDENCY_IDENTIFIERREFS => $dependency_refs) ;
		}
	}

	# this will both create the assessmentSection.xml files and add to the nodes of resources for the manifest
	$tmp_resource_block .= build_manifest_sets () ;

	my $mani = interplay_string ( source => $manifest_template{'manifest_wrap'},
		NUMERIC_MANIFEST_IDENTIFIER => "$epochdays-OCR2-$epochseconds",
		RESOURCE_BLOCKS => $tmp_resource_block) ;
	write_out ( $mani, 'out/imsmanifest.xml') ;
}

end_of_script:
for my $cmd ( @work_queue)  {
	print "$cmd\n" ;
	system ( $cmd) ;
}

print "END ", $0, ' for [', $job_name, '], ', strftime ( "%A, %B %d, %H:%M %Z, %Y", localtime), "\n" ;
exit ( 0) ;


##### SUBROUTINES #####

sub build_manifest_sets {
	if ( 0 == keys %shared_stimulus)  {
			return '' ;					 # nothing to do (either add to manifest or create section.xml files)
	}
	#
	# assessment section reference in manifest ...
	# each set of items with shared stimulus must be in its own assessmentSection
	#
	my ( $section_id_counter, $ret) = ( 1, '') ;			# resource blocks to add to manifest
	for my $k ( keys %shared_stimulus)  {
		#
		# the shared stimulus
		print "Processing shared stimulus $k ...\n" ;
		my $dependency_refs = interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'}, RES_OF_USED_RESOURCE => $res_id{$k}) ;
		my $ref_lines_in_section_xml = '' ;
		#
		# each dependent item
		my @im = split ( /\,/, $shared_stimulus{$k}) ;
		for my $m ( @im)  {
			$dependency_refs .= interplay_string ( source => $manifest_template{'dependency_identifier_ref_line'}, RES_OF_USED_RESOURCE => $res_id{$m}) ;
			my $this_reference = $res_id{$m} ;
			$this_reference =~ s/RES/REF/g ;				# can't match actual resource ID since it's just a reference to the resource
			$ref_lines_in_section_xml .= interplay_string ( source => $manifest_template{'assessment_item_ref_line'},
				REF_ID_ON_IMPORT_FOR_DEPENDENT_ITEM => $this_reference,
				PATH_TO_DEPENDENT_ITEM_FROM_ROOT => "item/$m.qti.xml") ;
		}
		#
		# add the resource block in manifest
		$ret .= interplay_string ( source => $manifest_template{'assessment_resource_block'},
			RES_ID_ON_IMPORT => "SHAR-$epochdays-OCR2-$epochseconds-$section_id_counter",
			SECTION_FILE_NAME => "section_$section_id_counter.xml",
			DEPENDENCY_IDENTIFIERREFS => $dependency_refs) ;
		#
		# build section_nn.xml
		#
		my $section_file_entirety = interplay_string ( source => $manifest_template{'assessment_section_wrap'},
			RES_SET_RESOURCE_ID_ON_INBOUND => "SHAR-$epochdays-OCR2-$epochseconds-$section_id_counter",
			PATH_TO_PASSAGE_QTI_XML_FROM_ROOT => "passage/$k.qti.xml",
			ASSESSMENT_ITEM_REF_LINES => $ref_lines_in_section_xml) ;
		my $assessment_file = interplay_string ( source => $manifest_template{'assessment_file_wrap'},
			ASSESSMENT_SECTION => $section_file_entirety) ;
		$assessment_file = interplay_string ( source => $assessment_file,
			RES_SET_RESOURCE_ID_ON_INBOUND => "SHAR-$epochdays-OCR2-$epochseconds-$section_id_counter") ;
		write_out ( $assessment_file, "out/section_$section_id_counter.xml") ;
		$section_id_counter++ ;
	}
	return $ret ;
}

#
# create a shared stimulus file as a rubricBlock node in its own file
#
sub write_rubric_block {
	my $id = shift ;
	my @ar = () ;
	#
	# read each line in
	#
	open ( my $fh, "<", $shared_rootfile{$id}) || die "Can't open " . $shared_rootfile{$id} . ": $!" ;
	while ( <$fh>)  { chomp ; push @ar, $_ ; }
	close ( $fh) ;

	my $stim_block = stimulus_only ( \@ar, 1, $#ar, 1) ;			# add 4th argument for keeping bullets
	$stim_block = '<div class="default">' . $stim_block . '</div>' ; # if ( length ( $stim_block) > 3) ;
	#
	# templates are defined in QtiXml.pm
	#
	my $template = interplay_string ( source => $rubric_block_xml_template,
		STIMULUS_MDV_ID => $id,
		STIMULUS_BLOCK => $stim_block ) ;
	write_out ( $template, "out/passage/$id.qti.xml") ;
	print " ... writing out/passage/$id.qti.xml" ;
}



#
# the item file that defines the identifier must be located
#
sub need_ident {
	my $ident = shift ;
	#
	# if the text file for the identifier is in the current directory, ask for use
	#
	( -f "$ident.o") && do {
		return "$ident.o" ;
	} ;
	print "\n*** ERROR ... item $ident not found, unable to continue without an item description\n" ;
	exit ( 10) ;
}

#
# the item file that defines the identifier must be located
#
sub need_stimulus_ident {
	my $ident = shift ;
	#
	# if the text file for the identifier is in the current directory, use it
	#
	( -f "$ident.p") && do {
		return "$ident.p" ;			 # add for auto mode after passage build to replace following two lines
	} ;
	#
	# process for cases where the shared stimulus isn't already here: may involve everything from OCR to editing text file
	#
	print "\nsorry ... stimulus not found, and we can't continue without a description\n" ;
	exit ( 21) ;
}

#
# build directories for the output of this script
#
sub check_startup_out {
	system "rm -rf out" ;
	system "mkdir out" ;
	system "mkdir out/item" ;
	system "mkdir out/asset" ;
	system "mkdir out/passage" ;
}

#
# get each text file (it must be .txt in current directory) and look for USE
#
sub check_shared_stimuli_in_txt {
	for my $k ( keys %inbound)  {
		my $start = index ( $rootfile{$k}, '/') ;
		if ( $start < 0)  {
			if ( $rootfile{$k} !~ m/\.(o|p)$/)  {
				print "\n* ERROR: Upon examining $k, " . $rootfile{$k} . " is not a standard text file.\n" ;
				$error_identifiers{$k} = 'rootfile not a text file' ;
			} else {
				my $in = get_file_content ( $rootfile{$k}) ;
				( $in =~ m/^USE (\S+)/) && do {
					my $this_stimulus = $1 ;
					$dependent_item{$k} = $this_stimulus ;
					$res_id{$this_stimulus} = "PAS-$epochdays-$epochseconds-$this_stimulus" ;
					if ( exists $shared_stimulus{$this_stimulus}) {
						$shared_stimulus{$this_stimulus} .= ',' . $k ;
					} else {
						$shared_stimulus{$this_stimulus} = $k ;
					}
				} ;
			}
		} else {
			print "\n* ERROR: Upon examining $k, " . $rootfile{$k} . " is not in the current directory.\n" ;
			$error_identifiers{$k} = 'rootfile not in current directory;' ;
		}
	}
}


sub write_item_file {
	my $id = shift ;
	my @ar = () ;
	#
	# read each line in
	#
	open ( my $fh, "<", $rootfile{$id}) || die "Can't open " . $rootfile{$id} . ": $!" ;
	while ( <$fh>)  { my $t = $_ ; $t =~ s/\r\n/ /g ; $t =~ s/\s+$//g ; $t =~ s/^\s+//g ; push @ar, $t ; }
	close ( $fh) ;
	#
	# check for malformed item: penultimate row must be either a multiple choice option letter or BUL
	#
	if ( $#ar < 1)  {
		print $rootfile{$id} . " is insufficient. Exiting now.\n" ;
		exit ( 22) ;
	} elsif ( $ar[$#ar-1] =~ m/^BUL\s/ )  {
		# we have a constructed response item - choose template - prompt is all bullets
		$bodytype { $id} = 'extendedTextInteraction' ;
		my $bullets = get_cr_bullets ( @ar) ;
		my $stim_block = stimulus_only ( \@ar, 0, $#ar - 2) ;		   # will stop at first bullet
		$stim_block = '<div class="default">' . $stim_block . '</div>' if ( length ( $stim_block) > 3) ;

		my $template = interplay_string ( source => $cr_w_stimulus_xml_template,
			ITEM_MDV_ID => $id, STIMULUS_BLOCK => $stim_block,
			BULLETS_IN_LI_LIST_PARAGRAPH_CLASS => $bullets ) ;
		write_out ( $template, "out/item/$id.qti.xml") ;
		print " ... writing out/item/$id.qti.xml" ;

	} elsif ( $ar[$#ar-1] =~ m/[CDHJ]\s/ )  {
		# we have a multiple-choice question - choose template
		$bodytype { $id} = 'choiceInteraction' ;
		if (( ! exists $correct{$id} ) || eval $correct{$id} < 1 || eval $correct{$id} > 4)  {
				# bad correct answer
				print "$id has no correct answer identified. Exiting now.\n" ;
				exit ( 23) ;
		}
		my ( $i, $choices) = ( 0, '') ;
		my $prompt = '<prompt><p class="stem_paragraph ">' . $ar[$#ar-4] . '</p></prompt>' ;
		for $i ( $#ar-3 .. $#ar)  {
			#
			# note that we should check for ABCD or FGHJ, not just the last four lines (could be a footer uncaught)
			#
			my $this = $i - $#ar + 4 ;
			my $thechoice = $ar[$i] ;
			$thechoice =~ s/^[ABCDFGHJ]\s+// ;
			$thechoice =~ s/^\*\s+// ;
			#
			# check now for formatting of answer choice options:
			# SCROLL_ATTR  text in scroll | attribution_author
			# HEADLINE	 text in headline
			# SCROLL	   text in a scroll parchment
			# SCROLL_ATTR_AFFIL  text in scroll | attribution_author | affiliation (after formatted_line_break)
			# OPTION_IMAGE graphic.jpg width height Alt-text
			#
			if ( $thechoice =~ m/^\s*SCROLL_ATTR\s+(\S.*?)\|(.*)/)  {
				$thechoice = '<div class="style_scroll "><p class="choice_paragraph ">' . $1
					. '<span class="formatted_line_break "></span>' . $2 . '</p></div>' ;
			} elsif ( $thechoice =~ m/^\s*SCROLL_ATTR_AFFIL\s+(\S.*?)\|(.*?)\|(.*)/)  {
				$thechoice = '<div class="style_scroll "><p class="choice_paragraph ">' . $1 . '</p>'
					. '<p class="attribution_author ">' . $2 . '<span class="formatted_line_break "></span>' . $3 . '</p></div>' ;
			} elsif ( $thechoice =~ m/\s*SCROLL\s+(\S.*)/)  {
				$thechoice = '<div class="style_scroll "><p class="choice_paragraph ">' . $1 . '</p></div>' ;
			} elsif ( $thechoice =~ m/\s*HEADLINE\s+(\S.*)/)  {
				$thechoice = '<div class="style_newsclip "><p class="choice_paragraph headline_para ">' . $1 . '</p></div>' ;
			} elsif ( $thechoice =~ m/\s*OPTION_IMAGE\s+(\S.*)\s+(\d+)\s+(\d+)\s+(\S.*)/)  {
				my ( $img_file, $img_width, $img_height, $alt_text) = ( $1, eval $2, eval $3, $4) ;
				$img_file =~ s/\.eps/.svg/ if ( ! -f $img_file) ;			   # possibly a substitute
				if ( ! -e $img_file)  {
					print "\nERROR: requires missing graphic $img_file\n" ;
					exit ( 10) ;
				}
				push @work_queue, "cp $img_file out/asset" ;
				my ( $act_width, $act_height) = ( 400, 400) ;
				( $act_width, $act_height) =  imgsize ( $img_file) if ( $img_file =~ m/\.jpg$/) ;
				my $use_width = ( $img_width < 10 ? ( $act_width < 10 ? 400 : $act_width ) : $img_width) ;
				my $use_height = ( $img_height < 10 ? ( $act_height < 10 ? 400 : $act_height ) : $img_height) ;
				$thechoice = '<div class="option_image "><img src="../asset/' . $img_file . '" alt="'
					. strip_quotes ( $alt_text) . '" height="' . $use_height . '" width="' . $use_width . '" /></div>' ;
			} else {
				$thechoice = '<p class="choice_paragraph ">' . $thechoice . '</p>' ;
			}
			$choices .= '<simpleChoice identifier="i' . "$this" . '" class="block_choice ">' . $thechoice . '</simpleChoice>' ;
		}
		my $stim_block = stimulus_only ( \@ar, 0, $#ar - 5) ;
		$stim_block = '<div class="default">' . $stim_block . '</div>' if ( length ( $stim_block) > 3) ;
		my $template = interplay_string ( source => $mc4_w_stimulus_xml_template,
			ITEM_MDV_ID => $id, CHOICES => $choices,
			CORRECT_RESPONSE_IDENTIFIER => 'i' . $correct{$id},
			PROMPT => $prompt, STIMULUS_BLOCK => $stim_block) ;
		write_out ( $template, "out/item/$id.qti.xml") ;
		print " ... writing out/item/$id.qti.xml" ;

	} else {
		print $rootfile{$id} . " is not a recognized format. Exiting now.\n" ;
		exit ( 22) ;
	}
}

sub write_out {
	my ( $string, $filename) = ( $_[0], $_[1]) ;
	open ( my $fh, ">", $filename) || die "Can't open $filename for writing: $!" ;
	$string =~ s/\s+\<span/ENFORCETHISSPACE<span/g ;
	$string =~ s/\s+\</</g ;
	$string =~ s/ENFORCETHISSPACE/ /g ;
	$string =~ s/decoration:underline/decoration_underline/g ;
	$string =~ s/style:italic/style_italic/g ;
	print $fh $string ;
	close ( $fh) ;
}

sub stimulus_only {
	my $array_ref = shift ;
	my ( $firstline, $lastline) = ( $_[0], $_[1]) ;
	my $keep_bullets = ( defined $_[2] ? $_[2] : 0) ;
	my $now_in_list = 0 ;
	my $ret = '' ;
	return $ret if ( $lastline < $firstline) ;

	my @ar_in = @{$array_ref} ;
	for ( my $i = $firstline ; $i <= $lastline ; $i++)  {

		if ( $ar_in[$i] =~ m/^EXCERPT_WITH_ATTR\s+(\S.*)/)  {
			my $excerpt = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $attribution = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose excerpt_with_attribution "><p class="passage_para ">' . $excerpt . '</p> '
					. ' <p class="attribution_author ">' . $attribution . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^HEADLINE\s+(\S.*)/)  {
			my $headline_text = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="headline_para ">' . $headline_text . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^NEWSCLIP\s+(\S.*)/)  {
			my $clip_text = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="news_para ">' . $clip_text . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^NEWS_WITH_ATTR\s+(\S.*)/)  {
			my $excerpt = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $attribution = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="news_para ">' . $excerpt . '</p> '
					. ' <p class="attribution_author ">' . $attribution . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^NEWS_HEADLINE_LEAD_ATTR\s+(\S.*)/)  {
			my $headline_text = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $lead = $ar_in[$i] ;
			$i++ ;
			my $attr = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="headline_para ">' . $headline_text . '</p>'
					. '<p class="news_para ">' . $lead . '</p>'
					. '<p class="attribution_author ">' . $attr . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^HEADLINE_SUBHEAD\s+(\S.*)/)  {
			my $headline_text = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $subheading = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="headline_para ">' . $headline_text . '</p>'
					. '<p class="news_subhead ">' . $subheading . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^CLIP2\s+(\S.*)/)  {
			my $clip_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $clip_para_2 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip ">'
					. '<p class="headline_para ">' . $clip_para_1 . '</p> '
					. '<p class="passage_para ">' . $clip_para_2 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^CLIP3\s+(\S.*)/)  {
			my $clip_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $clip_para_2 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_3 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip ">'
					. '<p class="headline_para ">' . $clip_para_1 . '</p> '
					. '<p class="passage_para ">' . $clip_para_2 . '</p>'
					. '<p class="passage_para ">' . $clip_para_3 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^CLIP4\s+(\S.*)/)  {
			my $clip_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $clip_para_2 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_3 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_4 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip ">'
					. '<p class="headline_para ">' . $clip_para_1 . '</p> '
					. '<p class="passage_para ">' . $clip_para_2 . '</p>'
					. '<p class="passage_para ">' . $clip_para_3 . '</p>'
					. '<p class="passage_para ">' . $clip_para_4 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^CLIP5\s+(\S.*)/)  {
			my $clip_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $clip_para_2 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_3 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_4 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_5 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip ">'
					. '<p class="headline_para ">' . $clip_para_1 . '</p> '
					. '<p class="passage_para ">' . $clip_para_2 . '</p>'
					. '<p class="passage_para ">' . $clip_para_3 . '</p>'
					. '<p class="passage_para ">' . $clip_para_4 . '</p>'
					. '<p class="passage_para ">' . $clip_para_5 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^CLIP6\s+(\S.*)/)  {
			my $clip_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $clip_para_2 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_3 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_4 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_5 = $ar_in[$i] ;
			$i++ ;
			my $clip_para_6 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip ">'
					. '<p class="headline_para ">' . $clip_para_1 . '</p> '
					. '<p class="passage_para ">' . $clip_para_2 . '</p>'
					. '<p class="passage_para ">' . $clip_para_3 . '</p>'
					. '<p class="passage_para ">' . $clip_para_4 . '</p>'
					. '<p class="passage_para ">' . $clip_para_5 . '</p>'
					. '<p class="passage_para ">' . $clip_para_6 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^NEWSCLIP_HEAD_LEAD\s+(\S.*)/)  {
			my $headline_text = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $the_lead = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="headline_para ">' . $headline_text . '</p>'
					. '<p class="news_para ">' . $the_lead . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^NEWSCLIP_HEAD_LEAD_ATTR_FOOT\s+(\S.*)/)  {
			my $headline_text = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $lead = $ar_in[$i] ;
			$i++ ;
			my $attr = $ar_in[$i] ;
			$i++ ;
			my $foot = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="headline_para ">' . $headline_text . '</p>'
					. '<p class="news_para ">' . $lead . '</p>'
					. '<p class="attribution_author ">' . $attr . '</p>'
					. '</div>' . '<div class="clip_footnote "><p class="news_para ">' . $foot . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^NEWSCLIP_ATTR_FOOT\s+(\S.*)/)  {
			my $lead = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $attr = $ar_in[$i] ;
			$i++ ;
			my $foot = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose style_newsclip "><p class="news_para ">' . $lead . '</p>'
					. '<p class="attribution_author ">' . $attr . '</p>'
					. '</div>' . '<div class="clip_footnote "><p class="news_para ">' . $foot . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^LEAD\s(\S.*)/)  {
			my $lead_in = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$ret .= '<p class="lead_in ">' . $lead_in . '</p>' ;

		} elsif ( $ar_in[$i] =~ m/^TITLE\s(\S.*)/)  {
			my $title_text = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$ret .= '<p class="title_graf ">' . $title_text . '</p>' ;

		} elsif ( $ar_in[$i] =~ m/^BOX\s+(\S.*)/)  {
			my $excerpt = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$ret .= '<div class="passage "><div class="prose boxed_info ">'
					. '<p class="passage_para ">' . $excerpt . '</p></div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^BOX2\s+(\S.*)/)  {
			my $boxed_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $boxed_para_2 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose boxed_info ">'
					. '<p class="passage_para ">' . $boxed_para_1 . '</p> '
					. '<p class="passage_para ">' . $boxed_para_2 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^BOX3\s+(\S.*)/)  {
			my $boxed_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $boxed_para_2 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_3 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose boxed_info ">'
					. '<p class="passage_para ">' . $boxed_para_1 . '</p> '
					. '<p class="passage_para ">' . $boxed_para_2 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_3 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^BOX4\s+(\S.*)/)  {
			my $boxed_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $boxed_para_2 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_3 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_4 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose boxed_info ">'
					. '<p class="passage_para ">' . $boxed_para_1 . '</p> '
					. '<p class="passage_para ">' . $boxed_para_2 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_3 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_4 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^BOX5\s+(\S.*)/)  {
			my $boxed_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $boxed_para_2 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_3 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_4 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_5 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose boxed_info ">'
					. '<p class="passage_para ">' . $boxed_para_1 . '</p> '
					. '<p class="passage_para ">' . $boxed_para_2 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_3 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_4 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_5 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^BOX6\s+(\S.*)/)  {
			my $boxed_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $boxed_para_2 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_3 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_4 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_5 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_6 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose boxed_info ">'
					. '<p class="passage_para ">' . $boxed_para_1 . '</p> '
					. '<p class="passage_para ">' . $boxed_para_2 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_3 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_4 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_5 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_6 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^BOX7\s+(\S.*)/)  {
			my $boxed_para_1 = $1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$i++ ;
			my $boxed_para_2 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_3 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_4 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_5 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_6 = $ar_in[$i] ;
			$i++ ;
			my $boxed_para_7 = $ar_in[$i] ;
			$ret .= '<div class="passage "><div class="prose boxed_info ">'
					. '<p class="passage_para ">' . $boxed_para_1 . '</p> '
					. '<p class="passage_para ">' . $boxed_para_2 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_3 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_4 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_5 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_6 . '</p>'
					. '<p class="passage_para ">' . $boxed_para_7 . '</p>' . '</div></div>' ;

		} elsif ( $ar_in[$i] =~ m/^IGNORE/)  {
			# skipping it
			my $dummy = 1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }

		} elsif ( $ar_in[$i] =~ m/^USE/)  {
			# skipping it
			my $dummy = 1 ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }

		} elsif ( $ar_in[$i] =~ m/^BUL\s+(\S.*)/)  {
			# we're done if we encounter a CR bullet
			my $the_bullet = $1 ;
			return $ret if ( $keep_bullets < 1) ;
#			print "\nERROR: Check bullets in file\n" ;
#			exit ( 31) ;
#			}
			#
			# TODO: get the list in the stimulus
			#
			if ( ! $now_in_list)  {
				$ret .= '<ul class="ulclass_1 ">' ;
			}
			$ret .= '<li class="list_paragraph ">' . $the_bullet . '</li>' ;
			$now_in_list = 1 ;

		} elsif ( $ar_in[$i] =~ m/^GRAPHIC\s+([\w\.]+)\s+(\d+)\s+(\d+)\s+(\w.*)/)  {
			my ( $img_file, $width, $height, $alt_text) = ( $1, eval $2, eval $3, $4) ;
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
			$alt_text = 'alt="' . strip_quotes ( $alt_text) . '"' ;
			$img_file =~ s/\.eps/.svg/ if ( ! -f $img_file) ;			   # possibly a substitute
			if ( ! -e $img_file)  {
				print "\nERROR: requires missing graphic $img_file\n" ;
				exit ( 10) ;
			}
			push @work_queue, "cp $img_file out/asset" ;
			my ( $act_width, $act_height) = ( 400, 400) ;
			( $act_width, $act_height) =  imgsize ( $img_file) if ( $img_file =~ m/\.jpg$/) ;
			my $use_width = ( $width < 10 ? ( $act_width < 10 ? 400 : $act_width ) : $width) ;
			my $use_height = ( $height < 10 ? ( $act_height < 10 ? 400 : $act_height ) : $height) ;
			$ret .= '<div class="stimulus_image "><p class="center_for_image ">'
					. '<img width="' . $use_width . '" src="../asset/' . $img_file
					. '" height="' . $use_height . '" '	 . $alt_text . ' /></p></div>' ;

		} elsif ( $ar_in[$i] =~ m/^TABLE_WITH_TITLE\s+(\d+)\s+(\d+)\s+(\d)\s+(\w.*)/)  {
			my ( $columns, $header_rows, $data_rows, $table_title) = ( eval $1, eval $2, eval $3, $4) ;
			if ( $table_title eq 'TITLE' || $table_title eq 'TABLE')  { $table_title = 'THIS IS DUMMY TEXT FOR A TABLE TITLE' ; }
			$ret .= '<div class="table_block "><table class="table table_style_1 "><caption>' . $table_title . '</caption>' ;
			$i++ ;
			( $header_rows > 0) && do {
				$ret .= '<thead>' ;
				for my $j ( 1 .. $header_rows)  {
					my @cols = () ;
					for my $c ( 1 .. $columns )  {
						push @cols, $ar_in[$i] ;
						$i++ ;
					}
					if ( $#cols != $columns - 1)  {
						print "\n\n*** ERROR: Table is malformed\n\n" ;
						exit ( 10) ;
					}
					$ret .= '<tr class="trclass tr_style_0 "><th class="thclass th_style_1 ">' ;
					$ret .= join '</th><th class="thclass th_style_1 ">', @cols ;
					$ret .= '</th></tr>' ;
				}
				$ret .= '</thead>' ;
			} ;
			$ret .= '<tbody> ' ;
			for my $j ( 1 .. $data_rows)  {
				$ret .= '<tr class="trclass tr_style_1 "><td class="tdclass td_style_1 ">' ;
				my @cols = () ;
				for my $c ( 1 .. $columns )  {
					push @cols, $ar_in[$i] ;
					$i++ ;
				}
				if ( $#cols != $columns - 1)  {
					print "\n\n*** ERROR: Table is malformed\n\n" ;
					exit ( 10) ;
				}
				$ret .= join '</td><td class="tdclass td_style_1 ">', @cols ;
				$ret .= '</td></tr>' ;
			}
			$ret .= '</tbody></table></div> ' ;

		} elsif ( $ar_in[$i] =~ m/^TABLE_GENERAL/)  {
			my $tfoot_exception = 0 ;			# SEE NOTE UNDER FOOTER -- HTML5 change and vendor disparity ???
			my ( $caption, $inhead, $inbody, $inrow, $apparent_columns, $max_columns) = ( '', 0, 0, 0, 1, 1) ;
			$ret .= '<div class="table_block "><table class="table table_style_1 ">' ;
			$i++ ;
			#
			# note, titles of rows (paragraphs) are TITLE, TR, TDtd_style_1
			while ( $ar_in[$i] !~ m/END_TABLE/ && $i <= $lastline)  {
				if ( $ar_in[$i] =~ m/^TITLE\s+(\S.*)/)  {
					$caption = $1 ;
					$ret .= '<caption>' . $caption . '</caption>' ;
				} elsif ( $ar_in[$i] =~ m/START_HEAD/)  {
					$inhead = 1 ;
					$ret .= '<thead>' ;
				} elsif ( $ar_in[$i] =~ m/END_HEAD/)  {
					$ret .= '</tr>' if ( $inrow) ;
					$inrow = 0 ;
					$ret .= '</thead>' ;
					$inhead = 0 ;
				} elsif ( $ar_in[$i] =~ m/START_BODY/)  {
					$ret .= '</tr>' if ( $inrow) ;
					$ret .= $inhead ? '</thead><tbody>' : '<tbody>' ;
					$inhead = 0 ;
					$inbody = 1 ;
					$inrow = 0 ;
				} elsif ( $ar_in[$i] =~ m/END_BODY/)  {
					$ret .= '</tr>' if ( $inrow) ;
					$inrow = 0 ;
					$ret .= '</tbody>' if ( $tfoot_exception == 0) ;
					$inbody = 0 ;
				} elsif ( $ar_in[$i] =~ m/^FOOTER\s+(\S.*)/)  {
					$ret .= '</tr>' if ( $inrow) ;
					$inrow = 0 ;
					if ( $tfoot_exception == 1)  {
							# important note: We put the tfoot in the last data row of the table
							# and reserve the caption for the table title, since captions are
							# required on all data tables in WCAG. This will need to be edited
							# when published to a form. Our vendor had a problem with tfoot, which was not
							# technically allowed after the <tbody> element until HTML 5, and some
							# item banks it seems just haven't caught up. If they do, we can process
							# <tfoot> elements normally, by HTML 5, that is: use $tfoot_exception = 0.
						$ret .= '<tr><td colspan="'
							. $max_columns . '" class="tdclass td_style_1 ">'
							. $1 . '</td></tr></tbody>' ;
						$inbody = 0 ;
					} else {
						$ret .= '<tfoot><tr><td colspan="'
							. $max_columns . '" class="tdclass td_foot_1 ">'
							. $1 . '</td></tr></tfoot>' ;
					}
					$inbody = 0 ;
					$inrow = 0 ;

			#
			# generic row
			#
				} elsif ( $ar_in[$i] =~ m/^TR/)  {
					$ret .= $inrow ? '</tr><tr class="trclass tr_style_1 ">' : '<tr class="trclass tr_style_1 ">' ;
					$inrow = 1 ;
					$max_columns = $apparent_columns if ( $apparent_columns > $max_columns) ;
					$apparent_columns = 0 ;
			#
			# title in table header row
			#
				} elsif ( $ar_in[$i] =~ m/^TH\s+rowspan(\d+)\s+(\S.*)/)  {
					my $rowcount = eval $1 ;
					my $cellcontent = $2 ;
					$ret .= '<th class="thclass th_style_1 " rowspan="' . $rowcount . '">' . $cellcontent . '</th>' ;
				} elsif ( $ar_in[$i] =~ m/^TH\s+colspan(\d+)\s+rowspan(\d+)\s+(\S.*)/)  {
					my $colcount = eval $1 ;
					my $rowcount = eval $2 ;
					my $cellcontent = $3 ;
					$ret .= '<th class="thclass th_style_1 " colspan="' . $colcount . '" rowspan="' . $rowcount . '">' . $cellcontent . '</th>' ;
				} elsif ( $ar_in[$i] =~ m/^TH\s+colspan(\d+)\s+(\S.*)/)  {
					my $colcount = eval $1 ;
					my $cellcontent = $2 ;
					$ret .= '<th class="thclass th_style_1 " colspan="' . $colcount . '">' . $cellcontent . '</th>' ;
				} elsif ( $ar_in[$i] =~ m/^TH\s(\S.*)/)  {
					my $cellcontent = $1 ;
					$ret .= '<th class="thclass th_style_1 ">' . $cellcontent . '</th>' ;
			#
			# table cells
			#
				} elsif ( $ar_in[$i] =~ m/^TD\s+rowspan(\d+)\s+(\S.*)/)  {
					my $rowcount = eval $1 ;
					my $cellcontent = $2 ;
					$ret .= '<td class="tdclass td_style_1 " rowspan="' . $rowcount . '">' . $cellcontent . '</td>' ;
				} elsif ( $ar_in[$i] =~ m/^TD\s+colspan(\d+)\s+rowspan(\d+)\s+(\S.*)/)  {
					my $colcount = eval $1 ;
					my $rowcount = eval $2 ;
					my $cellcontent = $3 ;
					$ret .= '<td class="tdclass td_style_1 " colspan="' . $colcount . '" rowspan="' . $rowcount . '">' . $cellcontent . '</td>' ;
					$apparent_columns++ ;
				} elsif ( $ar_in[$i] =~ m/^TD\s+colspan(\d+)\s+(\S.*)/)  {
					my $colcount = eval $1 ;
					my $cellcontent = $2 ;
					$apparent_columns++ ;
					$ret .= '<td class="tdclass td_style_1 " colspan="' . $colcount . '">' . $cellcontent . '</td>' ;
				} elsif ( $ar_in[$i] =~ m/^TD class(\S+)\s+(\S.*)/)  {
					my $cellclass = $1 ;
					$apparent_columns++ ;
					my $cellcontent = $2 ;
					$ret .= '<td class="tdclass ' . $cellclass . ' ">' . $cellcontent . '</td>' ;
				} elsif ( $ar_in[$i] =~ m/^TD\s(\S.*)/)  {
					my $cellcontent = $1 ;
					$apparent_columns++ ;
					$ret .= '<td class="tdclass td_style_1 ">' . $cellcontent . '</td>' ;
				}

				$i++ ;
				if ( $i > $lastline)  {
					#
					# end of file reached before END_TABLE statement: it's an error: abort
					print "\n\n*** ERROR: No END_TABLE statement in file. Check file.\n" ;
				}
			}
			#
			# end the table, whether we got here by an END_TABLE declaration or the end of the file
			#
			$ret .= '</tr>' if ( $inrow) ;
			$ret .= '</tbody>' if ( $inbody) ;
			$ret .= '</table></div>' ;

		} elsif ( $ar_in[$i] =~ m/\S/)  {
			#
			# if we haven't broken out of this loop by now, we don't recognize the line, assume it's a simulus paragraph
			#
			if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
				$ret .= '<div class="prose "><p class="passage_para ">' . $ar_in[$i] . '</p></div>' ;
			}
		}
		if ( $now_in_list) { $ret .= '</ul>' ; $now_in_list = 0 ; }
		return $ret ;
}

#
# constructed response questions have bullets at the end in our style
# yours may differ, and that will require a change here for
# the extendedText type of item interaction.
#
sub get_cr_bullets {
	my ( $nBullets, $s) = ( 0, '') ;
	for my $elt ( @_)  {
		( $elt =~ m/^BUL\s+(\w.*)$/) && do {
			$s .= '<li class="list_paragraph ">' . $1 . '</li>' ;
			$nBullets++ ;
		} ;
	}
	if ( $nBullets > 4)  {
		print "\nERROR: .o file has TOO MANY BULLETS\n" ;
		exit ( 30) ;
	}
	return $s ;
}

#
# if during edit.op.pl, the user decided to flag an item, it will be
# marked and excluded from the package, even if it is in in.csv
sub item_flagged {
	my $f = shift ;
	my $s = get_file_content ( $f) ;
	if ( $s =~ m/FLAGGED/gms)  {
		return 1 ;
	}
	return 0 ;
}
