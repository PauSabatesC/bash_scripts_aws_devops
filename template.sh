#!/usr/bin/env bash

###################################################################################
# Made by github.com/PauSabatesC
#
# SUMMARY:
#
# USAGE:
# ./xxx.sh X X X
#
# EXAMPLE:
#
###################################################################################

VERSION=v0.1

# Make script safe to fail and not continue
set -euo pipefail

# Colors for output
COLOR_DEFAULT='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'

# Validation for required parameters
X=${1:-None}
if [[ "x${X}" = "xNone" ]]; then
  printf "${COLOR_RED}Usage:\n" >&2
  printf "  ./xxx.sh X X X\n" >&2
  exit 1
fi


#### Functions
printSectionHeaderLine() {
  printf "${COLOR_DEFAULT}-------------------------------------------------------------\n"
}

################## 1. CHECK PREREQUISITES FOR SCRIPT EXECUTION ##################
printSectionHeaderLine
printf "${COLOR_YELLOW}Verifying prerequisites for script ${VERSION} execution...  ${COLOR_DEFAULT}"

# Check if jq command exists
command -v jq >/dev/null 2>&1 && status="$?" || status="$?"
if [[ ! "${status}" = 0 ]]; then
  printf "${COLOR_RED}FAIL\n"
  printf "${COLOR_RED}Pre check failed: \`jq\` command is missing\n" >&2
  printSectionHeaderLine
  exit 1
fi

printf "${COLOR_GREEN}OK ${COLOR_DEFAULT}\n"
printSectionHeaderLine

