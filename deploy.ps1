cd terraform/environments/azure
terraform apply -target=module.azure_networking -target=module.aks -target=azurerm_public_ip.vpn_ip -auto-approve
cd ../aws
terraform apply -auto-approve
cd ../azure
terraform apply -auto-approve
cd ../../../
