#!/bin/bash

# Variables
BOX_NAME="custom-opensuse-leap15.5"
VM_NAME="basebox"
IMG_IMAGE="custom_base.img"
QCOW2_IMAGE="custom_base.qcow2"
VAGRANT_DIR="${BOX_NAME}"
VAGRANT_BOX="${BOX_NAME}.box"
QEMU_PROVIDER="qemu"
QEMU_IMAGE_FORMAT="qcow2"
VIRTUAL_SIZE="20"  # Set according to your VM's disk size
ARCHITECTURE="aarch64"
TEMP_VAGRANTFILE="Vagrantfile.temp"
INSTALL_SCRIPT="install_software.sh"

# Function to handle errors
handle_error() {
    echo "Error on line $1"
    destroy_vm_if_running
    restore_vagrantfile
    exit 1
}

# Function to destroy the VM if it is running
destroy_vm_if_running() {
    VM_STATUS=$(vagrant status --machine-readable | grep ",state," | cut -d ',' -f4)
    if [ "$VM_STATUS" == "running" ]; then
        echo "Destroying the running VM..."
        vagrant destroy -f
        if [ $? -ne 0 ]; then
            echo "Failed to destroy the VM."
            exit 1
        fi
    fi
}

# Function to restore the original Vagrantfile
restore_vagrantfile() {
    if [ -f "$TEMP_VAGRANTFILE" ]; then
        mv $TEMP_VAGRANTFILE Vagrantfile
        echo "Restored the original Vagrantfile."
    fi
}

# Function to wait for VM to stop completely
wait_for_vm_stop() {
    echo "Waiting for VM to fully stop..."
    while [ "$(vagrant status --machine-readable | grep ",state," | cut -d ',' -f4)" == "running" ]; do
        sleep 2
    done
    echo "VM has fully stopped."
}

# Trap errors
trap 'handle_error $LINENO' ERR

# Step 0: Rename existing Vagrantfile if it exists
if [ -f "Vagrantfile" ]; then
    echo "Renaming existing Vagrantfile to $TEMP_VAGRANTFILE..."
    mv Vagrantfile $TEMP_VAGRANTFILE
    if [ $? -ne 0 ]; then
        echo "Failed to rename the existing Vagrantfile."
        exit 1
    fi
fi

# Step 1: Create and configure the base VM (using Vagrant with specific QEMU configuration)
echo "Creating the base VM with Vagrant..."
cat <<EOF > Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.box = "opensuse/Leap-15.5.aarch64"

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
if [ $? -ne 0 ]; then
    echo "Failed to create and configure the base VM."
    handle_error $LINENO
fi

# Step 2: Create the installation script
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

# Make the script executable
chmod +x $INSTALL_SCRIPT

# Step 3: Transfer and execute the installation script on the VM
echo "Transferring and executing the installation script on the VM..."
vagrant upload $INSTALL_SCRIPT /tmp/$INSTALL_SCRIPT
vagrant ssh -c "bash /tmp/$INSTALL_SCRIPT"
if [ $? -ne 0 ]; then
    echo "Failed to execute the installation script on the VM."
    handle_error $LINENO
fi

# Step 4: Halt the VM
echo "Halting the VM..."
vagrant halt
if [ $? -ne 0 ]; then
    echo "Failed to halt the VM."
    handle_error $LINENO
fi

# Wait for the VM to fully stop
wait_for_vm_stop

# Step 5: Locate and (optionally) convert the disk image
echo "Locating and converting the disk image..."
DISK_IMAGE=$(find . -name "*.img")

if [ -z "$DISK_IMAGE" ]; then
    echo "No img image found. Exiting."
    echo "Current directory contents:"
    ls -al
    handle_error $LINENO
fi

qemu-img convert -O $QEMU_IMAGE_FORMAT $DISK_IMAGE $QCOW2_IMAGE
if [ $? -ne 0 ]; then
    echo "Failed to convert the disk image."
    handle_error $LINENO
fi

# Step 6: Prepare the directory for the Vagrant box
echo "Preparing the Vagrant box directory..."
mkdir -p $VAGRANT_DIR
if [ $? -ne 0 ]; then
    echo "Failed to create Vagrant box directory."
    handle_error $LINENO
fi

mv $QCOW2_IMAGE $VAGRANT_DIR/box.img
if [ $? -ne 0 ]; then
    echo "Failed to move the disk image."
    handle_error $LINENO
fi

cat <<EOF > $VAGRANT_DIR/metadata.json
{
  "provider": "$QEMU_PROVIDER",
  "format": "$QEMU_IMAGE_FORMAT",
  "virtual_size": "$VIRTUAL_SIZE",
  "architecture": "$ARCHITECTURE"
}
EOF
if [ $? -ne 0 ]; then
    echo "Failed to create metadata.json."
    handle_error $LINENO
fi

# Step 7: Package the directory into a Vagrant box
echo "Packaging the Vagrant box..."
tar czvf $VAGRANT_BOX -C $VAGRANT_DIR .
if [ $? -ne 0 ]; then
    echo "Failed to package the Vagrant box."
    handle_error $LINENO
fi

# Step 8: Add the box to Vagrant
echo "Adding the box to Vagrant..."
vagrant box add $VAGRANT_BOX --name $BOX_NAME --force
if [ $? -ne 0 ]; then
    echo "Failed to add the Vagrant box."
    handle_error $LINENO
fi

# Cleanup
echo "Cleaning up..."
rm -rf $VAGRANT_DIR
if [ $? -ne 0 ]; then
    echo "Failed to clean up temporary files."
    handle_error $LINENO
fi

rm -f $INSTALL_SCRIPT

echo "Custom Vagrant box created and added: $VAGRANT_BOX"

# Restore the original Vagrantfile if it was renamed
restore_vagrantfile

echo "Process completed successfully."

