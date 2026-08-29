#!/bin/bash
set -euo pipefail

MASTER_IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
KUBE_USER="ec2-user"
KUBE_HOME="/home/${KUBE_USER}"

echo "Master private IP: ${MASTER_IP}"

if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "Initializing Kubernetes control plane..."

    kubeadm init \
        --pod-network-cidr=10.244.0.0/16 \
        --ignore-preflight-errors=NumCPU
else
    echo "Kubernetes control plane is already initialized. Skipping kubeadm init."
fi

echo "Configuring kubeconfig..."

mkdir -p "${KUBE_HOME}/.kube"
cp /etc/kubernetes/admin.conf "${KUBE_HOME}/.kube/config"
chown -R "${KUBE_USER}:${KUBE_USER}" "${KUBE_HOME}/.kube"

export KUBECONFIG="${KUBE_HOME}/.kube/config"

echo "Waiting for Kubernetes API server..."

until sudo -u "${KUBE_USER}" kubectl get nodes >/dev/null 2>&1; do
    sleep 5
done

echo "Kubernetes API is ready."

if ! kubectl get daemonset kube-flannel-ds -n kube-flannel >/dev/null 2>&1; then
    echo "Installing Flannel CNI..."

    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
else
    echo "Flannel CNI is already installed. Skipping."
fi

if [ ! -x /usr/local/bin/helm ]; then
    echo "Installing Helm..."

    HELM_VERSION="v3.21.4"

    curl -fsSL \
        "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
        -o /tmp/helm.tar.gz

    tar -xzf /tmp/helm.tar.gz -C /tmp

    install -m 755 /tmp/linux-amd64/helm /usr/local/bin/helm

    rm -rf /tmp/helm.tar.gz /tmp/linux-amd64
else
    echo "Helm is already installed."
fi

if [ ! -x /usr/local/bin/helm ]; then
    echo "ERROR: Helm installation failed."
    exit 1
fi

echo "Helm version:"
/usr/local/bin/helm version

echo "Configuring NFS server..."

mkdir -p /srv/nfs/kubedata

chown -R nobody:nobody /srv/nfs/kubedata
chmod 777 /srv/nfs/kubedata

echo "/srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports

exportfs -rav

systemctl enable --now nfs-server

echo "NFS server status:"
systemctl is-active nfs-server

echo "Generating Kubernetes worker join command..."

kubeadm token create --print-join-command > "${KUBE_HOME}/join-worker.sh"

chmod +x "${KUBE_HOME}/join-worker.sh"
chown "${KUBE_USER}:${KUBE_USER}" "${KUBE_HOME}/join-worker.sh"

echo "Worker join command saved to:"
echo "${KUBE_HOME}/join-worker.sh"

echo "Kubernetes nodes:"
sudo -u "${KUBE_USER}" kubectl get nodes -o wide

echo "Master setup completed successfully."