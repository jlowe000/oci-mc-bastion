#!/bin/bash

# Include Environment Variables
. ./mc-env.sh

# Get the options
while getopts ":hb:c:" option; do
  case $option in
    h) # display Help
       echo "-b <bastion_name> -c <compartment_name>"
       exit;;
    b) # Set Bastion (by arg)
       BASTION_NAME=$OPTARG;;
    c) # Set Compartment (by arg)
       COMPARTMENT_NAME=$OPTARG;;
  esac
done

# Get OCIDs for key components
COMPARTMENT_OCID=`oci --profile ${PROFILE_NAME} iam compartment list --all --name "${COMPARTMENT_NAME}" | jq -r ".data[0].id"`
echo ${COMPARTMENT_OCID}

LIST_BASTION=`oci --profile ${PROFILE_NAME} bastion bastion list --all --compartment-id ${COMPARTMENT_OCID} --name ${BASTION_NAME} --bastion-lifecycle-state ACTIVE`
if [ "" != "${LIST_BASTION}" ]; then
  BASTION_OCID=`echo ${LIST_BASTION} | jq -r '.data[0].id'`
  echo ${BASTION_OCID}
  DELETE_BASTION=`oci --profile ${PROFILE_NAME} bastion bastion delete --bastion-id ${BASTION_OCID} --force`
  echo ${DELETE_BASTION}
  GET_BASTION=""
  until [ "DELETED" = "${GET_BASTION}" ]
  do
    GET_BASTION=`oci --profile ${PROFILE_NAME} bastion bastion get --bastion-id ${BASTION_OCID} | jq -r ".data.\"lifecycle-state\"" `
    echo ${GET_BASTION}
    if [ "DELETED" != "${GET_BASTION}" ]
    then
      sleep 5s
    fi
  done
fi
