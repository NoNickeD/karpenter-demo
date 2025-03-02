#!/bin/bash

cat <<EOF > ../karpenterConfig/values.yaml
# -- Overrides the chart's name.
nameOverride: "karpenter"

# -- Kubernetes namespace for Karpenter.
namespaceOverride: "kube-system"

# -- Number of replicas for the controller.
replicas: 3

# -- SecurityContext for the pod.
podSecurityContext:
  fsGroup: 65532

# -- PriorityClass name for the pod.
priorityClassName: system-cluster-critical

# -- Node selector to schedule the pod to nodes with labels.
nodeSelector:
  kubernetes.io/os: linux

# -- Affinity rules for scheduling the pod.
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: karpenter.sh/nodepool
              operator: DoesNotExist
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: "kubernetes.io/hostname"

# -- IAM Role for Karpenter controller
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: "$(tofu output -raw karpenter_service_account_annotation | cut -d ' ' -f2)" # Before deploying Karpenter, make sure to run ../infrastructure/generate_values.sh to generate your own values.yaml configuration.

# -- Controller configuration
controller:
  image:
    repository: public.ecr.aws/karpenter/controller
    tag: 1.2.1

  resources:
    requests:
      cpu: 1
      memory: 1Gi
    limits:
      cpu: 1
      memory: 1Gi

# -- Global settings for Karpenter
settings:
  clusterName: "$(tofu output -raw karpenter_cluster_name)"
  interruptionQueue: "$(tofu output -raw karpenter_interruption_queue)"
  featureGates:
    spotToSpotConsolidation: false
    nodeRepair: false
EOF
