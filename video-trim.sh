## This cuts out the section after -ss from input.mp4, and saves that cut out section as output.mp4

ffmpeg -i input.mp4 -ss 00:17:10.420 -to 00:19:36.208 -c:v copy -c:a copy output.mp4

######### To delete multiple sections and stitch together the desired bits####### 

## This example deletes 1 sections from input.mp4 (from 00:17:10.420 - 00:19:36.208)

ffmpeg -i input.mp4 -ss 00:00:00.020 -to 00:17:10.420 -c:v copy -c:a copy part1.mp4 
ffmpeg -i input.mp4 -ss 00:19:36.208 -to 00:33:30 -c:v copy -c:a copy part2.mp4

# Create a text file named (say) joinlist.txt with this content:
# file 'part1.mp4'
# file 'part2.mp4'
# Then,

ffmpeg -f concat -i joinlist.txt -c copy joinedfile.mp4