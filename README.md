# oci-mc-bastion

Purpose: To simplify the connection to the Minecraft Server using a Bastion Instance to securely create an SSH tunnel to the server.

Background: I built and deploy Minecraft on Oracle Cloud Infrastructure using arm64 with VM.Standard.A1-Flex Shape. See the article [here](https://redthunder.blog/2021/06/21/minecraft-on-oci-arm-plus/ "RedThunder Blog"). To avoid using publicly accessible ports, the OCI Bastion service provides a method to create a connection that is a) temporal and b) managed through OCI creating a connection to the server.

Requires:
- OCI CLI SDK (See the reference [here](https://docs.oracle.com/en-us/iaas/Content/API/Concepts/cliconcepts.htm)
- OCI API key and configuration (Required for the OCI CLI SDK. Also you can use this tool to help generate the configuration available on github [here](https://github.com/jlowe000/oci-config-gen))

Environment Variable Configuration (in mc-env.sh):
- PROFILE_NAME - Name of the OCI SDK Profile
- COMPARTMENT_NAME - Name of the Compartment where the resources are.
- SUBNET_NAME - Name of the subnet where the compute instance exists and also the subnet where the bastion session to be created
- RESOURCE_NAME - Name of the compute instance to create the bastion session
- BASTION_NAME - Name of the Bastion Instance to be created
- SSH_KEY_PRIV - Path to the private ssh key
- SSH_KEY_PUB - Path to the public ssh key

Notes:
- Use double-quotes if spaces are included in the name
- Include full path to the SSH keys
- Assume the same compartment is used for the subnet, compute instance and bastion instance to be created.

What these do:
- create-bastion.sh - Creates and sets up a local connection @ location:25565 to tunnel to the Minecraft. It creates the SSH keys, Bastion Instance and Bastion Session if required.
- delete-bastion.sh - Deletes the Bastion Instance (also any active Bastion Sessions).
