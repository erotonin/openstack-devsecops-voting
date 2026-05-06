cd terraform/environments/azure
terraform destroy -target=azurerm_virtual_network_gateway_connection.vpn_conn -target=azurerm_local_network_gateway.lng -auto-approve
cd ../aws
terraform destroy -auto-approve
cd ../azure
terraform destroy -auto-approve
cd ../../../
