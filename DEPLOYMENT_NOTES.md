# Deployment Notes

## Magnum First

Create a resource-aware Kubernetes cluster through Magnum after Terraform has created the tenant network and Harbor VM.

Set shell variables from Terraform outputs:

```bash
cd terraform/openstack
TENANT_NET_ID="$(terraform output -raw tenant_network_id)"
TENANT_SUBNET_ID="$(terraform output -raw subnet_id)"
cd ../..
```

Create a cluster template. Adjust image and flavor names to match the local Glance and Nova catalog.

```bash
openstack coe cluster template create voting-k8s-template \
  --coe kubernetes \
  --image fedora-coreos-latest \
  --external-network public \
  --fixed-network "$TENANT_NET_ID" \
  --fixed-subnet "$TENANT_SUBNET_ID" \
  --dns-nameserver 1.1.1.1 \
  --master-flavor m1.k8s.master \
  --flavor m1.k8s.worker \
  --network-driver calico \
  --volume-driver cinder \
  --server-type vm \
  --docker-volume-size 20 \
  --floating-ip-enabled \
  --label container_runtime=containerd \
  --label cloud_provider_enabled=true \
  --label cinder_csi_enabled=true
```

Create the cluster:

```bash
openstack coe cluster create voting-k8s \
  --cluster-template voting-k8s-template \
  --master-count 1 \
  --node-count 1 \
  --keypair devsecops-voting \
  --timeout 90
```

Fetch kubeconfig:

```bash
openstack coe cluster config voting-k8s --dir ./kubeconfig
export KUBECONFIG="$PWD/kubeconfig/config"
kubectl get nodes -o wide
```

Install NGINX Ingress Controller, ArgoCD, and the observability charts after the cluster is healthy.

## Repository Branches

Create the staging branch from main once:

```bash
git checkout main
git pull origin main
git checkout -b staging
git push -u origin staging
```

Day-to-day changes should start on `feature/*` branches and enter the environments through pull requests.

## GitHub Runner And Secrets

Register a self-hosted runner inside the OpenStack lab network and give it these labels:

```text
self-hosted
linux
openstack
```

The runner must have Docker, kubectl, Helm, Terraform, and access to the Magnum cluster through its local kubeconfig. It must also be able to reach the Harbor endpoint.

Configure repository secrets:

```text
HARBOR_REGISTRY
HARBOR_USERNAME
HARBOR_PASSWORD
```

Install ArgoCD in the Kubernetes cluster, then apply the two application manifests:

```bash
kubectl apply -f k8s/argocd-app-staging.yaml
kubectl apply -f k8s/argocd-app-prod.yaml
```

The staging app tracks the `staging` branch and deploys to `voting-staging`. The production app tracks `main` and deploys to `voting-prod`.

## Kubespray Fallback

Use Kubespray only when Magnum cannot create a working cluster template or cluster in the local OpenStack environment.

Fallback outline:

1. Create one master VM and one worker VM on the Terraform tenant network.
2. Run Kubespray from a Linux control host.
3. Configure Calico.
4. Install OpenStack Cloud Controller Manager.
5. Install Cinder CSI and confirm a `cinder-csi` StorageClass exists.
6. Install NGINX Ingress Controller, ArgoCD, and observability charts.

Kubespray gives more direct Kubernetes control, but the OpenStack integration work becomes manual.
