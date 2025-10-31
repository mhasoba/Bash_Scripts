#!/bin/bash

for f in *.svg
    do 
        echo "Converting $f"; 
        inkscape "$f" --export-pdf="$(basename "$f" .svg).pdf"
    done

