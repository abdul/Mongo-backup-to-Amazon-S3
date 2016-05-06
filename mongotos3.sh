#!/bin/sh

# Updates etc at: https://github.com/woxxy/MySQL-backup-to-Amazon-S3
# Under a MIT license

# change these variables to what you need
#MONGOADMIN=root
#MONGOPASSWORD=password
S3BUCKET=bucketname
FILENAME=filename
DATABASE=''
# the following line prefixes the backups with the defined directory. it must be blank or end with a /
S3PATH=mongo_backup/
# when running via cron, the PATHs MIGHT be different. If you have a custom/manual Mongo install, you should set this manually like MONGODUMPPATH=/usr/bin/mongodump
MONGODUMPPATH=
#tmp path.
TMP_PATH=~/tmp/mongo-backups/

DATESTAMP=$(date +".%m.%d.%Y")
DAY=$(date +"%d")
DAYOFWEEK=$(date +"%A")

PERIOD=${1-day}
if [ ${PERIOD} = "auto" ]; then
	if [ ${DAY} = "01" ]; then
        	PERIOD=month
	elif [ ${DAYOFWEEK} = "Sunday" ]; then
        	PERIOD=week
	else
       		PERIOD=day
	fi	
fi

echo "Selected period: $PERIOD."

echo "Starting backing up the database to a file..."

# dump all databases
${MONGODUMPPATH}mysqldump --db ${DATABASE} --out ${TMP_PATH}${FILENAME}

echo "Done backing up the database to a folder."
echo "Starting compression..."

tar czf ${TMP_PATH}${FILENAME}${DATESTAMP}.tar.gz ${TMP_PATH}${FILENAME}

echo "Done compressing the backup folder."

# we want at least two backups, two months, two weeks, and two days
echo "Removing old backup (2 ${PERIOD}s ago)..."
s3cmd del --recursive s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/
echo "Old backup removed."

echo "Moving the backup from past $PERIOD to another folder..."
s3cmd mv --recursive s3://${S3BUCKET}/${S3PATH}${PERIOD}/ s3://${S3BUCKET}/${S3PATH}previous_${PERIOD}/
echo "Past backup moved."

# upload all databases
echo "Uploading the new backup..."
s3cmd put -f ${TMP_PATH}${FILENAME}${DATESTAMP}.tar.gz s3://${S3BUCKET}/${S3PATH}${PERIOD}/
echo "New backup uploaded."

echo "Removing the cache files..."
# remove databases dump
# Uncomment only when you have set TMP_PATH and FILENAME; if these variables are unset, rm -rf can be something bad. 
#rm -rf ${TMP_PATH}${FILENAME}
rm ${TMP_PATH}${FILENAME}${DATESTAMP}.tar.gz
echo "Files removed."
echo "All done."
