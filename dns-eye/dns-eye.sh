#!/usr/bin/env bash

###################################################################################
# Made by github.com/PauSabatesC
#
# SUMMARY:
# Get useful data regarding a domain name in one command.
#
# USAGE:
# ./dns-eye.sh URL
#
# EXAMPLE:
# ./dns-eye.sh google.com
###################################################################################

VERSION="v0.1"

# Make script safe to fail and not continue
#set -euo pipefail

# Colors for output
COLOR_DEFAULT='\033[0m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_GREEN='\033[0;32m'

# Validation for required parameters
URL=${1:-None}
if [[ "${URL}" = "None" ]]; then
  printf "${COLOR_RED}Usage:\n" >&2
  printf "  ./dns-eye.sh URL\n" >&2
  exit 1
fi


#### Functions
printSectionHeaderLine() {
  printf "${COLOR_DEFAULT}-------------------------------------------------------------\n"
}

printOutput() {
  arr=("$@")
  for i in "${arr[@]}"
  do
    printf " $i "
  done
  printf "\n"
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

# Check if nslookup command exists
command -v nslookup >/dev/null 2>&1 && status="$?" || status="$?"
if [[ ! "${status}" = 0 ]]; then
  printf "${COLOR_RED}FAIL\n"
  printf "${COLOR_RED}Pre check failed: \`nslookup\` command is missing\n" >&2
  printSectionHeaderLine
  exit 1
fi

# Check if curl command exists
command -v curl >/dev/null 2>&1 && status="$?" || status="$?"
if [[ ! "${status}" = 0 ]]; then
  printf "${COLOR_RED}FAIL\n"
  printf "${COLOR_RED}Pre check failed: \`curl\` command is missing\n" >&2
  printSectionHeaderLine
  exit 1
fi

# Check if dig command exists
command -v dig >/dev/null 2>&1 && status="$?" || status="$?"
if [[ ! "${status}" = 0 ]]; then
  printf "${COLOR_RED}FAIL\n"
  printf "${COLOR_RED}Pre check failed: \`dig\` command is missing\n" >&2
  printSectionHeaderLine
  exit 1
fi

printf "${COLOR_GREEN}OK ${COLOR_DEFAULT}\n"
printSectionHeaderLine


################## 2. Get DNS ips ##################
ips=($(nslookup ${URL} | grep -i Address | awk '{print $2}'))

printf "${COLOR_YELLOW}DNS Used: ${COLOR_DEFAULT}"
dns_ip=$(echo "${ips[0]}" | rev | cut -c4- | rev)
len=${#dns_ip}
if [ $len -gt 0 ]; then
  printOutput "${dns_ip}" # first ip is dns
else
  printf "${COLOR_RED} No DNS found. ${COLOR_DEFAULT}\n"
  exit 1
fi
printSectionHeaderLine

################## Get CNAMEs redirects ##################
printf "${COLOR_YELLOW}CNAME Redirects: ${COLOR_DEFAULT}"
cnames=($(dig +noall +answer ${URL} | grep CNAME | awk '{print $5}' | rev | cut -c2- | rev))
len=${#cnames[@]}
ORIGINAL_URL=$URL
if [ $len -gt 0 ]; then
  printOutput ${cnames[@]}
  URL=$(echo ${cnames[0]})
else
  printf "None.\n"
fi
printSectionHeaderLine

printf "${COLOR_YELLOW}Non Authoritative Response: ${COLOR_DEFAULT}"
ips=($(dig +short ${URL}))
len=${#ips[@]}
if [ $len -gt 0 ]; then
  printOutput "${ips[@]}" #removed first unwanted argument
else
  printf "${COLOR_RED} No IPs found. ${COLOR_DEFAULT}\n"
  exit 1
fi
printSectionHeaderLine

printf "${COLOR_YELLOW}Authoritative Server: ${COLOR_DEFAULT}"
auth_dns=($(dig +short NS ${URL} | rev | cut -c2- | rev))
len=${#auth_dns}
if [ $len -gt 0 ]; then
  printOutput "${auth_dns[@]}"
else
  printf "${COLOR_RED} No other authoritative server found. ${COLOR_DEFAULT}\n"
  ignore_auth_server=true
fi
printSectionHeaderLine

if [ ! $ignore_auth_server ]; then
  printf "${COLOR_YELLOW}Authoritative Response of ${auth_dns[0]}: ${COLOR_DEFAULT}"
  auth_ips=($(nslookup ${URL} ${auth_dns[0]} | grep -i Address | awk '{print $2}'))
  len=${#auth_ips[@]}
  if [ $len -gt 0 ]; then
    printOutput "${auth_ips[@]:1}" #removed first unwanted argument
  else
    printf "${COLOR_RED} No IPs found. ${COLOR_DEFAULT}\n"
    exit 1
  fi
  printSectionHeaderLine
fi

################## 3. Get Route Gateway ##################
printf "${COLOR_YELLOW}Route Gateway to access ${ips[0]}: ${COLOR_DEFAULT}"
route=($(netstat -rn | grep "${ips[0]}" | awk '{print $1}'))
len=${#route[@]}
if [ $len -gt 0 ]; then
  printOutput "${route[@]}"
else
  printf "Default\n"
fi

if [ ! $ignore_auth_server ]; then
  printf "${COLOR_YELLOW}Route Gateway to access ${auth_ips[1]}: ${COLOR_DEFAULT}"
  route=($(netstat -rn | grep "${auth_ips[1]}" | awk '{print $1}'))
  len=${#route[@]}
  if [ $len -gt 0 ]; then
    printOutput "${route[@]}"
  else
    printf "Default\n"
  fi
fi
printSectionHeaderLine

################## 5. Get Geographic of IPs ##################
printf "${COLOR_YELLOW}Location of ${ips[0]} : ${COLOR_DEFAULT}"
ipinfo=$(curl -s ipinfo.io/${ips[0]})
country=$(echo $ipinfo | jq '.country' | tr -d '"')
region=$(echo $ipinfo | jq '.region' | tr -d '"')
printOutput "$country/$region"

if [ ! $ignore_auth_server ]; then
  printf "${COLOR_YELLOW}Location of ${auth_ips[1]} : ${COLOR_DEFAULT}"
  ipinfo=$(curl -s ipinfo.io/${auth_ips[1]})
  country=$(echo $ipinfo | jq '.country' | tr -d '"')
  region=$(echo $ipinfo | jq '.region' | tr -d '"')
  printOutput "$country/$region"
fi
printSectionHeaderLine

################## 6. Get My Public and Private IPs ##################
printf "${COLOR_YELLOW}My private/public IP: ${COLOR_DEFAULT}"
private_ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1')
public_ip=$(dig @resolver4.opendns.com myip.opendns.com +short)
printOutput "$private_ip / $public_ip"
printSectionHeaderLine

################## 8. Get Headers and Redirects ##################
printf "${COLOR_YELLOW}Headers and Location Redirects: ${COLOR_DEFAULT}\n"
#curl -IL -s -X GET $ORIGINAL_URL | grep 'Server\|Location\|X-Powered-By\|Cache-Control\|HTTP' | sed 's/HTTP/\n&/g'
curl -IL -m 5 -s -X GET $ORIGINAL_URL
printSectionHeaderLine


################## 9. Download webpage response if not show no data to download after X seconds ##################
printf "${COLOR_YELLOW}Get request download: ${COLOR_DEFAULT} "
file_path="/tmp/dns-eye-curl-$(date "+%F-%T").html"
curl -L -m 7 -s -X GET $ORIGINAL_URL > $file_path 
if [ "$?" = 0 ]; then
  printOutput $file_path
else
  printOutput "${COLOR_RED}Failed to save response :(${COLOR_DEFAULT}"
fi
printSectionHeaderLine

