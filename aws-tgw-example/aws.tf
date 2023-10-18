########################################################################################################
# Create example resources using code yanked from tgw-example-module on Terraform Registry
########################################################################################################
module "name" {

}

########################################################################################################
# TODO in future iteration:
# Refactor this repo with a simpler / more digestible example which creates all the necessary bits,
# rather than relying on tgw-example-module (which is somewhat inflexible)
#
# - Create two VPCs
# - Create a TGW
# - Create a Resource Share
# - Create TGW Attachments for each VPC
# - Create EC2 instances in both VPCs to demonstrate routing works between them
# - Create Confluent Cloud network & attach to TGW
########################################################################################################

########################################################################################################
# Create a Transit Gateway & attach the VPCs to it, along with any necessary routes.
# After this, hosts in each VPC should be able to connect to hosts in the other.
########################################################################################################


########################################################################################################
# Create an RDS instance in one of the VPCs
########################################################################################################
