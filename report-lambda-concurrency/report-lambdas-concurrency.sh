#!/bin/bash

#################################################################
# This script creates a .csv file with the list of lambdas
# in an AWS account and its reserved and provisioned concurrency
#
# Usage:
#   ./report-lambdas-concurrency
#
#################################################################

set -euo pipefail #exits the execution if it occurrs an error, and error in a pipeline command e.g. "xxx | xxx" and variables unset.

function get_aws_account_id() {
  aws_account=$(aws sts get-caller-identity --query "Account" --output text)
  if [[ "$?" -ne 0  || -z "$aws_account" ]]; then
    printf "ERROR: Cannot obtain account id:\n" >&2
    printf $aws_account >&2
    exit 1
  fi
}

function pre_checks() {
  printf "INFO: Running pre checks..." >&1
  command -v aws >/dev/null 2>&1 && status="$?" || status="$?"
  if [ "${status}" -ne 0 ]; then
    printf "\nERROR: aws cli not installed.\n" >&2
    exit 1
  fi

  command -v jq >/dev/null 2>&1 && status="$?" || status="$?"
  if [ "${status}" -ne 0 ]; then
    printf "\nERROR: jq not installed.\n" >&2
    exit 1
  fi

  printf "OK\n" >&1
}

function get_lambdas() {
  lambdas=$(aws lambda list-functions --no-paginate --max-items=10000 | jq -c -r '.Functions[] | [.FunctionName]')
  lambdas=$(echo $lambdas | xargs -n1 | sort -f | xargs)
}

function get_and_print_concurrency() {
  printf "INFO: Getting concurrency data for lambdas in account ${aws_account}..."
  concurrency_used=0
  for lambda_name in $lambdas; do
    lambda_name_clean=$(echo $lambda_name | sed 's/\[//g; s/\]//g; s/\"//g;')
    concurrency=$(aws lambda get-function-concurrency --function-name $lambda_name_clean --no-paginate | jq .ReservedConcurrentExecutions)
    if [ -z $concurrency ];then 
      concurrency=0
    fi
    concurrency_used=$(($concurrency_used + $concurrency))
    sleep 1
    printf "${lambda_name_clean},${concurrency}\n" >> lambda_concurrency_report_${aws_account}.csv
  done

  printf "OK\n" >&1
}


function get_and_print_account_total_and_limit_concurrency() {
  printf "INFO: Getting concurrency quota limit and used..."

  quota=$(aws service-quotas list-service-quotas --service-code "lambda" | jq -c -r '.Quotas[] | select(.QuotaCode | contains("L-B99A9384"))')
  concurrency_total=$(echo $quota | jq .Value)
  printf "\n#######################################################\n" >> lambda_concurrency_report_${aws_account}.csv
  printf "ACCOUNT: ${aws_account}  Concurrency total: ${concurrency_total}  Concurrency used: ${concurrency_used}" >> lambda_concurrency_report_${aws_account}.csv
  printf "\n#######################################################\n" >> lambda_concurrency_report_${aws_account}.csv

  printf "OK\n" >&1
}

function print_csv_header() {
  printf "lambda_name,reserved_concurrency\n" > lambda_concurrency_report_${aws_account}.csv 
}

pre_checks
get_aws_account_id
print_csv_header
get_lambdas
get_and_print_concurrency
get_and_print_account_total_and_limit_concurrency
printf "INFO: Finished successfully. Output: lambda_concurrency_report_${aws_account}.csv\n"

