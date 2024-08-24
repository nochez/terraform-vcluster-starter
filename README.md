# terraform-vcluster-starter

This project is designed to set up a small Kubernetes (K3s) and HashiCorp Nomad cluster using Vagrant and Ansible. The cluster will be used to test microservices in a controlled environment. WireGuard VPN is used to securely connect the virtual machines (VMs) within the cluster.

## Project Structure
Here is a breakdown of the key files and directories in this project:

Vagrantfile: Defines the VMs and their configurations. This file uses QEMU as the provider and configures each VM with necessary packages, SSH keys, and WireGuard VPN settings.

playbook.yml: Ansible playbook that automates the setup process for the K3s and Nomad cluster. It handles everything from setting up Vagrant and WireGuard to installing and configuring K3s and Nomad.

ansible_key & ansible_key.pub: SSH keys used by Ansible for secure communication with the VMs. Will be generated at build time if they dont exist.

check_ports.sh: A script to ensure that the required SSH ports are available before proceeding with the Vagrant setup.

files/:

ansible_inventory: Contains the inventory of the hosts for Ansible.
tests/: Contains Kubernetes manifests for basic k8s testing, including nginx-deployment.yaml and nginx-service.yaml.
k3s-192.168.11.2.yaml: The kubeconfig file for accessing the K3s cluster, that is automatically generated at build time.

nomad_bootstrap_token.json: Contains the bootstrap token for managing Nomad's ACL. Generated at deploy time.

templates/: Contains Jinja2 templates used by Ansible to generate configuration files for K3s, Nomad, and system services.

k3s-config.yaml.j2: Template for K3s configuration.
nomad.hcl.j2: Template for Nomad client configuration.
nomad.service.j2: Systemd service file template for Nomad.
resolv.conf.j2: Template for DNS resolver configuration.
server.hcl.j2: Template for Nomad server configuration.
wg_setup.sh: Script to set up the WireGuard VPN.

wireguard-configs/: Contains WireGuard configuration files for the server and VMs. This is a temporal directory created at build time.

server_private.key & server_public.key: WireGuard keys for the server.
vm1_private.key & vm1_public.key: WireGuard keys for VM1.
wg0-server.conf: WireGuard configuration for the server.
wg0-vm1.conf: WireGuard configuration for VM1.

##Setup Instructions
###Prerequisites

Ensure you have the following installed on your local machine:

Vagrant: To create and manage VMs.
QEMU: As the VM provider.
Ansible: To automate the configuration of the VMs and the cluster.
WireGuard: To create a VPN for secure communication between the VMs.

###Steps to Set Up the Cluster

Run the Ansible Playbook:

```ansible-playbook -i files/ansible_inventory playbook.yml --ask-become-pass```

Execute the Ansible playbook with ansible-playbook playbook.yml. This playbook will:

* Ensure that WireGuard VPN is running.
* Bring up the VMs with Vagrant
* Install/provision necessary packages and configuration on the VMs.
* Set up the K3s cluster on the designated node.
* Install and configure Nomad on both the server and client nodes.
* Fetch the kubeconfig for the K3s cluster and store it locally.

#### Check Cluster Status:

Verify the setup by checking the status of the K3s and Nomad clusters. You can use kubectl to interact with K3s and nomad CLI to interact with Nomad.
Deploy and Test Microservices:

Use the Kubernetes manifests in the files/tests/ directory to deploy and test microservices on the K3s cluster.

###Additional Scripts

* check_ports.sh: Ensures that required SSH ports are available before the Vagrant setup.
* wg_setup.sh: Sets up the WireGuard VPN if it’s not already running.

### Troubleshooting
For issues with WireGuard, manually run wg show to check the status of the VPN.


# Manual Testing
## Nomad

```
export NOMAD_TOKEN=<find it in nomad_bootstrap_token.json>
export NOMAD_ADDR="http://192.168.11.2:4646"
nomad node status
```

## Test k8s can deploy a service

```
export KUBECONFIG=k3s-192.168.11.2.yaml
kubectl get nodes
kubectl apply -f files/tests/nginx-deployment.yaml
kubectl apply -f files/tests/nginx-service.yaml
```

Then all VMs should be able to 
```
nslookup nginx-service
```

