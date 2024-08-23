Vagrant.configure("2") do |config|

  def configure_vm(vm, vm_name, ssh_port, wireguard_conf)
    vm.vm.box = "opensuse/Tumbleweed.aarch64"
    vm.vm.synced_folder ".", "/vagrant", type: "rsync"

    vm.vm.provider "qemu" do |qemu|
      qemu.qemu_binary = "/usr/local/bin/qemu-system-aarch64"
      qemu.qemu_dir    = "/usr/local/share/qemu"
      qemu.memory      = 2048
      qemu.cpus        = 2
      qemu.disk_size   = "20G"
      qemu.machine     = "virt,accel=hvf,highmem=off"
      qemu.arch        = "aarch64"
      qemu.cpu         = "host"
      qemu.ssh_port    = ssh_port
    end

    vm.ssh.username   = "vagrant"
    vm.ssh.insert_key = false

    vm.vm.provision "shell", inline: <<-SHELL
      echo 'Installing python3'
      sudo zypper -n install python3
    SHELL

    vm.vm.provision "shell", inline: <<-SHELL
      if [ -f /vagrant/ansible_key.pub ]; then
        mkdir -p /home/vagrant/.ssh
        cp /vagrant/ansible_key.pub /home/vagrant/.ssh/authorized_keys
        chmod 600 /home/vagrant/.ssh/authorized_keys
        chown -R vagrant:vagrant /home/vagrant/.ssh
      else
        echo "WARNING: /vagrant/ansible_key.pub not found. Please ensure the SSH key exists."
      fi
    SHELL

    vm.vm.provision "shell", inline: <<-SHELL
      echo 'Setting up WireGuard WPN with #{wireguard_conf}'
      sudo zypper -n install wireguard-tools iptables
      sudo mkdir -p /etc/wireguard
      sudo cp /vagrant/wireguard-configs/#{wireguard_conf} /etc/wireguard/wg0.conf
      sudo chmod 600 /etc/wireguard/wg0.conf
      sudo wg-quick up wg0
    SHELL
  end

  # Lets get 4 VMs
  vms = [
    {name: "vm1", port: 60023, wireguard: "wg0-vm1.conf"}
  ]

  vms.each do |vm|
    config.vm.define vm[:name] do |node|
      configure_vm(node, vm[:name], vm[:port], vm[:wireguard])
    end
  end
end


