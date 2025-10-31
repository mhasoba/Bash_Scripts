#!/bin/bash

#~ Rename file name using regex (rename uses perl regex)
#~ see http://tips.webdesign10.com/how-to-bulk-rename-files-in-linux-in-the-terminal

#~ To Rename GCM2013update_robinson_composite_30fps.0002.jpg as 0002.jpg : 
#~ rename -v 's/GCM2013update_robinson_composite_30fps.(\d{4}).jpg$/$1\.jpg/' *.jpg

#~ To Rename 0002.jpg as 002.jpg : 
#~ rename rename -n -v 's/\d{1}(\d{3}).jpg$/$1\.jpg/' *.jpg

rename -v 's/\d{1}(\d{3}).jpg$/$1\.jpg/' *.jpg

#~// rename [options] [regex search/replace] [in these files]
#~// -v = verbose, display what you are doing on screen
#~// -n = "do Not, just show what might happen", in other words, use '-n' if you want to test the end result

#~ ANOTHER SOLUTION:
#~for f in file*; 
    #~do 
        #~mv $f ${f/${f:4:8}/25032014}; 
    #~done
#~
#~rename s/"SEARCH"/"REPLACE"/g  *


# To replace space dash space with underscore in filenames:

find -name "* - *" -type f | rename 's/ - /_/g'


ls | while read -r FILE
do
  # mv -v "$FILE" `echo $FILE | tr ' - ' '_' `
done


