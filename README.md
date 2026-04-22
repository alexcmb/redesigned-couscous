# Kubernetes Cluster on Azure — kubeadm

Déploiement automatisé d'un cluster Kubernetes sur Azure via Terraform et kubeadm.

## Architecture

```
Azure Resource Group
└── Virtual Network (10.0.0.0/16)
    └── Subnet (10.0.1.0/24)
        ├── NSG (SSH, Kube API, trafic interne)
        ├── VM Control Plane  (Standard_B2s, Ubuntu 22.04)
        ├── VM Worker 1       (Standard_B2s, Ubuntu 22.04)
        └── VM Worker 2       (Standard_B2s, Ubuntu 22.04)
```

**Stack :**
- Kubernetes **v1.30** via kubeadm
- Container runtime : **containerd**
- CNI : **Flannel** (`10.244.0.0/16`)
- Cloud : **Azure** (France Central)

## Prérequis

| Outil | Version minimale |
|---|---|
| Terraform | >= 1.3 |
| Azure CLI | >= 2.50 |
| Compte Azure | Subscription active |

```bash
# Vérifier les versions
terraform version
az version
```

## Authentification Azure

```bash
az login
az account set --subscription "<SUBSCRIPTION_ID>"

# Vérifier le compte actif
az account show
```

## Structure du projet

```
terraform/
├── main.tf                    # Providers, resource group, tokens kubeadm
├── variables.tf               # Variables d'entrée
├── outputs.tf                 # Sorties (IPs, kubeconfig, clé SSH)
├── network.tf                 # VNet, Subnet, NSG
├── compute.tf                 # VMs control plane et workers
└── cloud-init/
    ├── control-plane.yaml     # Bootstrap kubeadm init + Flannel
    └── worker.yaml            # Bootstrap kubeadm join
```

## Variables

| Variable | Type | Défaut | Description |
|---|---|---|---|
| `prefix` | string | `SDV_PRD` | Préfixe des ressources Azure |
| `location` | string | `France Central` | Région Azure |
| `worker_count` | number | `2` | Nombre de nœuds workers |
| `vm_size` | string | `Standard_B2s` | SKU des VMs (2 vCPU, 4 GB RAM min.) |
| `admin_username` | string | `adminuser` | Utilisateur admin des VMs |

### Fichier tfvars personnalisé

Créer un fichier `terraform.tfvars` pour surcharger les valeurs par défaut :

```hcl
prefix         = "MON_PROJET"
location       = "West Europe"
worker_count   = 3
vm_size        = "Standard_B4ms"
admin_username = "kubeadmin"
```

## Déploiement

### 1. Initialiser Terraform

```bash
cd terraform
terraform init
```

### 2. Valider la configuration

```bash
terraform validate
terraform fmt -check -recursive
```

### 3. Planifier

```bash
terraform plan
# ou avec un fichier tfvars
terraform plan -var-file="terraform.tfvars"
# sauvegarder le plan
terraform plan -out=tfplan
```

### 4. Appliquer

```bash
terraform apply
# ou à partir du plan sauvegardé
terraform apply tfplan
```

Le déploiement dure environ **5–8 minutes** (provisioning Azure + cloud-init kubeadm).

### 5. Récupérer les outputs

```bash
# IPs publiques
terraform output control_plane_public_ip
terraform output worker_public_ips

# Clé SSH (écrire dans un fichier)
terraform output -raw ssh_private_key > ~/.ssh/id_rsa_k8s
chmod 600 ~/.ssh/id_rsa_k8s

# Commande SSH prête à l'emploi
terraform output ssh_command_cp

# Kubeconfig
terraform output kubectl_config_command
```

## Connexion SSH

```bash
# Récupérer la clé depuis le state
terraform output -raw ssh_private_key > ~/.ssh/id_rsa_k8s
chmod 600 ~/.ssh/id_rsa_k8s

# Se connecter au control plane
ssh -i ~/.ssh/id_rsa_k8s adminuser@<CONTROL_PLANE_IP>

# Se connecter à un worker (remplacer l'IP)
ssh -i ~/.ssh/id_rsa_k8s adminuser@<WORKER_IP>
```

### Sur Windows (PowerShell)

```powershell
terraform output -raw ssh_private_key | Set-Content "$env:USERPROFILE\.ssh\id_rsa_k8s" -Encoding ascii

icacls "$env:USERPROFILE\.ssh\id_rsa_k8s" /inheritance:r
icacls "$env:USERPROFILE\.ssh\id_rsa_k8s" /grant "${env:USERNAME}:(R)"

ssh -i "$env:USERPROFILE\.ssh\id_rsa_k8s" adminuser@<CONTROL_PLANE_IP>
```

## Gestion du cluster Kubernetes

### Récupérer le kubeconfig

```bash
# Depuis la machine locale
ssh -i ~/.ssh/id_rsa_k8s adminuser@<CONTROL_PLANE_IP> \
  'sudo cat /etc/kubernetes/admin.conf' > kubeconfig.yaml

export KUBECONFIG=./kubeconfig.yaml
kubectl get nodes
```

### Vérifications post-déploiement

```bash
# Sur le control plane
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get nodes -o wide
sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get pods -A

# Vérifier le cloud-init
sudo cloud-init status --wait
sudo tail -100 /var/log/cloud-init-output.log

# Vérifier les services
sudo systemctl status kubelet containerd

# Vérifier les logs kubelet
sudo journalctl -u kubelet --no-pager | grep -E "error|Error" | tail -20
```

Résultat attendu :

```
NAME                  STATUS   ROLES           AGE   VERSION
sdv-prd-vm-cp-1       Ready    control-plane   5m    v1.30.x
sdv-prd-vm-worker-1   Ready    <none>          4m    v1.30.x
sdv-prd-vm-worker-2   Ready    <none>          4m    v1.30.x
```

### Ajouter un nœud worker manuellement

```bash
# Récupérer la commande join depuis les outputs (sensible)
terraform output -raw kubeadm_join_command

# Sur le nouveau worker, après installation de kubeadm/kubelet/kubectl :
sudo kubeadm join <CP_PRIVATE_IP>:6443 \
  --token <TOKEN> \
  --discovery-token-unsafe-skip-ca-verification \
  --cri-socket=unix:///run/containerd/containerd.sock
```

### Générer un nouveau token join (si expiré)

```bash
# Sur le control plane
kubeadm token create --print-join-command
```

### Réinitialiser un nœud

```bash
# Sur le nœud à réinitialiser
sudo kubeadm reset -f
sudo systemctl stop kubelet
sudo rm -rf /etc/kubernetes /var/lib/kubelet /var/lib/etcd ~/.kube
```

## Destruction de l'infrastructure

```bash
terraform destroy
# ou sans confirmation interactive
terraform destroy -auto-approve
```

## Réseau

| Plage | Usage |
|---|---|
| `10.0.0.0/16` | VNet Azure |
| `10.0.1.0/24` | Subnet VMs |
| `10.244.0.0/16` | Pod network (Flannel) |

### Règles NSG

| Règle | Port | Source | Description |
|---|---|---|---|
| SSH | 22/TCP | `*` | Accès SSH aux VMs |
| KubeAPI | 6443/TCP | `*` | API Kubernetes |
| AllowInternal | `*` | `10.0.0.0/16` | Trafic interne VNet |

> **Attention :** SSH et l'API Kubernetes sont ouverts sur `0.0.0.0/0`. Restreindre `source_address_prefix` à votre IP en production.

## Providers Terraform

| Provider | Version | Usage |
|---|---|---|
| `hashicorp/azurerm` | ~> 3.0 | Ressources Azure |
| `hashicorp/tls` | ~> 4.0 | Génération clé SSH RSA-4096 |
| `hashicorp/random` | ~> 3.0 | Génération token kubeadm |

## Limitations connues

- **State local** : pas de backend distant configuré. Ne pas utiliser tel quel en production (risque de perte du state).
- **`--discovery-token-unsafe-skip-ca-verification`** : le hash du CA ne peut pas être connu avant l'init du control plane en cloud-init. Acceptable en environnement isolé, à remplacer par une approche PKI en production.
- **Token TTL 0** : le token kubeadm n'expire jamais. Rotation manuelle recommandée après le provisioning.
- **Image `latest`** : la version de l'image Ubuntu peut varier entre deux `terraform apply`.
