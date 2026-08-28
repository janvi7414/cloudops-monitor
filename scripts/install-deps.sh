#!/bin/bash
set -euo pipefail

# Install required system packages.
sudo dnf remove -y podman* docker* || true
sudo dnf install -y dnf-plugins-core git vim wget curl nfs-utils

# Kubernetes requires swap to be disabled.
sudo swapoff -a

# Permanently disable swap after reboot.
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Disable firewalld because AWS Security Groups handle network-level access.
sudo systemctl disable --now firewalld || true

# Set SELinux to permissive mode.
sudo setenforce 0 || true
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Load kernel modules required for Kubernetes networking.
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Configure kernel networking parameters required by Kubernetes.
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply the sysctl configuration immediately.
sudo sysctl --system

# Kubernetes uses containerd as its container runtime.
# Docker Engine itself is not required.
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf install -y containerd.io

# Create containerd configuration directory.
sudo mkdir -p /etc/containerd

# Generate the default containerd configuration.
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# Use systemd as the cgroup manager.
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Start containerd and enable it after reboot.
sudo systemctl daemon-reload
sudo systemctl enable --now containerd

# Add the Kubernetes v1.30 repository.
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Install Kubernetes components.
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable kubelet at boot.
sudo systemctl enable --now kubelet

# Terraform supplies the private IPs of all Kubernetes nodes.
# This avoids hardcoding the addresses in this script.
cat <<EOF | sudo tee -a /etc/hosts

# CloudOps Kubernetes Cluster
${master_private_ip} k8s-master
${worker_1_private_ip} k8s-worker-1
${worker_2_private_ip} k8s-worker-2
EOF

echo "Kubernetes node prerequisites completed successfully."