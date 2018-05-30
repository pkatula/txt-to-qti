# txt-to-qti
These Perl scripts can be used for converting raw text files, which might originate from OCR
processing software, to a QTI content package that they create and you can import into test
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

Same contents of the build directory
------------------------------------
MDV00001.o  MDV00002.o  MDV00003.o  MDV00004.o  MDVA0001.p   flower.jpg  in.csv  style.css

