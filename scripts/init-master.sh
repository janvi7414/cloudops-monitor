```bash
#!/bin/bash
set -euo pipefail

MASTER_IP=$(hostname -I | awk '{print $1}')
KUBE_USER="ec2-user"
KUBE_HOME="/home/${KUBE_USER}"

echo "Master private IP: ${MASTER_IP}"

# 1. Initialize Kubernetes control plane only if it is not already initialized
if [ ! -f /etc/kubernetes/admin.conf ]; then
    echo "Initializing Kubernetes control plane..."

    sudo kubeadm init \
        --pod-network-cidr=10.244.0.0/16 \
        --ignore-preflight-errors=NumCPU
else
    echo "Kubernetes control plane is already initialized. Skipping kubeadm init."
fi

# 2. Configure kubeconfig for ec2-user
echo "Configuring kubeconfig..."

sudo mkdir -p "${KUBE_HOME}/.kube"
sudo cp /etc/kubernetes/admin.conf "${KUBE_HOME}/.kube/config"
sudo chown -R "${KUBE_USER}:${KUBE_USER}" "${KUBE_HOME}/.kube"

export KUBECONFIG="${KUBE_HOME}/.kube/config"

# 3. Wait for Kubernetes API server
echo "Waiting for Kubernetes API server..."

until sudo -u "${KUBE_USER}" kubectl get nodes >/dev/null 2>&1; do
    sleep 5
done

echo "Kubernetes API is ready."

# 4. Install Flannel CNI only if it is not already installed
if ! kubectl get daemonset kube-flannel-ds -n kube-flannel >/dev/null 2>&1; then
    echo "Installing Flannel CNI..."

    kubectl apply -f \
        https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
else
    echo "Flannel CNI is already installed. Skipping."
fi

# 5. Install Helm if it is not already available
if ! command -v helm >/dev/null 2>&1; then
    echo "Installing Helm..."

    curl -fsSL \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
        | sudo bash
else
    echo "Helm is already installed."
fi

# Ensure Helm can be found in the current and future shell
export PATH="/usr/local/bin:${PATH}"

if ! command -v helm >/dev/null 2>&1; then
    echo "ERROR: Helm installation failed."
    exit 1
fi

echo "Helm version:"
helm version

# 6. Configure NFS server for persistent Kubernetes storage
echo "Configuring NFS server..."

sudo mkdir -p /srv/nfs/kubedata

sudo chown -R nobody:nobody /srv/nfs/kubedata
sudo chmod 777 /srv/nfs/kubedata

# Create NFS export configuration
echo "/srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash)" \
    | sudo tee /etc/exports >/dev/null

# Apply NFS exports
sudo exportfs -rav

# Enable and start NFS server
sudo systemctl enable --now nfs-server

echo "NFS server status:"
sudo systemctl is-active nfs-server

# 7. Generate worker join command
echo "Generating Kubernetes worker join command..."

sudo kubeadm token create --print-join-command \
    | sudo tee "${KUBE_HOME}/join-worker.sh" >/dev/null

sudo chmod +x "${KUBE_HOME}/join-worker.sh"
sudo chown "${KUBE_USER}:${KUBE_USER}" "${KUBE_HOME}/join-worker.sh"

echo "Worker join command saved to:"
echo "${KUBE_HOME}/join-worker.sh"

# 8. Display cluster status
echo "Kubernetes nodes:"
sudo -u "${KUBE_USER}" kubectl get nodes -o wide

echo "Master setup completed successfully."
```
