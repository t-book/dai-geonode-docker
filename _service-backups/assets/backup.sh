#!/bin/sh

###########################################################
# Author: Toni Schönbuchner, contact: csgis.de
# Date: September 15 2020
# Purpose: Backup GeoNode Docker Instanse
# Written for: dainst.org
# Tested on: Alpine Linux
###########################################################

# this is read from env variables
# DRY_RUN=false
# SEND_MAIL=true
# SEND_SLACK=true

############################
# I. Variables             #
############################

set_variables(){
	# Currenct date
	NOW=$( date '+%d-%m-%y' )

	# DATABASE DEFINITION FROM DOCKER FILE
	DBS="$DATABASE $DATABASE_GEO"
	SCHEMAS="public"

	# Main backup dir with date
	BPTH=/backups/backup_${NOW}

	# Dir for backups
	DPTH=${BPTH}/databases

	# Dir for Geoserver data
	GPTH=${BPTH}/geoserver-data-dir

  # Create backup directories
	if [ $DRY_RUN = false ] ; then
		mkdir -p "${BPTH}"
		mkdir -p "${DPTH}"; mkdir -p "${DPTH}/full"; mkdir -p "${DPTH}/parts";
		mkdir -p "${GPTH}"
	fi

	# Directories to backup
	TO_BACKUP="/geonode_statics /geoserver-data-dir"

	# Server to Backup
	# this is read from env variables
	# BACKUP_HOST="virginiaplain07.klassarchaeologie.uni-koeln.de"
	# BACKUP_USER=csgis

	# Mount point of backup share's mount point and folder therein,
	# with write access on remote backup server machine.
	# this is read from env variables
	# BACKUP_MOUNT="/home/csgis/daicloud02"

	# Folder that exists within mount point's tree (relative path)
	# and will contain the backup data. BACKUP_USER must have
	# write access to this and it must already exist!
	# BACKUP_FOLDER="dai-backup-datadumps/iDAI.geoserver/v3"
	BACKUP_FOLDER_DB="$BACKUP_FOLDER/database_and_geoserver-config"
	BACKUP_FOLDER_BIN="$BACKUP_FOLDER/binary_files"

	# clear log
	echo "" > /tmp/result
}

############################
# I. Helper functions      #
############################

source ./helper_functions.sh
source ./colors.sh

############################
# II. BACKUP FUNCTIONS     #
############################

main(){
	# set global variables
	set_variables
	start_message

  # Initial checks
	test_mounted_drive_on_backup_server

	# Backup routine
	db_data_with_schema_backup
	db_schema_only_backup
	db_separated_table_backup
	files_sync_geoserver_config_to_local_folder
	db_restore_in_test_database
	files_copy_logs_to_backup_folder
	files_create_tar_from_local_folder
	copy_tar_archive_to_remote_server
	files_delete_old_backups
	files_sync_binary_to_remote

	# Good bye
	final_message
}

db_data_with_schema_backup(){
	for cur_db in $DBS; do
		printHeader "db_data_with_schema_backup: Processing Full Backup of DB: ${cur_db}"
		CMD="pg_dump -U postgres -h db -v -d ${cur_db} > ${DPTH}/full/${cur_db}.pgdump"
		if [ $DRY_RUN = false ] ; then
			if ! eval "$CMD"; then
				stopBackup "Full database backup for $cur_db via pg_dump\n CMD: $CMD"
			else
				printSuccess "Full database backup for $cur_db via pg_dump\n CMD: $CMD"
			fi
		else
	     printf "$CMD"
		fi
	done
}

db_schema_only_backup(){
	mkdir -p "${DPTH}/parts/schema"
	printHeader "db_schema_only_backup: Processing Schema Backup of DB: ${cur_db}"
	for cur_db in $DBS; do
		CMD="pg_dump -U postgres -h db --schema-only -d ${cur_db} > ${DPTH}/parts/schema/${cur_db}_schema.sql"

		if [ $DRY_RUN = false ] ; then
			if ! eval "$CMD"; then
				stopBackup "Schema database backup for ${cur_db} via pg_dump\n CMD: $CMD"
			else
				printSuccess ${PALETTE_GREEN}"Schema database backup for $cur_db via pg_dump"
			fi
		else
				printf "$CMD"
		fi
	done
}

db_separated_table_backup(){
	for cur_db in $DBS; do
		for cur_schema in $SCHEMAS; do
			printHeader "db_separated_table_backup: Processing Schema: ${cur_schema} from ${cur_db}"

			# contine loop if schema does not exist
			SCHEMA_EXIST=$(psql -U postgres -h db -d ${cur_db} -t -c  "SELECT schema_name FROM information_schema.schemata WHERE schema_name = '${cur_schema}'")
			if [ -z "$SCHEMA_EXIST" ]; then
				alert "Empty: Databse ${cur_db}, SELECT schema_name FROM information_schema.schemata WHERE schema_name = '${cur_schema}'"
				continue;
			fi

			mkdir -p ${DPTH}/parts/${cur_db}_${cur_schema}-single-tables/

			# Get names of all tables in current database and schema.
			SQL="\dt ${cur_schema}.*"
			TABLES=$(psql -U postgres -h db -d ${cur_db} -A -F';' -t -n -c "$SQL" | /usr/bin/cut -d';' -f2)
			# Dump single tables
			for table in $TABLES; do
				CMD="pg_dump -U postgres -h db -d ${cur_db} -t '\"$table\"' > ${DPTH}/parts/${cur_db}_${cur_schema}-single-tables/$table.sql"
				if [ $DRY_RUN = false ] ; then
					if ! eval "$CMD"; then
						stopBackup "Single table data backups for ${cur_db} schema ${table} via pg_dump\n CMD: $CMD"
					else
						printSuccess "Single table data backups for ${cur_db} schema ${cur_schema} via pg_dump\n CMD: $CMD"
					fi
				else
					printf "$CMD\n"
				fi
			done
		done
	done
}

db_restore_in_test_database(){

	for cur_db in $DBS; do
		printHeader "db_restore_in_test_database: Processing Test Restore DB: ${cur_db}"

		CMD_CREATE_DB="psql -U postgres -h db -c  \"CREATE DATABASE ${cur_db}_restore_test WITH TEMPLATE = template0 ENCODING='UTF8' LC_COLLATE='en_US.utf8' LC_CTYPE='en_US.utf8';\""
		CMD_RESTORE="cat ${DPTH}/full/${cur_db}.pgdump | psql -U postgres -h db -d ${cur_db}_restore_test"
		CMD_DROP="psql -U postgres -h db -c  \"DROP DATABASE IF EXISTS ${cur_db}_restore_test;\""

		if [ $DRY_RUN = false ] ; then
			# Restore files
			if ! eval "$CMD_CREATE_DB"; then
				stopBackup "Creation of ${cur_db}_restore_test\n CMD: $CMD_CREATE_DB"
			else
				printSuccess "Creation of ${cur_db}_restore_test\n CMD: $CMD_CREATE_DB"
			fi

			# Restore files
			if ! eval "$CMD_RESTORE"; then
				stopBackup "Restore for ${DPTH}/full/${cur_db}.pgdump in ${cur_db}_restore_test\n CMD: $CMD_RESTORE"
			else
				printSuccess "Restore for ${DPTH}/full/${cur_db}.pgdump in ${cur_db}_restore_test\n CMD: $CMD_RESTORE"
			fi

			# Drop Test Database
			if ! eval "$CMD_DROP"; then
				stopBackup "Drop of ${cur_db}_restore_test\n CMD: $CMD_DROP"
			else
				printSuccess "Drop of ${cur_db}_restore_test\n CMD: $CMD_DROP"
			fi

		else
	     printf "$CMD_CREATE_DB\n"
	     printf "$CMD_RESTORE\n"
	     printf "$CMD_DROP\n"
		fi
	done

}

files_sync_geoserver_config_to_local_folder(){
	printHeader "files_sync_geoserver_config_to_local_folder: Copy geoserver data dir config files from ${GPTH} to ${GPTH}"
	CMD="rclone copy /geoserver-data-dir "${GPTH}" --exclude-from exclude_from_config_copy.txt --log-level ERROR"
	if [ $DRY_RUN = false ] ; then
		if ! eval "$CMD"; then
			stopBackup "Config of /geoserver-data-dir could not be copied to ${GPTH}\n CMD: $CMD"
		else
			printSuccess "Config of /geoserver-data-dir copied to ${GPTH}\n CMD: $CMD"
		fi
	else
		printf "$CMD\n"
	fi
}

files_copy_logs_to_backup_folder(){
	CMD="cp /tmp/result ${BPTH}/backup_log"
	if [ $DRY_RUN = false ]; then
		if ! eval "$CMD"; then
			stopBackup "Copy Logfile\n CMD: $CMD"
		else
			printSuccess "Copy Logfile\n CMD: $CMD"
		fi
	else
		printf "$CMD\n"
	fi
}

files_create_tar_from_local_folder(){
	printHeader "files_create_tar_from_local_folder: ${BPTH} to /backups/dai-geonode.tar_$NOW.bz2"
	CMD="tar cvfj /backups/dai-geonode.tar_$NOW.bz2 ${BPTH}"
	if [ $DRY_RUN = false ]; then
		if ! eval "$CMD"; then
			stopBackup "Tar error for dai-geonode.tar_$NOW.bz2\n CMD: $CMD"
		else
			printSuccess "Created dai-geonode.tar_$NOW.bz2\n CMD: $CMD"
		fi
	else
		printf "$CMD\n"
	fi
}

copy_tar_archive_to_remote_server(){
	printHeader "copy_tar_archive_to_remote_server: Copy /backups/dai-geonode.tar_$NOW.bz2 to ${BACKUP_HOST}"
	CMD="scp /backups/dai-geonode.tar_$NOW.bz2 ${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_MOUNT}/${BACKUP_FOLDER_DB}"
	if [ $DRY_RUN = false ]; then
		if ! eval "$CMD"; then
			stopBackup "SCP for dai-geonode.tar_$NOW.bz2\n to ${BACKUP_HOST}\n CMD: $CMD"
		else
			printSuccess "SCP for dai-geonode.tar_$NOW.bz2\n to ${BACKUP_HOST}\nCMD: $CMD"
		fi
	else
		printf "$CMD\n"
	fi
}

files_delete_old_backups(){
	printHeader "files_delete_old_backups: Delete ${BPTH} /backups/dai-geonode.tar_$NOW.bz2"
	CMD="rm -rf ${BPTH} /backups/dai-geonode.tar_$NOW.bz2"
	if [ $DRY_RUN = false ]; then
		if ! eval "$CMD"; then
			stopBackup "Delete ${BPTH} /backups/dai-geonode.tar_$NOW.bz2"
		else
			printSuccess "Deleted ${BPTH} /backups/dai-geonode.tar_$NOW.bz2"
		fi
	else
		printf "$CMD\n"
	fi
}

files_sync_binary_to_remote(){
	for backup_directory in $TO_BACKUP; do
		CMD="rsync -avzh --progress ${backup_directory} ${BACKUP_USER}@${BACKUP_HOST}:${BACKUP_MOUNT}/${BACKUP_FOLDER_BIN}"
		if [ $DRY_RUN = false ]; then
			if ! eval "$CMD"; then
				stopBackup "Error while running rsync for ${backup_directory}"
			else
				printSuccess "rsync for ${backup_directory} succeeded"
			fi
		else
			printf "$CMD\n"
		fi
	done
}

# run
main "$@" | tee /tmp/result

