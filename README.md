# ubuntu-dev-machine-setup | Ubuntu 20.04 LTS

This repo contains Ansible playbooks to configure your system as a development machine upon a clean install.

- **Ubuntu 20.04**

## Pre-requisites

On the system which you are going to setup using Ansible, perform these steps.

You need to install `ansible` and `git` before running the playbooks. You can either install it using `pip` or `apt`.

```
/usr/bin/sudo apt install ansible git
```

And clone this repo

```
git clone https://github.com/jankul02/ubuntu-dev-machine-setup.git
cd ubuntu-dev-machine-setup
```

## Running the playbooks to configure your system

**Invoke the following as yourself, the primary user of the system. Do not run as `root`.**

```
ansible-playbook main.yml  -e "local_username=$(id -un)" -K
```

Enter the sudo password when asked for `BECOME password:`.




ssh -fNL 3389:hit.nata4d.de:3389 hit.nata4d.de  -p 4242
# now start remote desktopviewer


ssh  hit.nata4d.de  -p 4242