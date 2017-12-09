VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

# Ansible server

config.vm.define :molecule do |molecule_config|
  molecule_config.vm.box = "geerlingguy/centos7"
  molecule_config.vm.hostname = "molecule.molecule.home"
  molecule_config.vm.provision "shell", path: "configure_node.sh"
  config.vm.provider "virtualbox" do |v|
     v.memory = 1024
     v.cpus = 2
  end
end

end
