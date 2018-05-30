# txt-to-qti
These Perl scripts can be used for converting raw text files, which might originate from OCR
processing software, and building a QTI content package that can be imported into test
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
A Answer choice 1   
B Answer choice 2   
C Answer choice 3   

Format of Constructed Response Items
====================================
USE stimulus_identifier (if required)   
Stimulus (as above)   
BUL First bulleted direction or question   
BUL Second bulleted direction of question   
