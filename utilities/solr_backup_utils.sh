#!/bin/bash

# It will create a database dump in the directory specified under a directory that has name the database name the suffix and a date.
# The backup will be initiated with an async id, checked periodically and finally, when completed, it will remove the async id.
# Make sure the runner of this script has same permissions as the user of the solr that we are taking a backup from.
# Example usage take_solr_backup "${HOST}" "${PORT}" "${DATABASE}" "${BACKUP_DIRECTORY}" "${BACKUP_SUFFIX}"
# ${1} Solr host
# ${2} Solr port
# ${3} Solr database e.g. the collection name
# ${4} Backup directory /backups/solr/solr-entity-management/test/
# ${5} Backup suffix e.g. _dump_
function take_solr_backup() {
  local host="${1}"
  local port="${2}"
  local database="${3}"
  local backup_directory="${4}"
  local backup_suffix="${5}"

  start_solr_backup "${host}" "${port}" "${database}" "${backup_directory}" "${backup_suffix}"
  monitor_solr_request_status "${host}" "${port}" "${database}"
  remove_solr_status_request_id "${host}" "${port}" "${database}"
}

# Restores a Solr collection.
# This function will do the following
# - Delete a previous solr collection if existent
# - Start a Solr restore request
# - Monitor the Solr request and remove the request id when done
# Example usage restore_solr_backup "${HOST}" "${PORT}" "${DATABASE}" "${REPLICATION_FACTOR}" "${SOURCE_LATEST_BACKUP_DIRECTORY}"
# ${1} Solr host
# ${2} Solr port
# ${3} Solr database e.g. the collection name
# ${4} Solr replication factor for the new collection
# ${5} The absolute directory path for the database to be restored e.g. /backups/solr/solr-entity-management/test/entity-management-migration_dump_20220131-140133
function restore_solr_backup() {
  local host="${1}"
  local port="${2}"
  local database="${3}"
  local replication_factor="${4}"
  local source_latest_backup_directory="${5}"

  delete_solr_collection "${host}" "${port}" "${database}"
  start_solr_restore "${host}" "${port}" "${database}" "${replication_factor}" "${source_latest_backup_directory}"
  monitor_solr_request_status "${host}" "${port}" "${database}"
  remove_solr_status_request_id "${host}" "${port}" "${database}"
}

# It will create a database dump in the directory specified under a directory that has name the database name the suffix and a date.
# It will initiate the remote backup.
# Example usage start_solr_backup "${host}" "${port}" "${database}" "${backup_directory}" "${backup_suffix}"
# ${1} Solr host
# ${2} Solr port
# ${3} Solr database e.g. the collection name. This will also be used for the async id.
# ${4} Backup directory /backups/solr/solr-entity-management/test/
# ${5} Backup suffix e.g. _dump_
function start_solr_backup() {
  local host="${1}"
  local port="${2}"
  local database="${3}"
  local backup_directory="${4}"
  local backup_suffix="${5}"

  local current_date=$(date +%Y%m%d-%H%M%S)
  local solr_endpoint="${host}:${port}/solr/"

  local backup_name=${database}${backup_suffix}${current_date}
  local database_backup_directory=${backup_directory}

  #Parent directory has to be present before we run the backup but not the specific database directory
  mkdir -p "${database_backup_directory}"
  chmod 777 "${database_backup_directory}" #Update this so that the remote solr can write to the directory if not in the group
  chmod g+s "${database_backup_directory}" #Setup the group id to get same group permissions on the created files

  local parameters="admin/collections?action=BACKUP&name=${backup_name}&collection=${database}&location=${database_backup_directory}&async=${database}"
  printf "Starting backup with parameters: %s\n" "${solr_endpoint}${parameters}"
  curl "${solr_endpoint}${parameters}"
}

# It will monitor periodically the status of a task using the
# Required jq command to be available in the system
# Example usage monitor_solr_request_status "${host}" "${port}" "${database}"
# ${1} Solr host
# ${2} Solr port
# ${3} Solr request_id e.g. use the same that was used as async id on another command
function monitor_solr_request_status() {
  local host="${1}"
  local port="${2}"
  local request_id="${3}"
  local solr_endpoint="${host}:${port}/solr/"

  local parameters="admin/collections?action=REQUESTSTATUS&requestid=${request_id}"
  local retrieve_status_command="curl '${solr_endpoint}${parameters}' | jq -r '.status.state'"
  local sleep_time="30"

  local backup_status
  printf "Check backup status with parameters: %s\n" "${solr_endpoint}${parameters}"
  backup_status=$(eval "${retrieve_status_command}")
  while [ "${backup_status}" = "running" ]; do
    printf "Backup status: %s, sleeping for %s\n" "${backup_status}" "${sleep_time}"
    sleep "${sleep_time}"
    printf "Check backup status with parameters: %s\n" "${solr_endpoint}${parameters}"
    backup_status=$(eval "${retrieve_status_command}")
  done
  printf "Finished monitoring with final status: %s\n" "${backup_status}"
}

# Removes the request id provided
# Example usage remove_solr_status_request_id "${host}" "${port}" "${database}"
# ${1} Solr host
# ${2} Solr port
# ${3} Solr request_id e.g. use the same that was used as async id on another command
function remove_solr_status_request_id() {
  local host="${1}"
  local port="${2}"
  local request_id="${3}"
  local solr_endpoint="${host}:${port}/solr/"

  local parameters="admin/collections?action=DELETESTATUS&requestid=${request_id}"
  printf "Remove status with parameters: %s\n" "${solr_endpoint}${parameters}"
  curl "${solr_endpoint}${parameters}"
}

# Deletes a solr collection.
# Example usage delete_solr_collection "${host}" "${port}" "${database}"
# ${1} Solr host
# ${2} Solr port
# ${3} Solr database/collection to delete
function delete_solr_collection() {
  local host="${1}"
  local port="${2}"
  local database="${3}"
  local solr_endpoint="${host}:${port}/solr/"
  local parameters="admin/collections?action=DELETE&name=${database}"
  printf "Starting removal of collection with parameters: %s\n" "${solr_endpoint}${parameters}"
  curl "${solr_endpoint}${parameters}"
}

# Start a Solr restore.
# Example usage start_solr_restore "${host}" "${port}" "${database}" "${replication_factor}" "${source_backup_directory}"
# ${1} Solr host
# ${2} Solr port
# ${3} Solr database/collection to create
# ${4} Solr replication factor for the new collection
# ${5} The absolute directory path for the database to be restored e.g. /backups/solr/solr-entity-management/test/entity-management-migration_dump_20220131-140133
function start_solr_restore() {
  local host="${1}"
  local port="${2}"
  local database="${3}"
  local replication_factor="${4}"
  local source_backup_directory="${5}"
  local solr_endpoint="${host}:${port}/solr/"

  local absolute_parent_database_directory
  absolute_parent_database_directory="$(dirname "${source_backup_directory}")"
  local database_directory
  database_directory=$(basename "${source_backup_directory}")

  local parameters="admin/collections?action=RESTORE&name=${database_directory}&collection=${database}&location=${absolute_parent_database_directory}&replicationFactor=${replication_factor}&async=${database}"
  printf "Starting restore with parameters: %s\n" "${solr_endpoint}${parameters}"
  curl "${solr_endpoint}${parameters}"
}

# Initializes the following global environment variables best on provided parameters
# "${HOST}" "${PORT}" "${BACKUP_DIRECTORY}" "${BACKUP_SUFFIX}" "${DATABASE}"
# Example usage set_chosen_environment_fields_solr_backup ${ENVIRONMENT} ${DATABASE_SELECTION}
# ${1} environment
# ${2} Database selection
function set_chosen_environment_fields_solr_backup(){
  local environment=${1}
  local database_selection=${2}
  if [ -z "${environment}" ] || [ -z "${database_selection}" ]; then
    printf "ERROR: DATABASE_SELECTION is empty. Exiting..\n"
    exit 1
  fi

  # Compute variables with indirection
  name="${environment}_${database_selection}_DATABASE"
  DATABASE=${!name}
  name="${environment}_HOST"
  HOST=${!name}
  name="${environment}_PORT"
  PORT=${!name}
  name="${environment}_BACKUP_DIRECTORY"
  BACKUP_DIRECTORY=${!name}
  name="${environment}_BACKUP_SUFFIX"
  BACKUP_SUFFIX=${!name}
}

# Initializes the following global environment variables best on provided parameters
# "${HOST}" "${PORT}" "${REPLICATION_FACTOR}"  "${SOURCE_DATABASE}" "${SOURCE_BACKUP_DIRECTORY}" "${SOURCE_BACKUP_SUFFIX}" "${DATABASE}"
# Example usage set_chosen_environment_fields_solr_restore ${SOURCE_ENVIRONMENT} ${TARGET_ENVIRONMENT} ${DATABASE_SELECTION}
# ${1} Source environment
# ${2} Target environment
# ${3} Database selection
function set_chosen_environment_fields_solr_restore() {
  local source_environment=${1}
  local target_environment=${1}
  local database_selection=${3}
  if [ -z "${source_environment}" ] || [ -z "${target_environment}" ] || [ -z "${database_selection}" ]; then
    printf "ERROR: SOURCE_ENVIRONMENT OR TARGET_ENVIRONMENT OR DATABASE_SELECTION is empty. Exiting..\n"
    exit 1
  fi

  # Compute variables with indirection
  # SOURCE
  name="${source_environment}_${database_selection}_DATABASE"
  SOURCE_DATABASE=${!name}
  name="${source_environment}_BACKUP_DIRECTORY"
  SOURCE_BACKUP_DIRECTORY=${!name}
  name="${source_environment}_BACKUP_SUFFIX"
  SOURCE_BACKUP_SUFFIX=${!name}
  # TARGET
  name="${target_environment}_${database_selection}_DATABASE"
  DATABASE=${TEST_ENTITY_MANAGEMENT_DATABASE}
  name="${target_environment}_HOST"
  HOST=${TEST_HOST}
  name="${target_environment}_PORT"
  PORT=${TEST_PORT}
  name="${target_environment}_REPLICATION_FACTOR"
  REPLICATION_FACTOR=${TEST_REPLICATION_FACTOR}
}