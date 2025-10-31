#!/bin/bash

# Simple convert of all docx files in a given directory to pdf  
#~ This assumes you have apt installed pandoc. uses --pdf-engine=xelatex to ignore missing fonts (pandoc default pdflatex will give errors when encountering weird fonts)

for f in *.docx; 
    do  
        echo "Converting $f";
        pandoc --pdf-engine=xelatex -s "$f" -o "$(basename "$f" .docx).pdf"
    done
