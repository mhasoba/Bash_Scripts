#!/bin/bash

#~ This assumes you have done apt-get install imagemagick 
for f in *.tif; 
    do  
        echo "Converting $f"; 
        convert "$f"  "$(basename "$f" .tif).png"; 
    done