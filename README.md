## Description
This project provides instructions and Terraform scripts to create an AWS EKS cluster with EFS CSI,
allowing the cluster's components to mount EFS filesystems.

## Deployment
To deploy the cluster, clone the repository and navigate to the created directory. Then, create a `terraform.tfvars` file and customize the variables as needed. Below is an example of the variables used to create a cluster:

```hcl
cluster_name       = "tarterware-eks"
region             = "us-east-1"
disk_size          = 50
node_instance_type = ["t3.medium"]
```

Run the following commands to deploy the cluster:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

After deployment, configure `kubectl` to access the cluster:

```bash
aws eks update-kubeconfig --name tarterware-eks --region us-east-1
```

## Installing Kubernetes Dashboard
To manage the cluster more easily, install the Kubernetes Dashboard with the following commands:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
kubectl create serviceaccount admin-user -n kubernetes-dashboard
kubectl create clusterrolebinding admin-user-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:admin-user
```

## Creating a Companion Minikube Environment
If you'd like to test changes locally before deploying to EKS, you can set up a Minikube cluster. Follow these steps:

### Setting Up Shared Storage
Tarterware applications use a shared directory for files accessed across pods. Create this directory on your local machine:

```bash
sudo mkdir /opt/tarterware-data
sudo chmod 0777 /opt/tarterware-data
```

### Installing Minikube
Install Minikube using the instructions at [Minikube Installation](https://minikube.sigs.k8s.io/docs/start/). These steps are tailored for Ubuntu Linux, but adjustments may be necessary for other operating systems.

### Additional Tools
- **Kubectl**: Download from [Kubernetes CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/). Place the binary in a directory included in your PATH.
- **Helm**: Download from [Helm Releases](https://github.com/helm/helm/releases) and ensure it is in your PATH.

### Linux-Specific Setup
If running Minikube on Linux, ensure KVM2 virtualization is installed. Follow the steps at [KVM2 Driver Setup](https://minikube.sigs.k8s.io/docs/drivers/kvm2/) and download the driver from [Minikube Releases](https://github.com/kubernetes/minikube/releases).

### Configuring Minikube
Configure Minikube to allocate adequate resources for the cluster:

```bash
minikube config set vm-driver kvm2        # For Linux
minikube config set cpus 4
minikube config set memory 12000
minikube config set disk-size 200GB
```

Start Minikube with additional options:

```bash
minikube start \
  --extra-config=apiserver.service-node-port-range=1-65535 \
  --mount-string='/opt/tarterware-data/:/tarterware-data' \
  --mount=true
```

### Enabling Add-ons
Enable useful add-ons:

```bash
minikube addons enable ingress
minikube addons enable metrics-server
```

### Accessing the Dashboard
Start the Minikube dashboard to monitor the cluster:

```bash
minikube dashboard
```

### Managing Minikube
Stop Minikube before shutting down or logging off:

```bash
minikube stop
```

Restart with the same arguments to ensure proper configuration:

```bash
minikube start \
  --extra-config=apiserver.service-node-port-range=1-65535 \
  --mount-string='/opt/tarterware-data/:/tarterware-data' \
  --mount=true
```

