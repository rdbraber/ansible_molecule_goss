# Testing Ansible roles with Molecule,Goss and Docker

Recently I found out about testing your own created [Ansible](https://www.ansible.com) roles with [Molecule](https://github.com/metacloud/molecule). The default verifier for Molecule is [Testinfra](http://testinfra.readthedocs.io/en/latest/), but it's also possible to use [Goss](https://github.com/aelsabbahy/goss). As noted on their GitHub page, Goss is a YAML based serverspec alternative tool for validating a server's configuration. As I wanted to use this combination, I had a hard time to find proper documentation and examples. That's why I created this document.

For the installation of Ansible, Molecule and Goss I used a [Vagrant](https://www.vagrantup.com) [Centos 7](https://app.vagrantup.com/geerlingguy/boxes/centos7) box. The Vagrantfile can be found at: [https://github.com/rdbraber/ansible\_molecule\_goss](https://github.com/rdbraber/ansible_molecule_goss).

This blogpost is not about Vagrant and Git, so I assume that you're able to get the VM started.
If you really want to get started right away, make sure both Git and Vagrant are installed and use the following commands to start the VM and the installation of Ansible, Molecule, Goss and Docker:

~~~
git clone https://github.com/rdbraber/ansible_molecule_goss.git
cd ansible_molecule_goss
vagrant up
vagrant ssh
~~~

The test role as described in this document is available in the directory /home/vagrant/roles.

As a reference I will write down the steps to install Ansible, Molecule, Goss and Docker. All steps will be done with the vagrant account.

## Installing Molecule and Ansible

We're going to install Molecule with Pip, which is an installation tool for Python packages. First we have to install the python-pip package, with some other requirements, which we need later for the installation of Molecule. The python-pip package is only available in the [EPEL](https://fedoraproject.org/wiki/EPEL) (Extra Packages for Enterpise Linux) repository, so we have to install this repository first:

~~~
sudo yum install -y epel-release
sudo yum install -y gcc python-pip python-devel openssl-devel
~~~

After the command is finished, we can install Molecule, which also takes care of installing Ansible:

~~~
sudo pip install --upgrade pip
sudo pip install molecule
~~~

The first command will update pip to the latest version. The second command installs Molecule with some extra packages, which are required by Molecule. 

You can test the version of Ansible:

~~~
[vagrant@molecule ~]$ ansible --version
ansible 2.4.2.0
  config file = None
  configured module search path = [u'/home/vagrant/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/site-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.5 (default, Aug  4 2017, 00:39:18) [GCC 4.8.5 20150623 (Red Hat 4.8.5-16)]
~~~


Test the version of molecule:

~~~
[vagrant@molecule ~]$ molecule --version
molecule, version 2.5.0
~~~

## Installation of Goss

The installation of Goss is done by getting the installation script from the Goss site and then run this script:

~~~
curl -fsSL https://goss.rocks/install | GOSS_DST=/usr/local/sbin sh
~~~

Check the version of Goss:

~~~
[vagrant@molecule ~]$ goss --version
goss version v0.3.5
~~~

## Installation of Docker

For the installation of Docker we first have to add the configuration file for the repository. Also we have to add some extra packages:

~~~
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce
~~~

Make sure the Docker daemon is started and also after a reboot:

~~~
sudo systemctl start docker
sudo systemctl enable docker
~~~

Check the version of Docker:

~~~
[vagrant@molecule ~]$ sudo docker version
Client:
 Version:      17.09.1-ce
 API version:  1.32
 Go version:   go1.8.3
 Git commit:   19e2cf6
 Built:        Thu Dec  7 22:23:40 2017
 OS/Arch:      linux/amd64

Server:
 Version:      17.09.1-ce
 API version:  1.32 (minimum version 1.12)
 Go version:   go1.8.3
 Git commit:   19e2cf6
 Built:        Thu Dec  7 22:25:03 2017
 OS/Arch:      linux/amd64
 Experimental: false
~~~

Test if Docker works by running the hello-world container:

~~~
sudo docker run hello-world
~~~

If Docker is installed properly, the Hello from Docker! message is displayed.

When all of the above steps are performed, we are now ready to create a new Ansible role, which we can test with Molecule.

To make things a bit easier, we will add the user vagrant to the group docker. That way there is no need to use the sudo command for the docker command:

~~~
sudo usermod -G docker -a vagrant
~~~

Logout and login again to make to activate the change. Try to run the hello-world container again, but without the sudo command.

## Creating a new Ansible role

We are going to create an Ansible role that will install, configure and start a webserver. After the webserver is installed we want to test if the webserver is installed, configured and running. 
The role will be tested in a Docker container.

First create a roles directory in your home directory and go to that directory:

~~~
mkdir ~/roles && cd ~/roles
~~~

The new role should be initialised with the `molecule` command:

~~~
molecule init role --role-name httpd_webserver --verifier-name goss
~~~

The directory for the role is created, with the following content:

~~~
httpd_webserver
├── defaults
│   └── main.yml
├── handlers
│   └── main.yml
├── meta
│   └── main.yml
├── molecule
│   └── default
│       ├── create.yml
│       ├── destroy.yml
│       ├── Dockerfile.j2
│       ├── INSTALL.rst
│       ├── molecule.yml
│       ├── playbook.yml
│       ├── prepare.yml
│       ├── tests
│       │   └── test_default.yml
│       └── verifier.yml
├── README.md
├── tasks
│   └── main.yml
├── vars
│   └── main.yml
└── .yamllint
~~~

What you see is a directory named molecule inside the role directory. This directory contains all the configuration files for Molecule. The first file we are going take a look at, is the file INSTALL.rst. This file contains the requirements, which need to be in place before the role can be tested with Docker:

~~~
*******
Install
*******

Requirements
============

* Docker Engine
* docker-py

Install
=======

.. code-block:: bash

  $ sudo pip install docker-py
~~~

As shown in the file we need to install the docker-py package:

~~~
sudo pip install docker-py
~~~

## Create the play for the Ansible role

We are going to create a role, which will install a httpd webserver on a CentOS 7 image or container. So we need to edit the file ~/roles/httpd_webserver/tasks/main.yml. Add the following content to this file:

~~~
---
# tasks file for httpd_webserver

- name: Install the httpd package
  yum:
    name: httpd
    state: installed

- name: Start the webserver and make sure it is started at boot
  service:
    name: httpd
    state: started
    enabled: yes

- name: Configure the webserver to run at port 8080
  lineinfile:
    path: /etc/httpd/conf/httpd.conf
    regexp: '^Listen '
    insertafter: '^#Listen '
    line: 'Listen 8080'
  notify: restart httpd

- name: Create testpage for the webserver
  lineinfile:
    path: /var/www/html/test.html
    owner: apache
    group: apache
    mode: 0640
    create: yes
    line: 'testpage'
~~~

Also create the handler file ~/roles/httpd_webserver/handlers/main.yml to make sure the webserver is restarted if a change is made to the configuration file:

~~~
---
# handlers file for httpd_webserver

- name: restart httpd
  service:
    name: httpd
    state: restarted
~~~

## Configure molecule

The main configuration file for molecule is the file molecule.yml. One is already placed in the directory molecule/default. We need to modify this file so it will run our tests. Make sure it contains the following entries:

~~~
---
dependency:
  name: galaxy
driver:
  name: docker
lint:
  name: yamllint
platforms:
  - name: webserver-test
    hostname: webserver-test
    image: couchbase/centos7-systemd
    command: "/usr/sbin/init"
    privileged: True
provisioner:
  name: ansible
  lint:
    name: ansible-lint
scenario:
  name: default
verifier:
  name: goss
  enabled: True
~~~

Below a short explanation about the settings.

- dependency: If a role id dependent on other roles get name the location where to get them. In this case roles are downloaded from galaxy.ansible.com.
- driver: On which platform are we going to test our role. There's different kind of options, like Azure, Amazon EC2, Google Compute Engine (GCE), Vagrant and Docker. In these case we are going to test our role in a Docker container.
- lint: Which lint are we going to use on the yaml files.
- platforms: specifies the parameters needed for, in this case, the Docker container. **Because we want to start the webserver in the container, with help of systemd, we need a base container that supports systemd. Another thing to mention is the fact that in order to be able to run systemd, the container needs to run in privileged mode.**
- provisioner: Currently Ansible is the only provisioner that is supported by Molecule. To lint the Ansible playbook we wrote, we use ansible-lint.
- scenario: Molecule can work with different scenarios. The default one needs to be available at all time.
- verifier: Specifies the tool that's going to verify the outcome of our playbook. In our case we are going to use Goss.

All the other yaml files in the directory molecule/default are playbooks which are use to test the role:

- create.yml: Creates the Docker image that will be used to create a container. The Dockerfile used for this, is also located in the same directory (Dockerfile.j2).
- destroy.yml: In case the tests are ready, this playbook takes care of stopping the container and removal of the container.
- plabook.yml: This file contains a reference to the role we would like to test.
- prepare.yml: Can be used to add extra steps if needed before testing can proceed. When Docker is the driver for the tests, this file does not contain any extra steps.
- verifier.yml: This playbook takes care of the actual testing of the role. In case we use Goss as the verifier:
  
  - Download and installs Goss inside the running container
  - Copy the Goss testfile from our local machine (molecule/default/test/test_default.yml) inside the container
  - Runs the Goss tests


## Create test file for Goss

To be able to test our role, we need to specify which tests we would like to perform. These tests are located in the file molecule/default/tests/test_default.yml. An example of such a file is:

~~~
---

package:
  httpd:
    installed: true
    versions:
      - 2.4.6

service:
  httpd:
    enabled: true
    running: true

process:
  httpd:
    running: true

port:
  tcp:8080:
    listening: true

http:
  http://localhost:8080/test.html:
    status: 200
    body: [testpage]

file:
  /var/www/html/test.html:
    exists: true
    mode: "0640"
    owner: apache
    group: apache

command:
  httpd -v |grep -i version:
    exit-status: 0
    stdout:
      - "Server version: Apache/2.4.6 (CentOS)"
~~~

The tests in this file will test the following items:

- package: Check if the httpd package is installed and if it's version 2.4.6.
- service: Check if the httpd service is running and enabled at boottime.
- process: Check if a httpd process is currently running.
- port: Check if there is a service available at port 8080.
- http: Check if the webserver can be reached at the testpage and if the testpage contains the correct content.
- file: Check if the file /var/www/html/test.html does exists and has the correct owner, group and file rights.
- command: Use a bash command to verify the version of the webserver, check the exit status and the output of the command. 

## Run the molecule test

To test the role, run the command `molecule test` from within the role directory. The first output you will see are all the steps that are performed during the test:

~~~
[vagrant@molecule httpd_webserver]$ molecule test
--> Test matrix

└── default
    ├── lint
    ├── destroy
    ├── dependency
    ├── syntax
    ├── create
    ├── prepare
    ├── converge
    ├── idempotence
    ├── side_effect
    ├── verify
    └── destroy
~~~

- lint: Checks all the yaml files with yamllint
- destroy: If there is already a container running with the same name, destroy that container
- dependency: In case the role depends on other roles, the roles are downloaded
- syntax: Checks the role with ansible-lint
- create: Creates the Docker image, and use that image to start our test container.
- prepare: In case extra steps are required, these will be handled by this step.
- converge: Run the role inside the test container.
- idempotence: Run the role again to check for idempotency. In other words, can you run the role a second time with the same results.
- side_effect: Intended to test HA failover scenarios or the like. See [Ansible provisioner](https://molecule.readthedocs.io/en/latest/configuration.html#id12)
- verify: Run the Goss tests inside the container.
- destroy: Destroys the container.

The first time the command is run, it can take some extra time, as it needs to download the base image for our own image.
If the test did run successfully you will see the following message near the end of the output:

~~~
Verifier completed successfully
~~~

The `molecule test` command tests all the steps. It's also possible to only test certain steps. Use the `molecule --help` command to show the steps that can be tested:

~~~
[vagrant@molecule httpd_webserver]$ molecule --help
Usage: molecule [OPTIONS] COMMAND [ARGS]...

   _____     _             _
  |     |___| |___ ___ _ _| |___
  | | | | . | | -_|  _| | | | -_|
  |_|_|_|___|_|___|___|___|_|___|

  Molecule aids in the development and testing of Ansible roles.

  Enable autocomplete issue:

    eval "$(_MOLECULE_COMPLETE=source molecule)"

Options:
  --debug / --no-debug  Enable or disable debug mode. Default is disabled.
  --version             Show the version and exit.
  --help                Show this message and exit.

Commands:
  check        Use the provisioner to perform a Dry-Run...
  converge     Use the provisioner to configure instances...
  create       Use the provisioner to start the instances.
  dependency   Manage the role's dependencies.
  destroy      Use the provisioner to destroy the instances.
  idempotence  Use the provisioner to configure the...
  init         Initialize a new role or scenario.
  lint         Lint the role.
  list         Lists status of instances.
  login        Log in to one instance.
  prepare      Use the provisioner to prepare the instances...
  side-effect  Use the provisioner to perform side-effects...
  syntax       Use the provisioner to syntax check the role.
  test         Test (lint, destroy, dependency, syntax,...
  verify       Run automated tests against instances.
~~~

We could for example only test the lint function:

~~~
[vagrant@molecule httpd_webserver]$ molecule lint
--> Test matrix

└── default
    └── lint

--> Scenario: 'default'
--> Action: 'lint'
--> Executing Yamllint on files found in /home/vagrant/roles/httpd_webserver/...
    /home/vagrant/roles/httpd_webserver/tasks/main.yml
      13:14     warning  truthy value is not quoted  (truthy)
      29:13     warning  truthy value is not quoted  (truthy)

    /home/vagrant/roles/httpd_webserver/molecule/default/molecule.yml
      13:17     warning  truthy value is not quoted  (truthy)
      22:12     warning  truthy value is not quoted  (truthy)

Lint completed successfully.
Skipping, no tests found.
--> Executing Ansible Lint on /home/vagrant/roles/httpd_webserver/molecule/default/playbook.yml...
Lint completed successfully.
~~~

If you want to get rid of the warning messages, you could edit the file .yamllint which is in the root of the role directory. Change it to something like this:

~~~
extends: default

rules:
  braces:
    max-spaces-inside: 1
    level: error
  brackets:
    max-spaces-inside: 1
    level: error
  line-length: disable
  # NOTE(retr0h): Templates no longer fail this lint rule.
  #               Uncomment if running old Molecule templates.
  truthy: disable
~~~

More info about yamllint can be found at: [https://yamllint.readthedocs.io/en/latest/](https://yamllint.readthedocs.io/en/latest/.)

## Problems I encountered

During the installation of the components Ansible, Molecule, Goss and Docker I had some issues once everything was installed. I noticed that the order in which things were installed did matter. This was especially true for the components installed with pip. The order of installation in this document should work.

I had some issues with the packages urllib3 and chardet while running the `molecule test` command:

~~~
/usr/lib/python2.7/site-packages/requests/__init__.py:80: RequestsDependencyWarning: urllib3 (1.22) or chardet (2.2.1) doesn't match a supported version!
  RequestsDependencyWarning)
~~~

which I was able to resolve with the following commands:

~~~
sudo pip uninstall -y chardet urllib3
sudo pip install --upgrade chardet urllib3
~~~



