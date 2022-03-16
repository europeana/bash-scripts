#!/bin/bash

#This function removes spaces and CRLF from a passed certificate file and returns the string representation to be stored to a variable
#Example usage clear_certificate_from_spaces_and_crlf "$(</path/to/certificate.cer)"
function clear_certificate_from_spaces_and_crlf {
  echo "${1}" | sed 's/ *//' | sed 's/\r$//'
}

#Finds the latest (sorted) directory using the prefix supplied
# ${1} The directory prefix e.g. /backups/solr/solr-entity-management/acceptance/entity-management-acceptance_dump_
function get_latest_directory_with_prefix {
  local result=$(find "${1}"* -maxdepth 0 -mindepth 0 | sort | tail -1)
  echo "${result}"
}