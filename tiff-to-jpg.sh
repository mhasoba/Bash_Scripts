#!/bin/bash          

tif_count=`find . -iname "*.tif" | wc -l `
if [ $tif_count != 0 ] 
then
    for f in *.tif; 
        do  
            echo "Converting $f"; 
            convert "$f"  "$(basename "$f" .tif).jpg"; 
        done
else
    echo "No .TIF files found."
fi