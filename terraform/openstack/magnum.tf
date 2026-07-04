# Magnum is intentionally documented through OpenStack CLI commands in
# DEPLOYMENT_NOTES.md. The OpenStack Terraform provider and local Magnum driver
# labels vary by installation, so this module avoids declaring uncertain
# container-infra resources. Terraform still provisions the network, security
# groups, Harbor VM, Harbor volume, and Harbor floating IP used by the cluster.
