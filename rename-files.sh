#!/bin/bash

# Rename all pdf files matching a particular pattern in given directory by appending a particular string

for f in *.pdf; 
    do  
        echo "Renaming $f"; 
        mv "$f"  "$(basename "$f" .pdf)_Annotated.pdf";
    done

# Rename all files with names that contain a particular pattern in directory by replacing that pattern with a different one

