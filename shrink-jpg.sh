#!/bin/bash          

jpg_count=`find . -iname "*.jpg" | wc -l `
if [ $jpg_count != 0 ] 
then
    for f in *.JPG; 
        do 
            echo "Converting $f..." 
            convert $f -quality 50 $f;         
        done
else
    echo "No .JPG files found."
fi