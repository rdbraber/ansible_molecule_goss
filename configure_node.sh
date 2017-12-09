#!/bin/bash

# Install EPEL and package python-pip + dependencies

yum install -y epel-release
yum install -y gcc python-pip python-devel openssl-devel


# Update pip and install docker-py and Molecule
# Ansible will be installed as well

pip install --upgrade pip
pip install docker-py
pip install molecule


# Install Goss

curl -fsSL https://goss.rocks/install | GOSS_DST=/usr/local/sbin sh


# Make sure the location 

# Install Docker + some dependencies

yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce


# Start Docker and enable it to start at boot

systemctl start docker
systemctl enable docker


# Add the user vagrant to group docker

usermod -G docker -a vagrant


# Copy the role to the home directory of the vagrant user

mkdir /home/vagrant/roles
cp -pr /vagrant/ansible/roles/. /home/vagrant/roles
chown -R vagrant:vagrant /home/vagrant/roles


# Because of error message:

# /usr/lib/python2.7/site-packages/requests/__init__.py:80: RequestsDependencyWarning: urllib3 (1.22) or chardet (2.2.1) doesn't match a supported version!
#  RequestsDependencyWarning)

pip uninstall -y chardet urllib3
pip install --upgrade chardet urllib3


# Show versions of all products

ansible --version
molecule --version
goss --version
docker version

# The End

exit 0
