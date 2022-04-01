#!/usr/bin/env bash

set -e

##############################################################
# This simple script starts a new blue/green deploy on AWS ECS
#  updating the last task definition with the new docker 
#  image tag provided.
#
# Usage:
#   ./ecs_deploy.sh {env} {docker_image}
#
##############################################################

################### VARIABLES ################################
ENV=${1-:None} #stg,prd
DOCKER_IMAGE_TAG=${2-:None}
AWS_CLI=$(which aws)
AWS_ECS="$AWS_CLI --output json ecs"

################### FUNCTIONS ################################
function printSectionLine() {
  printf " ------------------------------------------------------------\n" >&1
}

function preChecks() {
  command -v $AWS_CLI >/dev/null 2>&1 && status="$?" || status="$?"
  if [[ ! "${status}" = 0 ]]; then
    printf "ERROR: Pre check failed: \`aws\` command is missing\n" >&2
    exit 1
  fi

  command -v jq >/dev/null 2>&1 && status="$?" || status="$?"
  if [[ ! "${status}" = 0 ]]; then
    printf "ERROR: Pre check failed: \`jq\` command is missing\n" >&2
    exit 1
  fi
}

function check_params() {
  if [ $ENV = "stg" ]; then
    CLUSTER_NAME="staging"
    TASK_FAMILY="familyNameStg"
    SERVICE_NAME="serviceNameStg"
  elif [ $ENV = "prd" ]; then
    CLUSTER_NAME="production"
    TASK_FAMILY="familyNamePrd"
    SERVICE_NAME="serviceNamePrd"
  else
    echo "ERROR: Environment should be 'stg' or 'prd'."
    exit 1
  fi
}

function get_current_task_definition() {
    # Use the most recently created task definition of the family rather than the most recently used.
    TASK_DEFINITION_ARN=`$AWS_ECS describe-services --services $SERVICE_NAME --cluster $CLUSTER_NAME | jq -r .services[0].taskDefinition`
    TASK_DEFINITION_FAMILY=`$AWS_ECS describe-task-definition --task-def $TASK_DEFINITION_ARN | jq -r .taskDefinition.family`
    TASK_DEFINITION=`$AWS_ECS describe-task-definition --task-def $TASK_DEFINITION_FAMILY --include TAGS`
    TASK_DEFINITION_ARN=`$AWS_ECS describe-task-definition --task-def $TASK_DEFINITION_FAMILY | jq -r .taskDefinition.taskDefinitionArn`
    TASK_DEFINITION_TAGS=$( echo "$TASK_DEFINITION" | jq ".tags" )

  if [[ -z "$TASK_DEFINITION" || -z "$TASK_DEFINITION_ARN" || -z "$TASK_DEFINITION_FAMILY" ]]; then
    printf "ERROR: Failed to get current task definition\n" >&2
    exit 1
  fi
}

function create_new_task_definition() {
  DEF=$( echo "$TASK_DEFINITION" \
        | sed -e "s|\(\"image\": *\".*:\)\(.*\)\"|\1${DOCKER_IMAGE_TAG}\"|g" \
        | jq '.taskDefinition' )
  
  # Default JQ filter for new task definition
  NEW_DEF_JQ_FILTER="family: .family, volumes: .volumes, containerDefinitions: .containerDefinitions, placementConstraints: .placementConstraints"

  # Some options in task definition should only be included in new definition if present in
  # current definition. If found in current definition, append to JQ filter.
  CONDITIONAL_OPTIONS=(networkMode taskRoleArn placementConstraints executionRoleArn)
  for i in "${CONDITIONAL_OPTIONS[@]}"; do
    re=".*${i}.*"
    if [[ "$DEF" =~ $re ]]; then
      NEW_DEF_JQ_FILTER="${NEW_DEF_JQ_FILTER}, ${i}: .${i}"
    fi
  done

  # Updated jq filters for AWS Fargate
  REQUIRES_COMPATIBILITIES=$(echo "${DEF}" | jq -r '. | select(.requiresCompatibilities != null) | .requiresCompatibilities[]')
  if `echo ${REQUIRES_COMPATIBILITIES[@]} | grep -q "FARGATE"`; then
    FARGATE_JQ_FILTER='requiresCompatibilities: .requiresCompatibilities, cpu: .cpu, memory: .memory'

    if [[ ! "$NEW_DEF_JQ_ILTER" =~ ".*executionRoleArn.*" ]]; then
      FARGATE_JQ_FILTER="${FARGATE_JQ_FILTER}, executionRoleArn: .executionRoleArn"
    fi
    NEW_DEF_JQ_FILTER="${NEW_DEF_JQ_FILTER}, ${FARGATE_JQ_FILTER}"
  fi

  # Build new DEF with jq filter
  NEW_DEF=$(echo "$DEF" | jq "{${NEW_DEF_JQ_FILTER}}")
}

function deploy_new_task_definition() {
  NEW_TASK_DEFINITION=`$AWS_ECS register-task-definition --cli-input-json "$NEW_DEF" --tags "$TASK_DEFINITION_TAGS" | jq -r .taskDefinition.taskDefinitionArn`
  if [[ ! "$?" = 0 || -z "$NEW_TASK_DEFINITION" ]]; then
    printf "ERROR: Failed to deploy new task definition\n" >&2
    exit 1
  fi
}

function update_ecs_service() {
  printf "Updating Cluster: $CLUSTER_NAME \n" >&1
  printf "Service: $SERVICE_NAME \n" >&1
  printf "Image: $DOCKER_IMAGE_TAG \n" >&1

  DEPLOYED_SERVICE=`$AWS_ECS update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition $NEW_TASK_DEFINITION`
  if [[ ! "$?" = 0 || -z "$DEPLOYED_SERVICE" ]]; then
    printf "ERROR: Failed to upload service\n" >&2
    exit 1
  fi
}

################ SCRIPT LOGIC ################################
printSectionLine
printf "Checking parameters...\n" >&1
check_params
printf "SUCCESS\n" >&1

printSectionLine
printf "Running pre checks...\n" >&1
preChecks
printf "SUCCESS\n" >&1

printSectionLine
printf "Getting current task definition...\n" >&1
get_current_task_definition
printf "SUCCESS\n" >&1

printSectionLine
printf "Creating new task definition...\n" >&1
create_new_task_definition
printf "SUCCESS\n" >&1

printSectionLine
printf "Deploying new task definition...\n" >&1
deploy_new_task_definition
printf "SUCCESS\n" >&1

printSectionLine
printf "Updating ECS service...\n" >&1
update_ecs_service
printf "SUCCESS\n" >&1

printSectionLine
printf "Blue/green deployment of new task definition started successfully\n" >&1

