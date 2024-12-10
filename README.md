terraform-eks-with-alb
Instructions for using Terraform to set up an EKS cluster with EFS, auto-scaling, and load balancer

## Description
This project provides instructions and Terraform scripts to create an AWK EKS cluster with EFS CSI,
allowing the cluster's components to mount EFS filesystems.


## Deployment
To deploy the new cluster, clone the repo, then change to the directory created.  Create a file terraform.tfvars; change variables
as you see fit.  Here's the variables I used to create my cluster:

  cluster_name       = "tarterware-eks"
  region             = "us-east-1"
  disk_size          = 50
  node_instance_type = ["t3.medium"]

Once that has completed, execute the following commands:

  terraform init -upgrade
  terraform plan
  terraform apply

Once that is finished, execute the following to add the cluster to the set of clusters accessible via kubectl:

  aws eks update-kubeconfig --name tarterware-eks --region us-east-1

## Installing Kubernetes Dashboard
I have a hard time living by kubectl alone.  Execute the following to install Kubernetes Dashboard:

  kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
  kubectl create serviceaccount admin-user -n kubernetes-dashboard
  kubectl create clusterrolebinding admin-user-binding   --clusterrole=cluster-admin   --serviceaccount=kubernetes-dashboard:admin-user

