#!/bin/bash

# Example run remove_old_backups "${retention}" "${backup_directory}" "${databases}" "${backup_suffix}"
# Removes directories based on their sorted order(example date suffices).
# By default it runs on dry run mode. Changes the last argument to true to do a real deletion of directories
# ${1} Retention policy e.g. 2
# ${2} absolute path to the directory that contains directories per database e.g. /backups/mongo/entity-management/test/
# ${3} Comma separated database names(do not use spaces) e.g. entity-management-test-2,batch-test-2
# ${4} Backup suffix e.g. _dump_
# ${5} Real run. By default the script runs on dry run. Set to true to do a real deletion of directories
function remove_old_backups() {
  local retention="${1}"
  local backup_directory="${2}"
  local databases="${3}"
  local backup_suffix="${4}"
  local real_run="${5}"

  for database in ${databases//,/ }
  do
      local backup_directory_prefix="${backup_directory}${database}${backup_suffix}"
      remove_old_directories_for_directory_prefix "${retention}" "${backup_directory_prefix}" "${real_run}"
  done
}

#Example run remove_old_directory_for_directory_prefix "${retention}" "${directory_prefix}"
#It's meant to search and sort directories with a prefix name provided(for example sort for directories that contain a date suffix).
#It will remove the lowest by name sort
# ${1} Retention policy e.g. 2
# ${2} Directory prefix e.g. /backups/mongo/entity-management/test/entity-management-test-2_dump_
# ${3} Real run. By default the script runs on dry run. Set to true to do a real deletion of directories
function remove_old_directories_for_directory_prefix() {
  local retention="${1}"
  local directory_prefix="${2}"
  local real_run="${3}"

  printf "Checking to remove directories with prefix: %s\n" "${directory_prefix}"
  local directory_list=$(find "${directory_prefix}"* -maxdepth 0 -mindepth 0 | sort)
  local directory_list_count=$(echo "${directory_list}" | wc -l)
  #Check if the number of directories surpasses the retention policy
  local remove_count=$(("${directory_list_count}" - "${retention}"))
  if [ "${remove_count}" -gt 0 ]; then {
    local directories_to_remove=$(echo "${directory_list}" | head -"${remove_count}")
    if [ "${real_run}" != "true" ]; then
      printf "This is a dry run! No directories will be removed\n"
    fi

    printf "Directories to remove: \n%s\n" "${directories_to_remove}"
    if [ "${real_run}" = "true" ]; then
      while IFS= read -r directory_to_remove; do
        printf "Removing directory: %s\n" "${directory_to_remove}"
        rm -r "${directory_to_remove}"
      done <<< "${directories_to_remove}"
    fi
  }
  fi
}