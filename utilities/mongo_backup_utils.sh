#!/bin/bash

#Example run take_mongo_backups "${TEST_HOST}" "${TEST_PORT}" "${TEST_USERNAME}" "${TEST_PASSWORD}" "${TEST_AUTHENTICATION_DATABASE}" "${TEST_SSL_ENABLED}" "${TEST_CERTIFICATE}" "${TEST_BACKUP_DIRECTORY}" "${TEST_DATABASES}" "${TEST_BACKUP_SUFFIX}"
# ${1} Mongo host
# ${2} Mongo port
# ${3} Mongo username
# ${4} Mongo password
# ${5} Mongo authentication destination_database
# ${6} Mongo ssl enabled e.g. true
# ${7} Mongo certificate if any
# ${8} Backup directory /backups/mongo/entity-management/test/
# ${9} Comma separated destination_database names(do not use spaces) e.g. entity-management-test-2,batch-test-2
# ${10} Backup suffix e.g. _dump_
function take_mongo_backups() {
  local host="${1}"
  local port="${2}"
  local username="${3}"
  local password="${4}"
  local authentication_database="${5}"
  local ssl_enabled="${6}"
  local certificate="${7}"
  local backup_directory="${8}"
  local databases="${9}"
  local backup_suffix="${10}"
  local current_date=$(date +%Y%m%d-%H%M%S)

  for destination_database in ${databases//,/ }
  do
      local backup_name=${destination_database}${backup_suffix}${current_date}
      local database_backup_directory=${backup_directory}${backup_name}
      take_mongo_dump "${host}" "${port}" "${username}" "${password}" "${authentication_database}" "${ssl_enabled}" "${certificate}" "${destination_database}" "${database_backup_directory}"
  done
}

# Example usage take_mongo_dump "${host}" "${port}" "${username}" "${password}" "${authentication_database}" "${ssl_enabled}" "${certificate}" "${destination_database}" "${database_backup_directory}"
# ${1} Mongo host
# ${2} Mongo port
# ${3} Mongo username
# ${4} Mongo password
# ${5} Mongo authentication destination_database
# ${6} Mongo ssl enabled e.g. true
# ${7} Mongo certificate if any
# ${8} Mongo destination_database
# ${9} Backup destination_database directory e.g. /backups/mongo/entity-management/test/entity-management-test-2_dump_20220128-111834
function take_mongo_dump() {
  local host="${1}"
  local port="${2}"
  local username="${3}"
  local password="${4}"
  local authentication_database="${5}"
  local ssl_enabled="${6}"
  local certificate="${7}"
  local destination_database="${8}"
  local database_backup_directory="${9}"

  #Structure parameters based on input
  local parameters="--host ${host}"
  if [ -n "${port}" ]; then
    parameters="${parameters} --port ${port}"
  fi
  if [ -n "${username}" ] && [ -n "${password}" ] && [ -n "${authentication_database}" ]; then
    #@Q provides escaping for quoted parameter expansion e.g. & character in password could cause a problem if not quoted properly
    parameters="${parameters} --username ${username} --password ${password@Q} --authenticationDatabase ${authentication_database}"
  fi
  parameters="${parameters} --db ${destination_database}"
  if [ "${ssl_enabled}" = true ]; then
    parameters="${parameters} --ssl"
  fi
  if [ -n "${certificate}" ]; then
    parameters="${parameters} --sslCAFile <(echo -n '${certificate}')"
  fi
  parameters="${parameters} --out ${database_backup_directory} --gzip"
  printf "Starting backup with parameters: %s\n" "${parameters}"
  eval "mongodump ${parameters}"
}

# Example usage restore_backup "${host}" "${port}" "${username}" "${password}" "${authentication_database}" "${ssl_enabled}" "${certificate}" "${source_backup_directory}" "${source_database}" "${target_database}"
# ${1} Mongo host
# ${2} Mongo port
# ${3} Mongo username
# ${4} Mongo password
# ${5} Mongo authentication database
# ${6} Mongo ssl enabled e.g. true
# ${7} Mongo certificate if any
# ${8} Database directory e.g. e.g. /backups/mongo/entity-management/test/entity-management-test-2_dump_20220128-111834
# ${9} Source database e.g. entity-management-test-2
# ${10} Target database e.g. entity-management-acceptance.
function restore_backup(){
  local host=${1}
  local port=${2}
  local username="${3}"
  local password="${4}"
  local authentication_database="${5}"
  local ssl_enabled="${6}"
  local certificate="${7}"
  local database_directory=${8}
  local source_database=${9}
  local target_database=${10}

  local parameters="--host ${host}"
  if [ -n "${port}" ]; then
    parameters="${parameters} --port ${port}"
  fi
  if [ -n "${username}" ] && [ -n "${password}" ] && [ -n "${authentication_database}" ]; then
    #@Q provides escaping for quoted parameter expansion e.g. & character in password could cause a problem if not quoted properly
    parameters="${parameters} --username ${username} --password ${password@Q} --authenticationDatabase ${authentication_database}"
  fi
  if [ "${ssl_enabled}" = true ]; then
    parameters="${parameters} --ssl"
  fi
  if [ -n "${certificate}" ]; then
    parameters="${parameters} --sslCAFile <(echo -n '${certificate}')"
  fi

  parameters="${parameters} --nsFrom ${source_database}.* --nsTo ${target_database}.* --drop --gzip ${database_directory}"
  printf "Starting restore with parameters: %s\n" "${parameters}"
  eval "mongorestore ${parameters}"
}

function set_chosen_environment_fields_mongo_backup(){
  local environment=${1}
  local database_selection=${2}
  if [ -z "${environment}" ] || [ -z "${database_selection}" ]; then
    printf "ERROR: environment OR database selection is empty. Exiting..\n"
    exit 1
  fi

  # Compute variables with indirection
  name="${environment}_${database_selection}_DATABASE"
  DATABASE=${!name}
  name="${environment}_HOST"
  HOST=${!name}
  name="${environment}_PORT"
  PORT=${!name}
  name="${environment}_USERNAME"
  USERNAME=${!name}
  name="${environment}_PASSWORD"
  PASSWORD=${!name}
  name="${environment}_AUTHENTICATION_DATABASE"
  AUTHENTICATION_DATABASE=${!name}
  name="${environment}_SSL_ENABLED"
  SSL_ENABLED=${!name}
  name="${environment}_CERTIFICATE"
  CERTIFICATE=${!name}
  name="${environment}_BACKUP_DIRECTORY"
  BACKUP_DIRECTORY=${!name}
  name="${environment}_BACKUP_SUFFIX"
  BACKUP_SUFFIX=${!name}
}