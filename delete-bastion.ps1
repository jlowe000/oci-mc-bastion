# Include Environment Variables
& .\mc-env.ps1

# Determine OCIDs
$COMPARTMENT_OCID=oci --profile $Env:PROFILE_NAME iam compartment list --all --name "$Env:COMPARTMENT_NAME" | jq-win64 -r ".data[0].id"
echo $COMPARTMENT_OCID

# Delete Bastion Instance if required
$LIST_BASTION=oci --profile $Env:PROFILE_NAME bastion bastion list --all --compartment-id $COMPARTMENT_OCID --name $Env:BASTION_NAME --bastion-lifecycle-state ACTIVE
echo $LIST_BASTION
if ($null -ne $LIST_BASTION) {
  $BASTION_OCID=echo $LIST_BASTION | jq-win64 -r '.data[0].id'
  echo $BASTION_OCID
  $DELETE_BASTION=oci --profile $Env:PROFILE_NAME bastion bastion delete --bastion-id $BASTION_OCID --force
  echo $DELETE_BASTION
  do {
    $GET_BASTION=oci --profile $Env:PROFILE_NAME bastion bastion get --bastion-id $BASTION_OCID | jq-win64 -r '.data.\"lifecycle-state\"'
    if ("DELETED" -ne $GET_BASTION) {
      echo "DELETING"
      sleep -Seconds 5
    } else {
      echo $GET_BASTION
    }
  } until ("DELETED" -eq $GET_BASTION)
}
