#!/bin/bash

#Need to modify this to be more self-sufficient/elegant... 

#Alternatives:
# inkscape --query-all Roadmap.svg | grep layer | awk -F, '{print $1}'
# for id in `seq 1 11`; do echo "Roadmap.svg -jC -i layer$id -e Roadmap$id.png -d 300"; done

# for id in `seq 1 12`; 
#     do inkscape Roadmap.svg -jC -i layer$id -e Roadmap$id.png -d 300; 
# done

# Usage
# inkscape --shell < ~/Documents/Code_n_script/Bash/InksExp.sh

# for id in `seq 1 4`; 
#     do inkscape history-of-life.svg -jC -i layer$id -e History$id.png -d 300; 
# done

inkscape history-of-life.svg -jC -i layer2 -e History1.png -d 300
inkscape history-of-life.svg -jC -i layer1 -e History2.png -d 300
inkscape history-of-life.svg -jC -i layer3 -e History3.png -d 300
inkscape history-of-life.svg -jC -i layer4 -e History4.png -d 300
inkscape history-of-life.svg -jC -i layer5 -e History5.png -d 300
