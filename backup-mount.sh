#!/bin/bash

#~UUID - Your hard drives UUID
#~BACKUPDIR - Where you want the files to be synced
#~TOBACKUP - What files you want synced

#backup harddrive variables
UUID='2b831e38-3389-4e39-9121-d2dc74ff13d9'
BACKUPDIR='/media/SamBlackup/HomeBkp/'
TOBACKUP='/home/mhasoba'
PARTITION=`readlink -f /dev/disk/by-uuid/$UUID`
TIMER=3

#############################################################

echo 'UUID: ' $UUID
echo 'Drive Partition: ' $PARTITION;

#check drive and partiton match
if /sbin/blkid | grep -s "$PARTITION" | grep -q "$UUID"; then
    echo 'Drive and partition match...'
else
	exit
fi

#if [ -z "$DIRECTORY" ]; then
#    echo 'No directory present...'
#fi

#check if drive mounted
if grep -qs $PARTITION /proc/mounts; then
	#its already mounted
	MOUNTED='1'
	echo 'Drive already mounted...'
        BACKUPDIR=`grep $PARTITION /proc/mounts | awk '{ print $2 }'`
        echo 'Directory: ' $BACKUPDIR
else
	#not mounted
	MOUNTED='0'
	echo 'Mounting drive...'
	sudo mkdir -p "$BACKUPDIR"
	sudo mount /dev/disk/by-uuid/$UUID "$BACKUPDIR"
        echo 'Mounted: ' $BACKUPDIR
fi


#countdown before sync
printf "\nStarting Backup..."
until [ $TIMER = 0 ]; do
    printf "$TIMER..."
    TIMER=`expr $TIMER - 1`
    sleep 1
done
echo ''

#perform home backup
sudo rsync -rave --stats --progress --delete $TOBACKUP $BACKUPDIR
