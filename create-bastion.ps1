# Include Environment Variables
& .\mc-env.ps1

# Create SSH Keys
if ((Test-Path -Path $Env:SSH_KEY_PRIV -PathType Leaf) -and (Test-Path -Path $Env:SSH_KEY_PUB -PathType Leaf)) {
  echo "Found SSH Keys"
} else {
  echo "Requires new SSH Keys"
  ssh-keygen -f $Env:SSH_KEY_PRIV -q -N `"`"
}

# Determine OCIDs
$COMPARTMENT_OCID=oci --profile $Env:PROFILE_NAME iam compartment list --all --name "$Env:COMPARTMENT_NAME" | jq-win64 -r ".data[0].id"
echo $COMPARTMENT_OCID
$SUBNET_OCID=oci --profile $Env:PROFILE_NAME network subnet list --all --display-name "$Env:SUBNET_NAME" --compartment-id $COMPARTMENT_OCID | jq-win64 -r ".data[0].id"
echo $SUBNET_OCID
$RESOURCE_OCID=`oci --profile $Env:PROFILE_NAME compute instance list --all --display-name "$Env:RESOURCE_NAME" --compartment-id $COMPARTMENT_OCID | jq-win64 -r ".data[0].id"` 
echo $RESOURCE_OCID

# Create Bastion Instance if required
$LIST_BASTION=oci --profile $Env:PROFILE_NAME bastion bastion list --all --compartment-id $COMPARTMENT_OCID --name $Env:BASTION_NAME --bastion-lifecycle-state ACTIVE
echo $LIST_BASTION
if ($null -eq $LIST_BASTION) {
  echo "EMPTY"
  $BASTION_WR=oci --profile $Env:PROFILE_NAME bastion bastion create --bastion-type standard --compartment-id $COMPARTMENT_OCID --target-subnet-id $SUBNET_OCID --name $Env:BASTION_NAME --client-cidr-list file://./cidr-list.json
  echo $BASTION_WR
  do {
    $LIST_BASTION=oci --profile $Env:PROFILE_NAME bastion bastion list --all --compartment-id $COMPARTMENT_OCID --name $Env:BASTION_NAME --bastion-lifecycle-state ACTIVE
    if ($null -eq $LIST_BASTION) {
      echo "CREATING"
      sleep -Seconds 5
    } else {
      echo $LIST_BASTION
    }
  } until ($null -ne $LIST_BASTION)
}

$BASTION_OCID=echo $LIST_BASTION | jq-win64 -r '.data[0].id'
echo $BASTION_OCID

# Create Bastion Session if required
$LIST_SESSION=oci --profile $Env:PROFILE_NAME bastion session list --all --bastion-id $BASTION_OCID --session-lifecycle-state ACTIVE
if ($null -eq $LIST_SESSION) {
  echo "EMPTY"
  $SESSION_WR=oci --profile $Env:PROFILE_NAME bastion session create-managed-ssh --bastion-id $BASTION_OCID --ssh-public-key-file $Env:SSH_KEY_PUB --target-os-username opc --target-port 22 --target-resource-id $RESOURCE_OCID
  do {
    $LIST_SESSION=oci --profile $Env:PROFILE_NAME bastion session list --all --bastion-id $BASTION_OCID --session-lifecycle-state ACTIVE
    if ($null -eq $LIST_SESSION) {
      echo "CREATING"
      sleep -Seconds 5
    } else {
      echo $LIST_SESSION
    }
  } until ($null -ne $LIST_SESSION)
}

$SESSION_OCID=echo $LIST_SESSION | jq-win64 -r '.data[0].id'
echo $SESSION_OCID

$GET_SESSION=oci --profile $Env:PROFILE_NAME bastion session get --session-id $SESSION_OCID
echo $GET_SESSION
$PRIVATE_IP_ADDRESS=echo $GET_SESSION | jq-win64 -r '.data.\"target-resource-details\".\"target-resource-private-ip-address\"'
echo $PRIVATE_IP_ADDRESS

$SSH_CMD=echo $GET_SESSION | jq-win64 -r '.data.\"ssh-metadata\".command'
echo $SSH_CMD
$SSH_CMD=($SSH_CMD).replace("<privateKey>","$Env:SSH_KEY_PRIV").replace("-p 22","-L 25565:$PRIVATE_IP_ADDRESS`:25565 -N")
echo $SSH_CMD
Invoke-Expression $SSH_CMD