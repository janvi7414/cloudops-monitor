#!/bin/bash

set -euo pipefail

WORKER_1_IP="10.0.2.10"
WORKER_2_IP="10.0.3.10"

SSH_USER="ec2-user"
SSH_KEY="/home/ec2-user/cloudops-key.pem"

echo "Checking SSH private key..."

if [ ! -f "${SSH_KEY}" ]; then
    echo "ERROR: SSH key not found at ${SSH_KEY}"
    exit 1
fi

chmod 400 "${SSH_KEY}"

echo "Testing SSH connection to Worker 1..."

ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    "${SSH_USER}@${WORKER_1_IP}" \
    "hostname"

echo "Testing SSH connection to Worker 2..."

ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    "${SSH_USER}@${WORKER_2_IP}" \
    "hostname"

echo "Generating Kubernetes worker join command..."

JOIN_COMMAND=$(sudo kubeadm token create --print-join-command)

if [ -z "${JOIN_COMMAND}" ]; then
    echo "ERROR: Failed to generate Kubernetes join command."
    exit 1
fi

echo "Join command generated successfully."

echo "Joining Worker 1: ${WORKER_1_IP}"

ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    "${SSH_USER}@${WORKER_1_IP}" \
    "sudo ${JOIN_COMMAND}"

echo "Worker 1 joined successfully."

echo "Joining Worker 2: ${WORKER_2_IP}"

ssh -i "${SSH_KEY}" \
    -o StrictHostKeyChecking=no \
    "${SSH_USER}@${WORKER_2_IP}" \
    "sudo ${JOIN_COMMAND}"

echo "Worker 2 joined successfully."

echo "Both worker nodes have been joined to the Kubernetes cluster."

echo "Current Kubernetes cluster nodes:"

kubectl get nodes -o wide