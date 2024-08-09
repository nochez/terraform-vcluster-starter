#!/bin/bash

# ==========================
# Install script for new box
# ==========================

# Executed on the VM to install new software
INSTALL_SCRIPT="install_software.sh"
cat <<'EOF' > $INSTALL_SCRIPT
#!/bin/bash

set -e

echo "Installing dependencies..."
sudo zypper -n install wireguard-tools iptables wget unzip 2>&1 | grep -v 'install-info: No such file or directory for /usr/share/info/wget.info.gz'

echo "Downloading and installing k3s..."
sudo curl -o /usr/local/bin/k3s_install.sh -sfL https://get.k3s.io
sudo chmod +x /usr/local/bin/k3s_install.sh

echo "Downloading and installing Nomad..."
wget https://releases.hashicorp.com/nomad/1.8.2/nomad_1.8.2_linux_arm64.zip
unzip nomad_1.8.2_linux_arm64.zip
sudo mv nomad /usr/local/bin/
EOF

# ==============================
# Variables
# ==============================

# Base VM box to be used
BASE_VM_BOX="opensuse/Leap-15.5.aarch64"

# Name of the custom Vagrant box to be created
BOX_NAME="CN-opensuse-leap15.5"

# ====================================
# Script settings (no need for change)
# ====================================

# Name of the VM instance (used internally)
VM_NAME="tmpbox"

# File names for the disk image and the converted qcow2 image
IMG_IMAGE="custom_base.img"
QCOW2_IMAGE="custom_base.qcow2"

# Directory where the final Vagrant box will be created
VAGRANT_DIR="${BOX_NAME}"

# Final Vagrant box file name
VAGRANT_BOX="${BOX_NAME}.box"

# QEMU-specific settings (these are constant for aarch64 on macOS)
QEMU_PROVIDER="qemu"
QEMU_IMAGE_FORMAT="qcow2"
ARCHITECTURE="aarch64"

VIRTUAL_SIZE="20"  # Set according to your VM's disk size

# Temporary swap file in case vagrantfile present
TEMP_VAGRANTFILE="Vagrantfile.temp"

# ==============================
# Utils
# ==============================

handle_error() {
    echo "Error on line $1"
    destroy_vm_if_running
    restore_vagrantfile
    exit 1
}

destroy_vm_if_running() {
    VM_STATUS=$(vagrant status --machine-readable | grep ",state," | cut -d ',' -f4)
    if [ "$VM_STATUS" == "running" ]; then
        echo "Destroying the running VM..."
        vagrant destroy -f
    fi
}

restore_vagrantfile() {
    if [ -f "$TEMP_VAGRANTFILE" ]; then
        mv $TEMP_VAGRANTFILE Vagrantfile
        echo "Restored the original Vagrantfile."
    fi
}

wait_for_vm_stop() {
    echo "Waiting for VM to fully stop..."
    while [ "$(vagrant status --machine-readable | grep ",state," | cut -d ',' -f4)" == "running" ]; do
        sleep 2
    done
    echo "VM has fully stopped."
}

# Trap errors and call handle_error function
trap 'handle_error $LINENO' ERR

# ==============================
# Main
# ==============================

# Step 0: Backup the existing Vagrantfile (if it exists)
if [ -f "Vagrantfile" ]; then
    echo "Renaming existing Vagrantfile to $TEMP_VAGRANTFILE..."
    mv Vagrantfile $TEMP_VAGRANTFILE
fi

# Step 1: Create and configure the base VM with specific QEMU settings
echo "Creating the base VM with Vagrant..."
cat <<EOF > Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "$BASE_VM_BOX"

  config.vm.provider "qemu" do |qemu|
    qemu.qemu_binary = "/usr/local/bin/qemu-system-aarch64"
    qemu.qemu_dir    = "/usr/local/share/qemu"
    qemu.memory      = 2048
    qemu.cpus        = 2
    qemu.disk_size   = "20G"
    qemu.machine     = "virt,accel=hvf,highmem=off"
    qemu.arch        = "aarch64"
    qemu.cpu         = "host"
  end
end
EOF

vagrant up --provider=$QEMU_PROVIDER

# Step 2: Make the installation script executable
chmod +x $INSTALL_SCRIPT

# Step 3: Upload and execute the installation script on the VM
echo "Transferring and executing the installation script on the VM..."
vagrant upload $INSTALL_SCRIPT /tmp/$INSTALL_SCRIPT
vagrant ssh -c "bash /tmp/$INSTALL_SCRIPT"

# Step 4: Halt the VM
echo "Halting the VM..."
vagrant halt

# Wait for the VM to fully stop before proceeding
wait_for_vm_stop

# Step 5: Locate and convert the disk image from .img to .qcow2
echo "Locating and converting the disk image..."
DISK_IMAGE=$(find . -name "*.img")

if [ -z "$DISK_IMAGE" ]; then
    echo "No img image found. Exiting."
    echo "Current directory contents:"
    ls -al
    handle_error $LINENO
fi

qemu-img convert -O $QEMU_IMAGE_FORMAT $DISK_IMAGE $QCOW2_IMAGE

# Step 6: Prepare the directory structure for the Vagrant box
echo "Preparing the Vagrant box directory..."
mkdir -p $VAGRANT_DIR

mv $QCOW2_IMAGE $VAGRANT_DIR/box.img

cat <<EOF > $VAGRANT_DIR/metadata.json
{
  "provider": "$QEMU_PROVIDER",
  "format": "$QEMU_IMAGE_FORMAT",
  "virtual_size": "$VIRTUAL_SIZE",
  "architecture": "$ARCHITECTURE"
}
EOF

# Step 7: Package the directory into a Vagrant box
echo "Packaging the Vagrant box..."
tar czvf $VAGRANT_BOX -C $VAGRANT_DIR .

# Step 8: Add the new Vagrant box to Vagrant's local storage
echo "Adding the box to Vagrant..."
vagrant box add $VAGRANT_BOX --name $BOX_NAME --force

# Cleanup temporary files and directories
echo "Cleaning up..."
rm -rf $VAGRANT_DIR
rm -f $INSTALL_SCRIPT
rm -f $VAGRANT_BOX  # Delete the .box file

echo "Custom Vagrant box created and added: $BOX_NAME"

# Restore the original Vagrantfile if it was backed up
restore_vagrantfile

echo "Success"

