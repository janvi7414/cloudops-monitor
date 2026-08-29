#!/bin/bash

set -euo pipefail

WORKER_1_IP="10.0.2.10"
WORKER_2_IP="10.0.3.10"
SSH_USER="ec2-user"

echo "Getting Kubernetes join command from control plane..."

JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)

echo "Joining Worker 1: ${WORKER_1_IP}"

ssh -o StrictHostKeyChecking=no \
    "${SSH_USER}@${WORKER_1_IP}" \
    "sudo ${JOIN_COMMAND}"

echo "Worker 1 joined successfully."

echo "Joining Worker 2: ${WORKER_2_IP}"

ssh -o StrictHostKeyChecking=no \
    "${SSH_USER}@${WORKER_2_IP}" \
    "sudo ${JOIN_COMMAND}"

echo "Worker 2 joined successfully."

echo "Both worker nodes have been joined to the Kubernetes cluster."

echo "Current cluster nodes:"

sudo kubectl get nodes -o wide