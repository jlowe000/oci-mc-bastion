#!/bin/bash

# Include Environment Variables
. ./mc-env.sh

RESOURCE_PORT="22"
SESSION_NAME="mysession"

# Get the options
while getopts ":hb:c:s:r:p:i:" option; do
  case $option in
    h) # display Help
       echo "-b <bastion_name> -c <compartment_name> -s <subnet_name> -r <resource_name> -p <port> -i <session_name>"
       exit;;
    b) # Set Bastion (by arg)
       BASTION_NAME=$OPTARG;;
    c) # Set Compartment (by arg)
       COMPARTMENT_NAME=$OPTARG;;
    s) # Set Subnet (by arg)
       SUBNET_NAME=$OPTARG;;
    r) # Set Resource (by arg)
       RESOURCE_NAME=$OPTARG;;
    p) # Set Resource Port (by arg)
       RESOURCE_PORT=$OPTARG;;
    i) # Set Session Name ie (ID) (by arg)
       SESSION_NAME=$OPTARG;;
  esac
done

# Create SSH Keys if required
if [ -r ${SSH_KEY_PRIV} ] && [ -r ${SSH_KEY_PUB} ] 
then
  echo "Found SSH Keys"
else
  echo "Requires new SSH Keys"
  ssh-keygen -f $SSH_KEY_PRIV -q -N ""
fi

# Get OCIDs for key components
COMPARTMENT_OCID=`oci --profile ${PROFILE_NAME} iam compartment list --all --name "${COMPARTMENT_NAME}" | jq -r ".data[0].id"` 
echo ${COMPARTMENT_OCID}
SUBNET_OCID=`oci --profile ${PROFILE_NAME} network subnet list --all --display-name "${SUBNET_NAME}" --compartment-id ${COMPARTMENT_OCID} | jq -r ".data[0].id"` 
echo ${SUBNET_OCID}
RESOURCE_OCID=`oci --profile ${PROFILE_NAME} compute instance list --all --display-name "${RESOURCE_NAME}" --compartment-id ${COMPARTMENT_OCID} | jq -r ".data[0].id"` 
echo ${RESOURCE_OCID}

# Create Bastion Instance if required
LIST_BASTION=`oci --profile ${PROFILE_NAME} bastion bastion list --all --compartment-id ${COMPARTMENT_OCID} --name ${BASTION_NAME} --bastion-lifecycle-state ACTIVE`
if [ "" = "${LIST_BASTION}" ]; then
  echo "EMPTY"
  echo 'oci --profile ${PROFILE_NAME} bastion bastion create --bastion-type standard --compartment-id ${COMPARTMENT_OCID} --target-subnet-id ${SUBNET_OCID} --name ${BASTION_NAME} --client-cidr-list file://./cidr-list.json'
  BASTION_WR=`oci --profile ${PROFILE_NAME} bastion bastion create --bastion-type standard --compartment-id ${COMPARTMENT_OCID} --target-subnet-id ${SUBNET_OCID} --name ${BASTION_NAME} --client-cidr-list file://./cidr-list.json`
  echo ${BASTION_WR}
  until [ "" != "${LIST_BASTION}" ]
  do
    LIST_BASTION=`oci --profile ${PROFILE_NAME} bastion bastion list --all --compartment-id ${COMPARTMENT_OCID} --name ${BASTION_NAME} --bastion-lifecycle-state ACTIVE`
    if [ "" = "${LIST_BASTION}" ]
    then
      echo "CREATING"
      sleep 5s
    else
      echo ${LIST_BASTION}
    fi
  done
fi

BASTION_OCID=`echo ${LIST_BASTION} | jq -r '.data[0].id'`
echo ${BASTION_OCID}

# Create Bastion Session if required
LIST_SESSION=`oci --profile ${PROFILE_NAME} bastion session list --all --bastion-id ${BASTION_OCID} --session-lifecycle-state ACTIVE`
if [ "" = "${LIST_SESSION}" ]; then
  SESSION_WR=`oci --profile ${PROFILE_NAME} bastion session create-managed-ssh --bastion-id ${BASTION_OCID} --ssh-public-key-file ${SSH_KEY_PUB} --target-os-username opc --target-port 22 --target-resource-id ${RESOURCE_OCID}`
  until [ "" != "${LIST_SESSION}" ]
  do
    LIST_SESSION=`oci --profile ${PROFILE_NAME} bastion session list --all --bastion-id ${BASTION_OCID} --session-lifecycle-state ACTIVE`
    if [ "" = "${LIST_SESSION}" ]
    then
      echo "CREATING"
      sleep 5s
    else
      echo ${LIST_SESSION}
    fi
  done
fi

SESSION_OCID=`echo ${LIST_SESSION} | jq -r '.data[0].id'`
echo ${SESSION_OCID}

GET_SESSION=`oci --profile ${PROFILE_NAME} bastion session get --session-id ${SESSION_OCID}`
echo ${GET_SESSION}
PRIVATE_IP_ADDRESS=`echo ${GET_SESSION} | jq -r ".data.\"target-resource-details\".\"target-resource-private-ip-address\""`
echo ${PRIVATE_IP_ADDRESS}

# Create SSH Tunnel for Minecraft
SSH_CMD=`echo ${GET_SESSION} | jq -r ".data.\"ssh-metadata\".command" | sed -E 's/<privateKey>/${SSH_KEY_PRIV}/g'`

if [ "22" != "${RESOURCE_PORT}" ]; then
  SSH_CMD=`echo ${SSH_CMD} | sed -E 's/-p 22/-L ${RESOURCE_PORT}:${PRIVATE_IP_ADDRESS}:${RESOURCE_PORT} -N/g'`
fi

echo ${SSH_CMD}
eval ${SSH_CMD}
