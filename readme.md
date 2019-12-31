# Build Boxes

## Introduction

A lot of projects are already available on GitHub to build `.box` files for vagrant. An excellent example and a source of inspiration for this work is [windows-2016-vagrant](https://github.com/rgl/windows-2016-vagrant).

The goal of this project is to provide:

* An easy to use building environment for Windows OS boxes
* Updated and syspreped images that can easily be created/destroyed to avoid Windows License issues
* An easier debugging environment to build boxes by separating this process into 4 steps

## Limitations

At the moment of writing, the only supported provider is `virtualbox`. The project was built to easily extend to other providers.

This project has only been tested on Ubuntu Linux host machine.

## Requirements

* pipenv (python 3)
* A provider
  * Virtualbox (the only supported at the moment)
* packer - https://www.packer.io/
* packer plugin
  * Windows update - https://github.com/rgl/packer-provisioner-windows-update
* vagrant - https://www.vagrantup.com/

## Installation

The use `build-boxes`, you need to install the python depedencies. They can easily be installed using the following commands

```
git clone https://github.com/df3l0p/build-boxes.git
python3 -m pipenv install
```

To switch in the pipenv environment

```
pipenv shell
```

At this point, you are able to build boxes

## Build boxes

To list all supported boxes
```bash
invoke build.list-box
```

Building all steps for a box
```bash
invoke build.build-box -b <box_name> -p <provider> 
invoke build.build-box -b windows_10-amd64 -p virtualbox
```

Building steps since a particular step for a box
```bash
invoke build.build-box -b <box_name> -p <provider> -i <step_since>
invoke build.build-box -b windows_10-amd64 -p virtualbox -i 2
```


Building a specific step for a box
```bash
invoke build.build-box -b <box_name> -p <provider> -s <build_number>
invoke build.build-box -b windows_10-amd64 -p virtualbox -s 4
```

Each building step's output can be found in the `output` folder

## Add boxes to vagrant

At the end of the building process, a `.box` file is created. This file can be added to vagrant with the following command

```bash
vagrant box add -f <box name> <path to box>
vagrant box add -f windows-2019-amd64-datacenter-virtualbox ./output/virtualbox/windows_2019-amd64/4/windows_2019-amd64-virtualbox.box
```

At this point you can now references the boxes in your Vagrantfile to bootstrap your desired environment. You can use the `lab-builder` project for already prepared environments.

## Contributing to the project

We need to help to improve this project and specially add other providers. You can find below information that is important for contributing to this project. You will need to understand how `packer` works if you want to add new Windows box images.

### Anatomy of this project

Here is a description of the structure of this project

```
build-boxes
├── env
│   ├── <windows box>
│   │   ├── 1-bootstrap.json	-- Packer conf for the 1st step
│   │   ├── 2-update.json		-- Packer conf for the 2nd step
│   │   ├── 3-provision.json	-- Packer conf for the 3rd step
│   │   ├── 4-finalize.json		-- Packer conf for the 4th step
│   │   └── Autounattend.xml	-- Autounattend conf file for bootstraping windows
├── logs						-- logging folder for the building process
├── Pipfile						-- Python requirements file. See pipenv documentation
├── Pipfile.lock				-- Lock of Python dependencies version
├── readme.md
├── res							-- Resource folder
│   ├── scripts					-- Provisioners scripts
│   └── vagrantfile				-- Vagrantfile templates
└── tasks						-- Source code of project's build tools
    ├── build.py
    ├── core
    │   ├── BoxBuilder.py
    │   ├── __init__.py
    │   └── utils.py
    └── __init__.py
```

### Building steps

The building process has been separated in 4 steps. The main reason for that is to ease the development of boxes and increase flexibility when updating boxes. The building process is done with `packer`.

You can find below further information about the building steps

#### Bootstrap

The bootstraping step aims to download the iso, create the virtual machine and apply a few fixes in case for the next steps

#### Update

This step applies all the windows updates for the box. The virtual machine is restarted multiple times if some patches require a restart

#### Provision

The provision step's goal is to:

* Add guest additions to the VM
* Make the last configurations on the OS
* Install all the tools

#### Finalize

The last step for generating the `.box` file will:

* Remove all the building artefacts from the OS
* Sysprep the windows box

### Box naming convention

If you are planing to use those boxes in the `lab-build` project, make sure you use the following naming convention to add the box to Vagrant (to match what was used in Vagrantfile of that project)

```
windows-<version>-<architecture>-<license>-<provider>
```

* version
  * 10
  * 2016
  * 2019
  * ...
* architecture
  * amd64
  * i386
  * ...
* license
  * pro
  * enterprise
  * ...
* provider
  * virtualbox
  * vmware
  * ...

## Resources

Windows packer main source of inspiration - https://github.com/rgl/windows-2016-vagrant

Windows packer best practices - https://hodgkins.io/best-practices-with-packer-and-windows  

Packer documentation - https://www.packer.io/docs/

## License

GNU General Public License v3.0 or later

See [COPYING](COPYING) to see the full text.

## Appendix

### Manual command execution for building boxes

Here are the commands executed by pyinvoke:

1st step

```bash
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=logs/windows_10-amd64-virtualbox.log \
		packer build -only=windows_10-amd64-virtualbox -on-error=abort env/windows_10-amd64/1-bootstrap.json
```

2nd step

```bash
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=logs/windows_10-amd64-virtualbox.log \
		packer build -on-error=abort env/windows_10-amd64/2-update.json
```

3rd step

```bash
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=logs/windows_10-amd64-virtualbox.log \
		packer build -on-error=abort env/windows_10-amd64/3-provision.json
```

4th step

```bash
CHECKPOINT_DISABLE=1 PACKER_LOG=1 PACKER_LOG_PATH=logs/windows_10-amd64-virtualbox.log \
		packer build -on-error=abort env/windows_10-amd64/4-finalize.json
```

### Troubleshoot WinRM connection issues from packer

Use `wmi-cli` to troubleshoot and understand what is going on when packer keeps trying to connect to your remote computer through WinRM.

1. Install go to build `wmi-cli`. You can follow this procedure to install go on Linux.
[Link](http://ask.xmodulo.com/install-go-language-linux.html)

1. Install godep (to build automatic go dependecies)
```bash
go get github.com/tools/godep
```
3. Download wmi-cli project and build
```bash
cd /opt/
sudo git clone https://github.com/masterzen/winrm-cli
cd winrm-cli
make
```
4. Usage
```bash
winrm -hostname 127.0.0.1 -port 4311 -username vagrant -password vagrant "whoami"
```
