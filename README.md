# Karpenter Demo

This repository provides a complete setup for deploying and testing [Karpenter](https://karpenter.sh/) on AWS EKS using OpenTofu.

## Prerequisites

Ensure you have the following installed:

- [AWS CLI](https://aws.amazon.com/cli/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [OpenTofu](https://opentofu.org/)
- [Helm](https://helm.sh/)
- [jq](https://stedolan.github.io/jq/)
- [Task](https://taskfile.dev/)

## Installation Steps

### Clone the Repository

```sh
git clone https://github.com/NoNickeD/karpenter-demo.git
cd karpenter-demo
```

### Pull the Latest Changes (if needed)

```sh
git pull
```

### Navigate to the Infrastructure Directory

```sh
cd infrastructure
```

### Initialize OpenTofu

```sh
tofu init
```

### Plan Deployment

```sh
tofu plan -var-file=./conf/deploy.tfvars
```

### Apply Deployment

```sh
tofu apply -var-file=./conf/deploy.tfvars
```

### Update Kubernetes Configuration

```sh
aws eks update-kubeconfig --name karpenter-demo --alias karpenter-demo --region eu-central-1 --profile sandbox
```

### Set Kubernetes Context

```sh
kubectl config use-context karpenter-demo
```

### Generate `values.yaml` Dynamically

```sh
./generate_values.sh
```

### Verify Cluster Nodes and Pods

```sh
kubectl get nodes
kubectl get pods -A
```

### Navigate to `karpenterConfig`

```sh
cd ../karpenterConfig
```

### Confirm `values.yaml` File Generation

```sh
cat values.yaml
```

### Install Karpenter

```sh
helm registry logout public.ecr.aws

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --namespace kube-system \
  --create-namespace \
  --values values.yaml \
  --wait
```

### Verify Karpenter Installation

```sh
kubectl --namespace kube-system get pods -l "app.kubernetes.io/instance=karpenter"
```

### Check Karpenter Logs

```sh
kubectl --namespace kube-system logs -f -l "app.kubernetes.io/instance=karpenter"
```

### Install Karpenter Concepts

```sh
task install-karpenter-concepts
```

### Verify Karpenter EC2 Node Classes

```sh
kubectl get ec2nodeclasses.karpenter.k8s.aws
```

### Verify Karpenter Node Pools

```sh
kubectl get nodepools.karpenter.sh
```

### Deploy Example Application (This app cannot run on existing nodes)

```sh
kubectl apply -f example-app.yaml
```

### Debugging: Inspect Karpenter Logs for Scheduling Issues

Karpenter logs should provide insights if the pod cannot be scheduled due to node constraints.

```json
{
  "level": "ERROR",
  "time": "2025-03-01T15:28:13.169Z",
  "logger": "controller",
  "message": "could not schedule pod",
  "commit": "477072f",
  "controller": "provisioner",
  "namespace": "",
  "name": "",
  "reconcileID": "1f121039-b9e6-4ae2-8fba-99491d3cc7cd",
  "Pod": {
    "name": "example-app-78f879fdb6-chqvg",
    "namespace": "default"
  },
  "error": "incompatible with nodepool \"system\", daemonset overhead={\"cpu\":\"180m\",\"memory\":\"120Mi\",\"pods\":\"3\"}, did not tolerate node-type=system:NoSchedule; incompatible with nodepool \"apps\", daemonset overhead={\"cpu\":\"180m\",\"memory\":\"120Mi\",\"pods\":\"3\"}, incompatible requirements, key node.kubernetes.io/instance-type, node.kubernetes.io/instance-type In [c5.4xlarge m5.4xlarge r5.2xlarge] not in node.kubernetes.io/instance-type In [t3.large]",
  "errorCauses": [
    {
      "error": "incompatible with nodepool \"system\", daemonset overhead={\"cpu\":\"180m\",\"memory\":\"120Mi\",\"pods\":\"3\"}, did not tolerate node-type=system:NoSchedule"
    },
    {
      "error": "incompatible with nodepool \"apps\", daemonset overhead={\"cpu\":\"180m\",\"memory\":\"120Mi\",\"pods\":\"3\"}, incompatible requirements, key node.kubernetes.io/instance-type, node.kubernetes.io/instance-type In [c5.4xlarge m5.4xlarge r5.2xlarge] not in node.kubernetes.io/instance-type In [t3.large]"
    }
  ]
}
```

### Apply a New NodePool for Applications

```sh
kubectl apply -f ./nodePool/nodePool-app-final.yaml
```

### Update AWS Auth ConfigMap to Include Karpenter Role

```sh
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text --region eu-central-1 --profile sandbox)

kubectl get configmap -n kube-system aws-auth -o yaml | \
yq e '.data.mapRoles += "\n- rolearn: arn:aws:iam::'"$AWS_ACCOUNT_ID"':role/KarpenterNodeRole-karpenter-demo\n  username: system:node:{{EC2PrivateDNSName}}\n  groups:\n    - system:bootstrappers\n    - system:nodes"' - | \
kubectl apply -f -
```

### Verify NodeClaims

```sh
kubectl get nodeclaims
```

### Confirm Karpenter Creates a New Node

```sh
kubectl get nodes --no-headers
```

### Verify Running Pods

```sh
kubectl get pods
```

### Cleanup: Remove Example Application Deployment

```sh
kubectl delete deploy example-app
```

### Verify Node Auto-Scaling

After removing the deployment, Karpenter should automatically remove unused nodes within two minutes.

```sh
kubectl get nodes
```

### Destroy Infrastructure

Navigate back to the infrastructure directory and destroy resources.

```sh
cd ../infrastructure

tofu destroy -var-file=./conf/deploy.tfvars
```

## Notes

- Karpenter automatically provisions and deprovisions EC2 nodes based on workload requirements.
- The example application demonstrates how Karpenter reacts when a pod cannot be scheduled due to insufficient node resources.
- Ensure that IAM roles, permissions, and node pools are configured correctly to allow smooth provisioning of nodes.

For more details, check the [Karpenter Documentation](https://karpenter.sh/).

```sh
.
├── README.md
├── infrastructure
│   ├── cluster.tf
│   ├── conf
│   │   └── deploy.tfvars
│   ├── data.tf
│   ├── generate_values.sh
│   ├── iam.tf
│   ├── locals.tf
│   ├── network.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── scaler.tf
│   └── variables.tf
└── karpenterConfig
    ├── Taskfile.yaml
    ├── ec2nodeclass
    │   ├── ec2nodeclass-apps.yaml
    │   └── ec2nodeclass-system.yaml
    ├── example-app.yaml
    ├── nodePool
    │   ├── nodePool-app-final.yaml
    │   ├── nodePool-app.yaml
    │   └── nodePool-system.yaml
    └── values.yaml
```
