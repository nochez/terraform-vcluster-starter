Vagrant.configure("2") do |config|

  def configure_vm(vm, vm_name, ssh_port, wireguard_conf)
    vm.vm.box = "opensuse/Tumbleweed.x86_64"
    vm.vm.synced_folder ".", "/vagrant", type: "rsync"


    vm.vm.provider "qemu" do |qemu|
      qemu.qemu_binary = "/usr/local/bin/qemu-system-x86_64"
      qemu.qemu_dir    = "/usr/local/share/qemu"
      qemu.memory      = 4096
      qemu.cpus        = 4
      qemu.disk_size   = "20G"
      qemu.machine     = "q35,accel=tcg"
      qemu.arch        = "x86_64"
      qemu.cpu         = "qemu64"

      qemu.net_device = "virtio-net-pci"
      qemu.customize ["-nic", "user,id=net0,hostfwd=tcp::#{ssh_port}-:22"]
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
    {name: "vm64", port: 60023, wireguard: "wg0-vm1.conf"}
  ]

  vms.each do |vm|
    config.vm.define vm[:name] do |node|
      configure_vm(node, vm[:name], vm[:port], vm[:wireguard])
    end
  end
end


