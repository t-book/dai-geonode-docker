#!/bin/sh

# helper for sending notifications to backup channel
sendSlack () {
	curl -g -X POST -H "Content-type: application/json" --data "{\"text\": \"$1\"}" ${SLACK_TOKEN}
}

# Helper function alert
alert(){
	echo -e ${PALETTE_RED}"Warning: $1\n"${PALETTE_RESET}
}

# Helper function quit process
stopBackup(){
	LOG=$(cat /tmp/result)
	rm -f /tmp/result
	echo -e ${PALETTE_RED}"FAILED: $1\n"${PALETTE_RESET}
	if [ $SEND_MAIL =  true]; then
		(echo "Subject: $1"; echo "From: ${DJANGO_EMAIL_HOST_USER}"; echo "To: ${REPORTS_TO}"; echo ""; echo "${LOG}") | /usr/sbin/ssmtp ${REPORTS_TO}
	fi
	if [ $SEND_SLACK =  true ]; then
		sendSlack "$1"
	fi
	exit 1
}

# Format Header
printHeader(){
	echo -e ${PALETTE_REVERSE}"\n\n$1\n"${PALETTE_RESET}
}

# Success Message
start_message(){
	MSG="Started backup $( date '+%d-%m-%y %H:%M' ) on $SITEURL"
	printHeader "$MSG"
	if [ $SEND_SLACK =  true ]; then
		sendSlack "$MSG"
	fi
	if [ $SEND_MAIL =  true]; then
		(echo "Subject: ${MSG}"; echo "From: ${DJANGO_EMAIL_HOST_USER}"; echo "To: ${REPORTS_TO}"; echo ""; echo "${MSG}") | /usr/sbin/ssmtp ${REPORTS_TO}
	fi
}

# Success Message
final_message(){
	MSG="Ended backup $( date '+%d-%m-%y %H:%M' ) on $SITEURL"
	printHeader "$MSG"
	if [ $SEND_SLACK =  true ]; then
		sendSlack '$MSG'
	fi
	if [ $SEND_MAIL =  true]; then
		(echo "Subject: ${MSG}"; echo "From: ${DJANGO_EMAIL_HOST_USER}"; echo "To: ${REPORTS_TO}"; echo ""; echo "${MSG}") | /usr/sbin/ssmtp ${REPORTS_TO}
	fi
}

# Success Message
printSuccess(){
	echo -e ${PALETTE_GREEN}"SUCCESS: $1\n"${PALETTE_RESET}
	if [ $SEND_SLACK =  true ]; then
		sendSlack 'SUCCESS: $1'
	fi
}

# Test if Backup Drive is mounted
test_mounted_drive_on_backup_server(){
	printHeader "test if drive is mounted."
	MOUNT_ENTRY=$(ssh ${BACKUP_USER}@${BACKUP_HOST} mount | grep $BACKUP_MOUNT)
	if [[ -n "$MOUNT_ENTRY" ]] ; then
	  printSuccess "mount ${BACKUP_MOUNT} found on ${BACKUP_HOST}"
	else
		stopBackup "Backup mount '$BACKUP_MOUNT' not mounted on ${BACKUP_HOST} or SSH connection failed!"
	fi
}

