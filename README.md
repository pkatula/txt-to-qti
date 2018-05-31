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

The scripts whould be on the path, and the package QtiXml.pm should be on the Perl search
path on your system. The op.manifest.pl script requires POSIX, XML::Bare, and Image::Size.

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

Run edit.op.pl
--------------
Go into the build directory (the one with the files shown above), and run the edit.op.pl script. This will cycle through the item files and then the stimulus files in that directory, based on what it finds in in.csv. You can edit the files by hand, just in case your automated process of OCR, conversion from PDF or Microsoft Word, or whatever you used, didn't work 100 percent.

When edit.op.pl is running, you are shown the contents of the file (syswrite to STDERR), and each line is numbered so that you can use commands to edit individual lines.

Before you do that, you should know that typing *vi* at the prompt will simply open the file in the visual editor, allowing you to correct spelling mistakes.

If all you want to do is edit the content one line at a time, though, you can use the command-line file editing tool built into edit.op.pl:

* delete,2

This command will delete line number 2 from the file.

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
