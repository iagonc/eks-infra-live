# EKS Infra Project - README

## Overview
This project sets up an **Amazon EKS (Elastic Kubernetes Service) cluster** using **Terraform** and **Terragrunt**. The infrastructure is designed to be **scalable** and **cost-efficient**, leveraging **Karpenter** for node auto-scaling, along with a well-structured VPC and IAM policies to ensure security and high availability.

## Prerequisites

1. **Terragrunt and Terraform**:
   - Ensure that `terragrunt` and `terraform` are installed on your system.
   - Modify `/infra/account.hcl` to match the correct AWS account ID before deploying.

2. **AWS Credentials**:
   - Export valid AWS credentials in your environment:
     ```bash
     export AWS_ACCESS_KEY_ID="your-access-key-id"
     export AWS_SECRET_ACCESS_KEY="your-secret-access-key"
     ```

3. **kubectl and Helm**:
   - Install `kubectl` and `helm` to interact with the Kubernetes cluster.
   - Ensure you have AWS CLI configured to fetch EKS authentication tokens.

## Directory Structure

The project follows a modular approach with the following structure:

```
eks-infra-live/
|└── infra/
    |└── production/
        |└── env.hcl
        |└── us-east-1/
            |├── region.hcl
            |└── services/
                |├── service.hcl
                |└── eks/
                    |├── terragrunt.hcl
|└── modules/
    |├── aws/
        |└── eks/
        |└── vpc/
        |└── karpenter/
```

### Key Components
- **`infra/production/us-east-1/services/eks/terragrunt.hcl`**:
  - Main entry point to deploy the EKS infrastructure.

- **`modules/aws/eks`**:
  - Contains Terraform configuration to deploy an Amazon EKS cluster.

- **`modules/aws/vpc`**:
  - Defines the network infrastructure, including subnets, NAT gateway, and route tables.

- **`modules/aws/karpenter`**:
  - Deploys Karpenter for node auto-scaling.

## How to Deploy the Infrastructure

Navigate to the EKS service folder and apply Terragrunt:

```bash
cd infra/production/us-east-1/services/eks/
terragrunt apply
```

This command initializes and applies the Terraform configurations defined for the EKS service.

## Kubernetes Cluster Configuration

### Cluster Components
- **EKS Cluster**: Deployed with a managed control plane.
- **VPC and Subnets**: Includes private, public, and intra subnets.
- **IAM Policies and Roles**: Provides required permissions to EKS, Karpenter, and worker nodes.
- **EKS Add-ons**:
  - CoreDNS
  - Kube-Proxy
  - VPC CNI
  - EKS Pod Identity Agent

### Worker Nodes Auto-Scaling
- **Karpenter** is used instead of traditional Managed Node Groups for dynamic scaling.
- Instance types are optimized based on workload demand.
- Uses Spot and On-Demand instances to optimize cost.

### Karpenter Deployment
- Deployed using **Helm** with the following configuration:
  ```yaml
  nodeSelector:
    karpenter.sh/controller: 'true'
  dnsPolicy: Default
  settings:
    clusterName: ${module.eks.cluster_name}
    clusterEndpoint: ${module.eks.cluster_endpoint}
    interruptionQueue: ${module.karpenter.queue_name}
  webhook:
    enabled: false
  ```
- IAM roles and policies grant Karpenter permissions to scale EC2 nodes dynamically.

## Observability & Monitoring

- **Amazon CloudWatch**:
  - Logs stored under `/aws/eks/<cluster-name>/cluster`.
  - Logs are retained for 90 days.

- **Security Groups**:
  - Configured to allow secure communication between cluster components.

## Testing and Validation

1. **Verify Cluster Access**:
   ```bash
   aws eks --region us-east-1 update-kubeconfig --name <cluster-name>
   kubectl get nodes
   ```

2. **Check Karpenter Logs**:
   ```bash
   kubectl logs -n kube-system deployment/karpenter
   ```

3. **Deploy a Sample Workload**:
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: nginx
   spec:
     replicas: 2
     selector:
       matchLabels:
         app: nginx
     template:
       metadata:
         labels:
           app: nginx
       spec:
         containers:
         - name: nginx
           image: nginx
   ```
   ```bash
   kubectl apply -f deployment.yaml
   ```

## Notes
- The project uses **Terragrunt** to simplify multi-environment deployments.
- **Karpenter replaces traditional AWS Auto Scaling Groups**, making scaling more efficient.
- Ensure **IAM permissions** are correctly configured for Karpenter to manage EC2 instances.
- Change `/infra/account.hcl` to match the correct AWS account before applying.

## Cleanup
To destroy the infrastructure, run:
```bash
terragrunt destroy
```
This will remove the EKS cluster, VPC, and all associated resources.

