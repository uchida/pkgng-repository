# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "uchida/poudriere"
  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 1
    vb.memory = 2048
    #vb.gui = true
  end
  config.ssh.shell = "/bin/sh"
  config.vm.network "private_network", ip: "10.0.1.15"
  config.vm.synced_folder ".", "/vagrant", nfs: true

  config.vm.provision "shell", path: "provision.sh"
end