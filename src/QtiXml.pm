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
package QtiXml ;
use strict ;
use warnings ;
use XML::Bare ;
use Image::Size ;


BEGIN {
	require Exporter;
	# set the version for version checking
	our $VERSION = 1.00 ;
	# Inherit from Exporter to export functions and variables
	our @ISA = qw(Exporter) ;
	# Functions and variables that are exported by default
	our @EXPORT = qw(
		interplay_string
		get_file_content
		strip_quotes
		$rubric_block_xml_template
		$mc4_w_stimulus_xml_template
		$cr_w_stimulus_xml_template
		edit_txt_file
		%manifest_template
	) ;
}


#
# #############################################
# EXPORT OF TEMPLATES FOR OUTPUT FILES
# #############################################
#

#
# <rubricBlock> for share stimulus
#
our $rubric_block_xml_template = '<?xml version="1.0" encoding="UTF-8"?>'
	. '<rubricBlock use="sharedstimulus" view="author candidate proctor scorer testConstructor tutor" '
	. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
	. 'id="{{STIMULUS_MDV_ID}}" '
	. 'xsi:schemaLocation="http://www.w3.org/1998/Math/MathML http://www.w3.org/Math/XMLSchema/mathml2/mathml2.xsd http://www.imsglobal.org/xsd/imsqti_v2p1 http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1p2.xsd http://www.imsglobal.org/xsd/apip/apipv1p0/imsapip_qtiv1p0 http://www.imsglobal.org/profile/apip/apipv1p0/apipv1p0_qtiextv2p1_v1p0.xsd" '
	. 'xmlns="http://www.imsglobal.org/xsd/imsqti_v2p1"> '
	. '{{STIMULUS_BLOCK}}'
	. '<stylesheet href="../asset/style.css" type="text/css" />'
	. '<apipAccessibility xmlns="http://www.imsglobal.org/xsd/apip/apipv1p0/imsapip_qtiv1p0" />'
	. '</rubricBlock>' ;

#
# multiple choice question, not using a shared stimulus: STIMULUS_BLOCK must be set (already in its own div)
#
our $mc4_w_stimulus_xml_template = '<?xml version="1.0" encoding="UTF-8"?>'
	. '<assessmentItem xsi:schemaLocation="http://www.imsglobal.org/xsd/imsqti_v2p1 http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1.xsd" '
	. 'toolVersion="1.0" toolName="MSDE/ETS OCR/tesseract" timeDependent="false" '
	. 'identifier="{{ITEM_MDV_ID}}" title="Migrated MC Item {{ITEM_MDV_ID}}" '
	. 'adaptive="false" '
	. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
	. 'xmlns="http://www.imsglobal.org/xsd/imsqti_v2p1">'
	. '<responseDeclaration identifier="RESPONSE" cardinality="single" baseType="identifier"> '
	. '<correctResponse><value>{{CORRECT_RESPONSE_IDENTIFIER}}</value></correctResponse></responseDeclaration> '
	. '<outcomeDeclaration identifier="SCORE" cardinality="single" baseType="float" normalMinimum="0.0" normalMaximum="1.0"/> '
	. '<stylesheet href="../asset/style.css" type="text/css" />'
	. '<itemBody>'
	. '{{STIMULUS_BLOCK}}'
	. '<choiceInteraction class="choice_list " shuffle="false" responseIdentifier="RESPONSE" minChoices="1" maxChoices="1">'
	. '{{PROMPT}} {{CHOICES}}'
	. '</choiceInteraction>'
	. '</itemBody>'
	. '<responseProcessing xmlns="http://www.imsglobal.org/xsd/apip/apipv1p0/qtiitem/imsqti_v2p1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
	. 'xsi:schemaLocation="http://www.imsglobal.org/xsd/apip/apipv1p0/qtiitem/imsqti_v2p1 http://www.imsglobal.org/profile/apip/apipv1p0/apipv1p0_qtiitemv2p1_v1p0.xsd"> '
	. '<responseCondition><responseIf><match><variable identifier="RESPONSE"/><correct identifier="RESPONSE"/></match>'
	. '<setOutcomeValue identifier="SCORE"><baseValue baseType="float">1</baseValue></setOutcomeValue></responseIf>'
	. '<responseElse><setOutcomeValue identifier="SCORE"><baseValue baseType="float">0</baseValue></setOutcomeValue></responseElse>'
	. '</responseCondition></responseProcessing>'
	. '</assessmentItem>' ;

our $cr_w_stimulus_xml_template = '<?xml version="1.0" encoding="UTF-8"?>'
	. '<assessmentItem xsi:schemaLocation="http://www.imsglobal.org/xsd/imsqti_v2p1 http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1.xsd" '
	. 'toolVersion="1.0" toolName="MSDE/ETS OCR/tesseract" timeDependent="false" '
	. 'identifier="{{ITEM_MDV_ID}}" title="Migrated CR Item {{ITEM_MDV_ID}}" '
	. 'adaptive="false" '
	. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
	. 'xmlns="http://www.imsglobal.org/xsd/imsqti_v2p1">'
	. '<responseDeclaration identifier="RESPONSE" cardinality="single" baseType="string"/>'
	. '<outcomeDeclaration identifier="SCORE" cardinality="single" baseType="float">'
	. '<defaultValue><value>0</value></defaultValue></outcomeDeclaration>'
	. '<stylesheet href="../asset/style.css" type="text/css" />'
	. '<itemBody> '
	. '{{STIMULUS_BLOCK}}'
	. '<extendedTextInteraction class="extended_text_response " responseIdentifier="RESPONSE"> '
	. '<prompt class="item_stem "> '
	. '<ul class="unordered_list style:1 "> {{BULLETS_IN_LI_LIST_PARAGRAPH_CLASS}} </ul> '
	. '</prompt> '
	. '</extendedTextInteraction> '
	. '</itemBody> '
	. '</assessmentItem>' ;

our %manifest_template = (
	manifest_wrap => '<?xml version="1.0" encoding="UTF-8"?>'
		. '<manifest identifier="MAN-{{NUMERIC_MANIFEST_IDENTIFIER}}" '
		. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
		. 'xsi:schemaLocation="http://www.imsglobal.org/xsd/imscp_v1p1 http://www.imsglobal.org/xsd/qti/qtiv2p1/qtiv2p1_imscpv1p2_v1p0.xsd http://ltsc.ieee.org/xsd/LOM http://www.imsglobal.org/xsd/imsmd_loose_v1p3p2.xsd http://www.imsglobal.org/xsd/imsqti_metadata_v2p1 http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_metadata_v2p1p1.xsd http://www.imsglobal.org/xsd/imsccv1p2/imscsmd_v1p0 http://www.imsglobal.org/profile/cc/ccv1p2/ccv1p2_imscsmd_v1p0.xsd" '
		. 'xmlns="http://www.imsglobal.org/xsd/imscp_v1p1">'
		. '<metadata><schema>QTIv2.1 Package</schema><schemaversion>1.0.0</schemaversion><lom xmlns="http://ltsc.ieee.org/xsd/LOM">'
		. '<general><identifier><entry>{{NUMERIC_MANIFEST_IDENTIFIER}}</entry><catalog>MD Package Identifier</catalog></identifier>'
		. '<title/></general></lom></metadata><organizations/><resources>{{RESOURCE_BLOCKS}}</resources></manifest>',
	image_resource_block => '<resource identifier="{{RES_ID_ON_IMPORT}}" type="webcontent" href="{{PATH_TO_IMAGE_JPG}}">'
		. '<metadata><qtiMetadata xmlns="http://www.imsglobal.org/xsd/imsqti_metadata_v2p1"/><lom xmlns="http://ltsc.ieee.org/xsd/LOM"/></metadata>'
		. '<file href="{{PATH_TO_IMAGE_JPG}}"/></resource>',
	item_resource_block => '<resource identifier="{{RES_ID_ON_IMPORT}}" type="imsqti_item_xmlv2p1" href="{{PATH_TO_ITEM_QTI_XML}}">'
		. '<metadata><qtiMetadata xmlns="http://www.imsglobal.org/xsd/imsqti_metadata_v2p1">'
		. '<interactionType>{{ITEM_INTERACTION_TYPE}}</interactionType></qtiMetadata>'
		. '<lom xmlns="http://ltsc.ieee.org/xsd/LOM"><general><identifier><entry>{{MDV_ITEM_ID}}</entry><catalog>ETS</catalog></identifier></general>'
		. '<lifeCycle><status><source>LOMv1.0</source><value>draft</value></status></lifeCycle></lom>'
		. '</metadata><file href="{{PATH_TO_ITEM_QTI_XML}}"/>{{DEPENDENCY_IDENTIFIERREFS}}</resource>',
	dependency_identifier_ref_line => '<dependency identifierref="{{RES_OF_USED_RESOURCE}}"/>',
	stimulus_resource_block => '<resource identifier="{{RES_ID_ON_IMPORT}}" type="webcontent" href="{{PATH_TO_PASSAGE_QTI_XML}}">'
		. '<metadata><lom xmlns="http://ltsc.ieee.org/xsd/LOM"><general><identifier><entry>{{MDV_ITEM_ID}}</entry><catalog>ETS</catalog></identifier></general>'
		. '<lifeCycle><status><source>LOMv1.0</source><value>draft</value></status></lifeCycle></lom>'
		. '</metadata><file href="{{PATH_TO_PASSAGE_QTI_XML}}"/>{{DEPENDENCY_IDENTIFIERREFS}}</resource>',
	assessment_resource_block => '<resource identifier="{{RES_ID_ON_IMPORT}}" type="imsqti_section_xmlv2p1" href="{{SECTION_FILE_NAME}}">'
		. '<metadata><lom xmlns="http://ltsc.ieee.org/xsd/LOM"><lifeCycle><status><source>LOMv1.0</source><value>draft</value></status></lifeCycle></lom></metadata>'
		. '<file href="{{SECTION_FILE_NAME}}"/>{{DEPENDENCY_IDENTIFIERREFS}}</resource>',
	assessment_file_wrap => '<?xml version="1.0" encoding="UTF-8"?>{{ASSESSMENT_SECTION}}</assessmentSection>',
	assessment_section_wrap => '<assessmentSection identifier="{{RES_SET_RESOURCE_ID_ON_INBOUND}}" title="" '
		. 'visible="true" fixed="false" keepTogether="false" '
		. 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
		. 'xsi:schemaLocation="http://www.imsglobal.org/xsd/imsqti_v2p1 http://www.imsglobal.org/xsd/qti/qtiv2p1/imsqti_v2p1p2.xsd http://www.w3.org/1998/Math/MathML http://www.w3.org/Math/XMLSchema/mathml2/mathml2.xsd http://www.imsglobal.org/xsd/apip/apipv1p0/imsapip_qtiv1p0 http://www.imsglobal.org/profile/apip/apipv1p0/apipv1p0_qtiextv2p1_v1p0.xsd" '
		. 'xmlns="http://www.imsglobal.org/xsd/imsqti_v2p1"><xi:include href="{{PATH_TO_PASSAGE_QTI_XML_FROM_ROOT}}" xmlns:xi="http://www.w3.org/2001/XInclude" />'
		. '{{ASSESSMENT_ITEM_REF_LINES}}',
	assessment_item_ref_line => '<assessmentItemRef identifier="{{REF_ID_ON_IMPORT_FOR_DEPENDENT_ITEM}}" '
		. 'href="{{PATH_TO_DEPENDENT_ITEM_FROM_ROOT}}" required="false" fixed="false" />'
) ;


################ SUBROUTINES #################

#
# put the contents of a file (usually a template) in a string
#
sub get_file_content {
	my ( $s, $fn) = ( '', $_[0]) ;
	open ( VOXF_INFILE, "<", $fn) || return $s ;
	while ( <VOXF_INFILE>)  {
		$s .= $_ ;
	}
	close ( VOXF_INFILE) ;
	return $s ;
}

#
# a useful function for replacing parameters in a string given parameter => value in list as arguments
#
sub interplay_string {
	my %prms  = @_ ;
	my $s_str = $prms{'source'} ;
	#
	# scan the string and determine all the variables we need (variables are in {{variable_name}} )
	#
	my @ar = $s_str =~ m/\{\{(.+?)\}\}/g ;
	#
	# we could make sure all requested variables were supplied in parameter list,
	# but since it's just us calling it, we're going to leave that to QA
	#
	for my $elt ( @ar)  {
		my $replaced = '{{' . $elt . '}}' ;
		my $replace_with = $prms{$elt} ;
		$s_str =~ s/$replaced/$replace_with/g if ( defined $replace_with) ; #  && length ( $replace_with) > 1) ;
	}
	#
	# white space is neither added nor deleted (in the event of an empty replacement) around the parameter,
	# but we do clean up the whole string a little, replacing repeated white space with a single space (or not)
	#
	# $s_str =~ s/\s{2,}/ /g ;
	return $s_str ;
}

#
# processing functions
#
sub strip_quotes {
	my $s = shift ;
	$s =~ s/\"//g ;
	return $s ;
}

# consume the XML coming out of OCR
# Note: This subroutine is not called but was used in some precursor scripts and may still be useful
#
sub stylize_text {
	my $s = shift ;
	$s =~ s/\s{2,}/ /g ;
	$s =~ s/^\s+//g ;
	$s =~ s/\s+$//g ;
	$s =~ s/\"/&quot;/g ;
	$s =~ s/\'/&apos;/g ;		   # sometimes apos comes straight out of the OCR, sometimes not

	#
	# We noted several error coming from the OCR software, so we apply automatic
	# fixes whenever we find one of these common misspellings
	$s =~ s/Nezv\s/New /g ;
	$s =~ s/Nezu\s/New /g ;
	#
	# next, the OCR didn't reliable report italicised or underlined text,
	# so we apply a italics to Supreme Court cases here as well as underlining
	# phrases like "most likely" for emphasis, which is our style
	# simply add any processing you want here, and make sure you add
	# the counterpart to edit_txt_file()
	#
	$s =~ s/(McCulloch vs*\. Maryland)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Tinker vs*\. Des\s*Moines)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Miranda vs*\. Arizona)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Gideon vs*\. Wainwright)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Gideon vs*\. Waimvright)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Marbury vs*\. Madison)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Brown vs*\. Board of Education)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(New Jersey vs*\. T\.L\.O\.)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Plessy vs*\. Ferguson)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Mapp vs*\. Ohio)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Plessy vs*\. Ferguson)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;
	$s =~ s/(Weeks vs*\. U\.S\.)($|[^\<])/<span class="formatted_text font_style_italic ">$1<\/span>$2/g ;

	$s =~ s/(\s)(EXTENDED CONSTRUCTED RESPONSE|BRIEF CONSTRUCTED RESPONSE|CONSTRUCTED RESPONSE)([^\<])/$1<span class="formatted_text text_decoration_underline ">$2<\/span>$3/g ;
	$s =~ s/(\s)(most \w+?ly)([^\<])/$1<span class="formatted_text text_decoration_underline ">$2<\/span>$3/g ;

	return $s ;
}

#
# modify existing text file with console commands
#
sub edit_txt_file {
	my $ff = shift ;
	do {
		my @e_array = () ;
		my $save_it = 1 ;
		open ( my $fh, "<", $ff) || die "Can't open $ff: $!" ;
		while ( <$fh>)  { push @e_array, $_ ; }
		close ( $fh) ;
		#
		# show what's in the file, with line numbers
		#
		my $ln = 0 ;
		syswrite STDERR, "\nContents of $ff:\n" ;
		for my $e ( @e_array)  {
			syswrite STDERR, '[' . ( $ln < 10 ? ' ' : '') . $ln . '] ' . $e ;
			$ln++ ;
		}
		#
		# process a command entered by the user
		#
		syswrite STDERR, "command [, line[, args]] > " ;
		my $line = <STDIN> ; chomp $line ;
		if ( $line =~ m/^quit/)  {
			return 0 ;			  # signal to end it
		} elsif ( length ( $line) < 2)  {
			return 1 ;			  # signal (probably) to do the next file
		} elsif ( $line =~ m/^vi$/)  {
			system ( "vi $ff") ;
			$save_it = 0 ;				  # editor will save it
		} elsif ( $line =~ m/^flag$/)  {
			splice @e_array, 1, 0, "IGNORE FLAGGED ON REVIEW\n" ;
		} elsif ( $line =~ m/^normal\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], '') ;
			}
		} elsif ( $line =~ m/^ewa\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'EXCERPT_WITH_ATTR') ;
			}
		} elsif ( $line =~ m/^bul\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'BUL') ;
			}
		} elsif ( $line =~ m/^join\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline < $#e_array)  {
				$e_array[$refline] = substr ( $e_array[$refline], 0, -1) . ' ' . $e_array[$refline + 1] ;
				splice @e_array, $refline + 1, 1 ;
			}
		} elsif ( $line =~ m/^lead\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'LEAD') ;
			}
		} elsif ( $line =~ m/^headline\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'HEADLINE') ;
			}
		} elsif ( $line =~ m/^optheadline\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] =~ s/([ABCDEFGHJK])\s+(.+)/$1 HEADLINE $2/ ;
			}
		} elsif ( $line =~ m/^title\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'TITLE') ;
			}
		} elsif ( $line =~ m/^ignore\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'IGNORE') ;
			}
		} elsif ( $line =~ m/^delete\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 1 ;
			}
		} elsif ( $line =~ m/^box\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'BOX') ;
			}
		} elsif ( $line =~ m/^box(\d)\s*\,\s*(\d+)/) {
			my $boxcount = eval $1 ;
			my $refline = eval $2 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'BOX' . "$boxcount") ;
			}
		} elsif ( $line =~ m/^twt\s*\,\s*(\d+)\s*\,\s*(\d+)\s*\,\s*(\d+)\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			my $table_cols = eval $2 ;
			my $table_head_rows = eval $3 ;
			my $table_data_rows = eval $4 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], "TABLE_WITH_TITLE $table_cols $table_head_rows $table_data_rows") ;
			}
		} elsif ( $line =~ m/^table\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "TABLE_GENERAL\n" ;
			}
		} elsif ( $line =~ m/^thead\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "START_HEAD\n"  ;
			}
		} elsif ( $line =~ m/^end\_head\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "END_HEAD\n"  ;
			}
		} elsif ( $line =~ m/^tbody\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "START_BODY\n"  ;
			}
		} elsif ( $line =~ m/^end\_body\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "END_BODY\n"  ;
			}
		} elsif ( $line =~ m/^tr\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "TR\n" ;
			}
		} elsif ( $line =~ m/^th\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'TH') ;
			}
		} elsif ( $line =~ m/^td\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = change_paragraph_type ( $e_array[$refline], 'TD') ;
			}
		} elsif ( $line =~ m/^tfoot\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "FOOTER\n" ;
			}
		} elsif ( $line =~ m/^end\_*table\s*\,\s*(\d+)/)  {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				splice @e_array, $refline, 0, "END_TABLE\n" ;
			} elsif ( $refline == $#e_array + 1)  {
				push @e_array, "END_TABLE\n" ;
			}
		} elsif ( $line =~ m/^unspan\s*\,\s*(\d+)/) {
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$1] =~ s/<\/*span[^>]*?>//g ;
			}
		} elsif ( $line =~ m/^italicize\s*\,\s*(\d+)\s*\,\s*(.*)/) {
			my $refline = eval $1 ;
			my $formatted_span = $2 ;
			if ( $refline <= $#e_array)  {
				$e_array[$1] =~ s/($formatted_span)/<span class="formatted_text font_style_italic ">$formatted_span<\/span>/g ;
			}
		} elsif ( $line =~ m/^underline\s*\,\s*(\d+)\s*\,\s*(.*)/) {
			my $refline = eval $1 ;
			my $formatted_span = $2 ;
			if ( $refline <= $#e_array)  {
				$e_array[$1] =~ s/($formatted_span)/<span class="formatted_text text_decoration_underline ">$formatted_span<\/span>/g ;
			}
		} elsif ( $line =~ /^rebreak\s*\,\s*(\d+)/)  {
			# stylizer didn't catch a new paragraph (potentially) for multiple choice line
			my $refline = eval $1 ;
			if ( $refline <= $#e_array)  {
				$e_array[$refline] = rebreak_mc ( $e_array[$refline]) ;
			}
		} else {
			syswrite STDERR, "Command not recognized. Options: quit normal ewa twt italicize underline unspan box ignore delete ...\n" ;
		}
		#
		# save the file, so it can be reloaded
		#
		if ( $save_it)  {
			open ( my $fh1, ">", $ff) || die "Can't write $ff: $!" ;
			for my $elt ( @e_array)  {
				print $fh1 $elt if ( $elt =~ m/\S/) ;   # don't write out blank lines
			}
			close ( $fh) ;
		}
	} while ( 1) ;				  # return only on quit (or ctrl-c)
}

sub change_paragraph_type {
	my ( $s, $newtype) = ( $_[0], $_[1]) ;
	#
	# delete any existing paragraph type identifier
	#
	$s =~ s/^(LEAD|TITLE|HEADLINE|IGNORE|BUL|TD|TH|EXCERPT_WITH_ATTR|BOX|BOX\d|TABLE_WITH_TITLE\s+\d+\s+\d+\s+\d+)\s+// ;
	return $s if ( length ( $newtype) < 2) ;
	return $newtype . ' ' . $s ;
}

#
# This function rebreaks a multiple-choice "paragraph" based on the sequence of
# letters. Some of our multiple-choice questions went A, B, C, D; others went F, G, H, J.
# But the OCR sometimes interpreted a block of multiple-choice options as being in
# on paragraph and so put it all on one line; most of the time it put each choice
# in its own paragraph (line in OCR text output), which made this function
# unnecessary on those items. When OCR took the multiple choice block to be one
# paragraph, mainly when each option had the same length and looked like wrapping
# to the OCR software, we had to use a function like this to automatically
# rebreak the line into separate lines for each multiple-choice option.
#
sub rebreak_mc {
	my $s = shift ;
	$s =~ s/\sB\s/\nB / ;
	$s =~ s/\sC\s/\nC / ;
	$s =~ s/\sD\s/\nD / ;
	$s =~ s/\sG\s/\nG / ;
	$s =~ s/\sH\s/\nH / ;
	$s =~ s/\sJ\s/\nJ / ;
	return $s ;
}

END { }	   # module clean-up code here (global destructor)
1;  # don't forget to return a true value from the file

#
# at https://www.imsglobal.org/question/qtiv2p1/imsqti_infov2p1.html#element10112 :
# supported derived classes inside item block:
# atomicBlock, atomicInline, caption, choice, col, colgroup, div, dl, dlElement, hr, interaction,
# itemBody, li, object, ol, printedVariable, prompt, simpleBlock, simpleInline, table, tableCell,
# tbody, templateElement, tfoot, thead, tr, ul, infoControl
#
