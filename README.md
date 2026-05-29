# EKS with EFS and ALB

A fully automated Terraform project that provisions a production-ready AWS EKS (Elastic Kubernetes Service) cluster, complete with:

- **VPC** with public and private subnets across three availability zones
- **EFS (Elastic File System)** for persistent, shared storage across pods via the CSI driver
- **ALB (Application Load Balancer)** managed by the AWS Load Balancer Controller
- **Cluster Autoscaler** for dynamic node scaling based on pod demand
- **EBS CSI Driver** for block storage support
- **IAM roles and policies** using IRSA (IAM Roles for Service Accounts) for least-privilege access

This project is primarily aimed at engineers who need a solid, repeatable baseline for running stateful, internet-facing workloads on EKS without piecing together multiple guides.

---

## Architecture Overview

```
Internet
    │
    ▼
[ALB - public subnets]
    │
    ▼
[EKS Worker Nodes - private subnets]
    ├── EFS CSI Driver  → mounts AWS EFS filesystem
    ├── AWS LB Controller → manages ALB lifecycle
    └── Cluster Autoscaler → scales node groups via ASG tags
    │
    ▼
[Amazon EFS]  (NFS over port 2049, private subnet mount targets)
```

The VPC uses a `10.0.0.0/16` CIDR with three private subnets (`10.0.1-3.0/24`) for worker nodes and three public subnets (`10.0.4-6.0/24`) for load balancers, spread across the first three availability zones of the chosen region. A single NAT gateway provides outbound internet access from the private subnets.

---

## Repository Structure

| File | Purpose |
|---|---|
| `provider.tf` | AWS, Helm, and kubectl provider configuration and version constraints |
| `main.tf` | Filters availability zones to exclude Local Zones |
| `variables.tf` | Input variable declarations |
| `vpc.tf` | VPC, subnets, NAT gateway, and subnet tagging for Kubernetes |
| `eks.tf` | EKS cluster, managed node group, EBS CSI add-on, IAM policy for EFS worker node access, security group rules, Kubernetes and kubectl provider config |
| `iam.tf` | IAM roles, policies, and groups for EKS admin access, EBS CSI driver, and a sample `user1` IAM user |
| `efs.tf` | EFS security group, Kubernetes service account, and IRSA role for EFS access |
| `helm_provider.tf` | Helm provider bootstrap (depends on EKS cluster) |
| `helm-efs-csi-driver.tf` | Helm deployment of the AWS EFS CSI driver |
| `helm-load-balancer-controller.tf` | IAM policy, IRSA role, and Helm deployment of the AWS Load Balancer Controller |
| `autoscaler_iam.tf` | IRSA role for the Cluster Autoscaler |
| `autoscaler_manifest.tf` | Kubernetes manifests for the Cluster Autoscaler (ServiceAccount, RBAC, Deployment) |
| `install_efs_utils.tf` | DaemonSet that installs `amazon-efs-utils` on every worker node |
| `outputs.tf` | Outputs the OIDC provider ARN and issuer URL for downstream use |
| `nginx.yaml` | Example NGINX deployment (2 replicas, 1 CPU request) for autoscaler testing |
| `echoserver.yaml` | Example echoserver deployment for ALB Ingress smoke testing |

---

## Prerequisites

Before deploying, ensure you have the following tools installed and configured:

- [Terraform](https://developer.hashicorp.com/terraform/install) `~> 1.0`
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured with credentials that have sufficient IAM permissions to create EKS, VPC, IAM, and EFS resources
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/) `v3+`

Your AWS credentials must allow creating resources in the target region. At minimum, the deploying identity needs permissions to create and manage: VPCs, EKS clusters, EC2 autoscaling groups, IAM roles/policies, EFS file systems, and ELBs.

---

## Configuration

Create a `terraform.tfvars` file in the root of the repository and set the following variables:

```hcl
cluster_name       = "my-eks-cluster"
region             = "us-east-1"
disk_size          = 50
node_instance_type = ["t3.medium"]
```

### Variables Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `cluster_name` | `string` | *(required)* | Name for the EKS cluster and associated resources |
| `region` | `string` | `"us-east-1"` | AWS region to deploy into |
| `disk_size` | `number` | `50` | Root EBS disk size (GB) for worker nodes |
| `node_instance_type` | `list(string)` | `["t3.large"]` | EC2 instance type(s) for the managed node group |
| `environment_label` | `string` | `"prod"` | Tag applied to all resources for environment identification |

> **Cost note:** The cluster deploys a minimum of 2 worker nodes, one NAT gateway, and an EFS file system. Running this continuously in `us-east-1` with `t3.medium` nodes costs roughly $5–10/day. Destroy the cluster when not in use.

---

## Deployment

### 1. Clone and initialize

```bash
git clone https://github.com/SteveTarter/eks-with-efs-and-alb.git
cd eks-with-efs-and-alb
```

Create `terraform.tfvars` as described above, then:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

Terraform will provision the full stack in a single apply. Expect the deployment to take 15–20 minutes due to EKS cluster creation time.

### 2. Configure kubectl

Once `apply` completes, update your local kubeconfig:

```bash
aws eks update-kubeconfig --name <cluster_name> --region <region>
```

For example:

```bash
aws eks update-kubeconfig --name tarterware-eks --region us-east-1
```

Verify connectivity:

```bash
kubectl get nodes
kubectl get pods -A
```

### 3. Verify EFS

Check that the EFS CSI driver DaemonSet is running and that `amazon-efs-utils` is installed on the nodes:

```bash
kubectl get pods -n kube-system | grep efs
```

### 4. Verify the Load Balancer Controller

```bash
kubectl get pods -n kube-system | grep aws-load-balancer-controller
```

### 5. Verify the Cluster Autoscaler

```bash
kubectl get pods -n kube-system | grep cluster-autoscaler
kubectl logs -n kube-system deployment/cluster-autoscaler
```

---

## Testing the Cluster

### Autoscaler test (nginx.yaml)

`nginx.yaml` deploys two NGINX pods, each requesting 1 full CPU core. This is useful for observing the Cluster Autoscaler add nodes when capacity is exhausted.

```bash
kubectl apply -f nginx.yaml
kubectl get pods -w
```

Scale the deployment up to trigger node addition:

```bash
kubectl scale deployment nginx-deployment --replicas=10
```

Watch the autoscaler logs and node count:

```bash
kubectl logs -n kube-system deployment/cluster-autoscaler -f
kubectl get nodes -w
```

### ALB Ingress test (echoserver.yaml)

`echoserver.yaml` deploys a simple HTTP echo server. After applying it, annotate the Service with the ALB ingress class to have the Load Balancer Controller provision an Application Load Balancer:

```bash
kubectl apply -f echoserver.yaml
kubectl get ingress
```

The `ADDRESS` column will show the ALB DNS name once the controller has finished provisioning it (typically 2–3 minutes).

---

## IAM and Security Model

### IRSA (IAM Roles for Service Accounts)

All AWS API access from within Kubernetes uses IRSA, which binds an IAM role to a specific Kubernetes ServiceAccount via the cluster's OIDC provider. This avoids the need to attach broad instance-profile policies to all worker nodes.

The following IRSA roles are created:

| Role | Service Account | Permissions |
|---|---|---|
| `<cluster_name>-ebs-csi-driver` | `kube-system:ebs-csi-controller-sa` | `AmazonEBSCSIDriverPolicy` |
| `aws-load-balancer-controller` | `kube-system:aws-load-balancer-controller` | EC2/ELB management |
| `efs-access-role` | `default:efs-app-service-account` | EFS mount/write |
| Cluster Autoscaler role | `kube-system:cluster-autoscaler` | EC2 Auto Scaling group management |

### EKS Admin Access

An IAM role named `eks-admin` is created and granted `system:masters` in the cluster's `aws-auth` ConfigMap. An IAM group named `eks-admin` is also created; members of that group can assume the `eks-admin` role via `sts:AssumeRole`. A placeholder user `user1` is added to this group — replace or remove this as appropriate for your organisation.

### Security Groups

Two security group rules are notable:

- **Ingress:** All traffic (`-1`) is permitted between nodes and between nodes and the cluster control plane. This is broad; tighten to specific ports (e.g., 443, 10250) for production.
- **Egress from nodes:** Restricted to `10.0.0.0/16` (the VPC CIDR). If your workloads need to reach the public internet directly (rather than through the NAT gateway), you will need to relax this rule.
- **EFS security group:** Allows NFS traffic on port 2049 from `0.0.0.0/0`. Consider tightening this to the VPC CIDR or the node security group ID in production.

---

## Installing the Kubernetes Dashboard

To manage the cluster visually, install the Kubernetes Dashboard:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

kubectl create serviceaccount admin-user -n kubernetes-dashboard

kubectl create clusterrolebinding admin-user-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:admin-user
```

Generate a login token:

```bash
kubectl -n kubernetes-dashboard create token admin-user
```

Start the proxy and open the dashboard at `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`:

```bash
kubectl proxy
```

---

## Teardown

To destroy all provisioned resources and avoid ongoing costs:

```bash
terraform destroy
```

> **Important:** If you have applied any Kubernetes resources that created AWS load balancers or EFS access points outside of Terraform (e.g., via `kubectl apply`), delete those first. Terraform cannot destroy VPC or EFS resources that still have dependent AWS objects attached.

---

## Creating a Companion Minikube Environment

If you want to test application changes locally before deploying to EKS, you can set up a Minikube cluster that mirrors the shared-storage pattern used in production.

### Setting Up Shared Storage

Tarterware applications use a shared directory accessible across pods. Create it on your local machine:

```bash
sudo mkdir /opt/tarterware-data
sudo chmod 0777 /opt/tarterware-data
```

### Installing Minikube

Install Minikube using the official instructions at [https://minikube.sigs.k8s.io/docs/start/](https://minikube.sigs.k8s.io/docs/start/). The steps below are tailored for Ubuntu Linux.

**Additional tools required:**

- `kubectl` — [https://kubernetes.io/docs/tasks/tools/install-kubectl/](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- `helm` — [https://github.com/helm/helm/releases](https://github.com/helm/helm/releases)

Place both binaries in a directory on your `PATH`.

### Linux-Specific: KVM2 Driver

On Linux, Minikube runs best with the KVM2 hypervisor driver. Follow the setup guide at [https://minikube.sigs.k8s.io/docs/drivers/kvm2/](https://minikube.sigs.k8s.io/docs/drivers/kvm2/) and download the driver binary from [https://github.com/kubernetes/minikube/releases](https://github.com/kubernetes/minikube/releases).

### Configuring and Starting Minikube

Configure adequate resources before the first start:

```bash
minikube config set vm-driver kvm2   # Linux only; omit on macOS/Windows
minikube config set cpus 4
minikube config set memory 12000
minikube config set disk-size 200GB
```

Start Minikube and mount the shared directory into the cluster:

```bash
minikube start \
  --extra-config=apiserver.service-node-port-range=1-65535 \
  --mount-string='/opt/tarterware-data/:/tarterware-data' \
  --mount=true
```

Enable useful add-ons:

```bash
minikube addons enable ingress
minikube addons enable metrics-server
```

Open the dashboard:

```bash
minikube dashboard
```

### Stopping and Restarting Minikube

Always stop Minikube cleanly before logging off or shutting down:

```bash
minikube stop
```

Restart with the same mount arguments to ensure the shared directory is re-mounted:

```bash
minikube start \
  --extra-config=apiserver.service-node-port-range=1-65535 \
  --mount-string='/opt/tarterware-data/:/tarterware-data' \
  --mount=true
```

---

## Outputs

After a successful `terraform apply`, two values are emitted:

| Output | Description |
|---|---|
| `oidc_provider_arn` | ARN of the EKS OIDC provider — use this when creating additional IRSA roles for new workloads |
| `cluster_oidc_issuer_url` | Issuer URL of the OIDC provider |

---

## Known Limitations and Considerations

- **Single NAT gateway:** A single NAT gateway is used to reduce cost. In production, deploy one NAT gateway per availability zone for high availability.
- **Public cluster endpoint:** The EKS API server endpoint is publicly accessible (`cluster_endpoint_public_access = true`). Restrict this to known CIDR ranges by setting `cluster_endpoint_public_access_cidrs` in `eks.tf` for production use.
- **EFS security group:** The EFS security group currently allows NFS (port 2049) from any source. Lock this down to the VPC CIDR or the node security group for production.
- **Helm chart versions:** The Load Balancer Controller Helm chart is pinned to `1.4.4`. Check [https://github.com/aws/eks-charts](https://github.com/aws/eks-charts) for newer releases and test upgrades before applying to production.
- **Cluster Autoscaler image version:** The autoscaler is pinned to `v1.26.2`. The image version must match your EKS cluster version. Update `autoscaler_manifest.tf` if you change `cluster_version` in `eks.tf`.
- **`user1` IAM user:** A placeholder IAM user named `user1` is created in `iam.tf`. Remove or replace this with real users or federated identities before deploying to a shared AWS account.
