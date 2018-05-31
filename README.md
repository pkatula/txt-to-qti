# txt-to-qti
These Perl scripts can be used for converting raw text files, which might originate from OCR
(optical character recognition) software, to a QTI content package created by the scripts that you can import into
item banks, such as TAO.

The base suite includes a utility (edit.op.pl) to review the content of the text files and
edit them or add styling if desired. Once approved, the script op.manifest.pl can be run
to build the QTI content package automatically.

The scripts recognize two item interaction types:
* Multiple choice with one correct answer
* Extended text (constructed response), which involves hand scoring

Text files that define test ITEMS should have the file name IDENT.o, where IDENT is the unique
identifier for the item. Passages (shared stimuli) should have the file name IDENT.p.

The scripts should be on the path, and the package QtiXml.pm should be on the Perl search
path (probably PERL5LIB) on your system. The op.manifest.pl script requires POSIX, XML::Bare, and Image::Size.

Format of Item Files
====================
USE stimulus_identifier (optional, to be included if a shared stimulus is used)   
Stimulus paragraph 1   
TABLE definition (or any elements that are part of the item)   
IMAGE included   
Prompt (optional)    
A Answer choice 1   
B Answer choice 2   
C Answer choice 3   

Format of Constructed Response Items
====================================
USE stimulus_identifier (if required)   
Stimulus (as above)   
Prompt (optional)   
BUL First bulleted direction or question   
BUL Second bulleted direction of question   

Instructions
============
Create a directory for the export package
-----------------------------------------
In a separate directory on your computer, place the style.css file and the in.csv file. The format of the in.csv file should be:
* No header row or BOM
* Column 1: Identifier for a test item (test question)
* Column 2: The correct answer, incicated by a 1-based integer (use 0 for constructed-response questions)
* Column 3: A shared stimulus, if one should be attached, or 0 if none

Sample contents of the build directory
--------------------------------------
MDV00001.o  MDV00002.o  MDV00003.o  MDV00004.o  MDVA0001.p   mlk.monu.jpg  in.csv  style.css

What the files contain
----------------------
In the above directory listing, the contents of each file might be this (see the test directory on this repository for the files themselves).

in.csv:   
MDV00001,1,0   
MDV00002,2,0   
MDV00003,3,MDVA0001   
MDV00004,4,MDVA0001    
MDV00005,0,MDVA0001

MDV00001.o:   
A stand-alone multiple-choice question with "A" as the correct answer.

MDV00002.o:   
A stand-alone multiple-choice question with "B" as the correct answer. A picture, mlk.monu.jpg, is part of the prompt or printed slightly above the prompt after an introductory paragraph.

MDVA0001.p:   
A stimulus that includes a table with data in it from the Census Bureau. This stimulus serves both multiple-choice questions MDV00003 and MDV00004 as well as the constructed response question MDV00005.

MDV00003.o:    
A multiple-choice question with "C" as the correct answer, shown on the same screen or page as the stimulus MDVA0001.

MDV00004.o:    
A multiple-choice question, also based on stimulus MDVA0001, with "D" as the correct response.

MDV00005.o:    
A constructed-response question (essay question), shown on the same screen or page as the stimulus MDVA0001.

style.css:   
A CSS style sheet, providing styling information about many of the classes used by this suite of scripts.

A note about tables and math
----------------------------
We didn't have too many special tables to deal with, and we had absolutely *no* math expressions to encode in MathML. Therefore, you will need to add code if you want to deal with this automatically, as they were not part of our initial migration of items in U.S. government (civics).

I included an example of how you might create a table, using the TABLE_GENERAL layout specification in the text file. It's found in the shared stimulus MDVA0001.p, which I put into the test directory on this repository. This is a simple table with a title, header row, six data rows with U.S. population data, and a footer. You can provide layout for tables on your items in a similar manner by using the *vi* command with edit.op.pl.

For math, I now use iTex2MML, which is open source available on GitHub to convert LaTeX to MathML for use in QTI content packages. LaTeX is much more user-friendly than MathML, but the latter is used in QTI. One of these days, IMS Global will allow the use of LaTeX, which has been used by textbook publishers for several years for math expressions, but right now, MathML is required and there are several tools that can help you format a math expression.

Note that the packager here (op.manifest.pl), simply takes whatever it finds on a line and puts it in a paragraph, so if you put MathML on a line, using "inline" or "block" format, the packager will simply copy that to the package, even if it contains MathML.

Run edit.op.pl if you need to check layout or proofread
-------------------------------------------------------
Go into the build directory (the one with the files shown above), and run the edit.op.pl script. This will cycle through the item files and then the stimulus files in that directory, based on what it finds in in.csv. You can edit the files by hand, just in case your automated process of OCR, conversion from PDF or Microsoft Word, or whatever you used, didn't work 100 percent.

When edit.op.pl is running, you are shown the contents of the file (syswrite to STDERR), and each line is numbered so that you can use commands to edit individual lines.

Before you do that, you should know that typing *vi* at the prompt will simply open the file in the visual editor, allowing you to correct spelling mistakes.

If all you want to do is edit the content one line at a time, though, you can use the command-line file editing tool built into edit.op.pl:

* delete,2

This command will delete line number 2 from the file.

* rebreak,6

Apply a multiple-choice breaking to line 6. Sometimes the OCR software we used thought the multiple choice block was all in one paragraph. This was common when all the lines were the same length, such as:

A milk    
B tea     
C water

The OCR would give us something like:

A milk B tea C water   

(thinking it was just a very narrow column for a whole paragraph). Our software requires each multiple-choice option to be on a separate line, so I added the rebreak command to edit.op.pl to apply a more intelligent breaking to a line that I could see was a multiple-choice line by noticing the letters. This could probably be done automatically, but doing it with rebreak wasn't necessary often enough to justify rewriting the layout recognition code.

* join,3

This command will join lines 3 and 4 to create a single paragraph. It is important to note that each answer option in a multiple-choice layout must be on one line, so if the OCR software breaks the line in the middle of a multiple-choice option or in the middle of a paragraph in the stimulus, you need to use join to put all that text on one line.

* ignore,3

Put the directive "IGNORE" in front of line number 3. This will prevent the packager from reading anything on this line or incorporating it into the content package created by op.manifest.pl.

* underline,5,most likely

Wrap the words "most likely" on line number 5 in a span that imparts the class "text_decoration_underline" on those words. Note that QTI does not support the *style* attribute in a span, so the use of classes is necessary for giving your text any styling.

* italicize,3,Gideon v. Wainwright

Wrap the words "Gideon v. Wainwright" on line number 3 in a span that will add the class "font_style_italicize" to that court case. This is done through a definition of that class in the style sheet.

* unspan,2

Remove all styling spans from line number 2.

* headline,1

Tag line number 1 as the text of a headline. This ordinarily causes a text-transform:uppercase to be added to the classes affecting the words on the entire line.

* ewa,4

Changes the style of lines 4 and 5 to type "Exerpt With Attribution" so that line 4 is a quoted excerpt (see style.css to note that we put these in a box with light gray shading) and line 5 is the attribution, which is styled to be in its own paragraph, right-aligned. IMPORTANT NOTE: This layout specification applies to two lines in the raw text file: the line with the quotation and the line immediately following that as the attribtion.

* box,6

Puts the text on line 6 in a shaded box in the layout by using style.css.

* lead,1

Makes line 1 a "lead-in" paragraph. Our software looked for phrases like "Read the ..." or "Study the ..." or "Look at the ..." and then automatically applied the lead-in class to that initial paragraph, provided that phrase started the paragraph near the beginning of the text file. Often some boxed info or a headline or newsclip would follow on the line immediately following the lead-in.

* box4,5

Beginning with line 5, put the next four paragraphs in a shaded gray box (or whatever you define as the style for this class in style.css). IMPORTANT NOTE: This layout specification affects the next four lines of the raw text file, even though only the first line is specifically tagged. I have created box2 through box6 directives for our purposes, but feel free to extend this or to create similar classes by using the box3 or whatever as a template in QtiXml.pm.

* newsclip,2

Give the paragraph on line 2 a style that indicates it is some sort of newsclip.

See QtiXml.pm
-------------
Other commands may be developed and placed in the edit_txt_file() subroutine in QtiXml.pm, and you should refer to that file for the ultimate list of commands that are availble from edit.op.pl.

If you make any changes, you should also ensure that the command is processed correctly when creating the outut package for export. Only a certain subset of XHTML is supported by the QTI standards, and you should also check that whatever changes you make will not cause the emission of invalid QTI.

Run op.manifest.pl
==================
The script op.manifest.pl will take the .o and .p files in the current directory, based on what it finds in the in.csv file, and build a QTI content package for export to an online item bank.

Assuming all the pieces are in the current directory, including any images referenced in the .o or .p files, the script will create the following subdirectories in the current directory:
* out/
* out/item
* out/passage
* out/asset

The imsmanifest.xml file will be in the out/ directory, along with any assessmentSetion files that may have been used in order to create test sections to accommodate the shared stimuli your items may have used.

There are other options for incorporating shared stimuli as well, and some of these modifications may be forthcoming. But we tested this code on two different item banks, and both were able to import the package with sections encoded as separate entities.

Zip the package up
==================
You will need to use WinZip or another archive/compress utility to create an actual export package. Just Zip the entire contents of the out/ directory, including all subdirectories.
