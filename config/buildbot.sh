#!/bin/bash
# set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export CDB_TAG=$1
if [ "${CDB_TAG}" = "" ]; then
    echo "Please specify a version tag to build! Use 'HEAD' for latest master."
    exit
fi

function runbuild {
	 # Start the VM and wait for it to come up.
	 echo "Starting build bot for $1, ssh port $3"
	 ssh buildbothost "nohup VBoxHeadless -s '$1' > /tmp/buildbot.out 2> /tmp/buildbot.err < /dev/null &"
	 echo "Waiting 20 seconds for VM to start up..."
	 sleep 20

	 # Setup the tunnel to the VM; a local port $3 gets mapped
	 # to a port $3 on the build host, which is forwarded by 
	 # virtualbox to the ssh port of the build bot.

	 echo 'Going to start build process...'
	 ssh -M -S my-ctrl-socket -fnNT -L $3:localhost:$3 buildbothost
	 
	 # Execute build commands on the VM, using the build script
	 # on the local machine (as the build bot may not have an
	 # up-to-date build script yet).

	 ssh -tt -p $3 buildbot CDB_TAG=${CDB_TAG} "bash -s" -- < ${DIR}/buildpkg.sh
	 
	 # Copy the generated package to the web server.

	 echo 'Going to copy the package to the web server'
	 scp -P $3 'buildbot:cadabra2/build/cadabra*' .
	 scp cadabra*$2 "cadabra_web:/var/www/cadabra2/packages/$4"
	 rm -f cadabra*$2
	 
	 # Take down the VM gracefully.

	 echo 'Shutting down build bot...'
	 ssh -tt -p $3 buildbot 'sudo shutdown now'
	 
	 # Close the tunnel to the VM.

	 ssh -S my-ctrl-socket -O exit buildbot
}

# To setup a new build bot, install a basic system, install
# openssh-server, and setup a tunnel from a local port (to be given
# below) to the ssh port on the build bot. Put
#
#   kasper ALL=(ALL) NOPASSWD: ALL
#
# at the bottom of the file edited with 'sudo visudo' (to avoid
# scripts asking for passwords). Copy the ~/.ssh/buildbots_rsa.pub to
# ~/.ssh/authorized_keys on the build VM.
#
# For RPM-based systems, install rpm-build.
#
# Then install 'git', install all cadabra2 dependencies, and clone the
# github repo into ~/cadabra2.

# Parameters: VM name, package type, local ssh port, folder name on web server.

runbuild "Ubuntu_20.04"        ".deb" 7030 ubuntu2004
runbuild "Ubuntu_18.04"        ".deb" 7017 ubuntu1804
runbuild "Fedora_28"           ".rpm" 7020 fedora28
runbuild "Fedora_29"           ".rpm" 7025 fedora29               
runbuild "Fedora_32"            ".rpm" 7027 fedora32
runbuild "Mint_19"             ".deb" 7022 mint19
runbuild "Mint_20"             ".deb" 7026 mint20
runbuild "OpenSUSE_15"         ".rpm" 7024 opensuse150
runbuild "OpenSUSE_Tumbleweed" ".rpm" 7023 opensusetw
# runbuild "CentOS_7"            ".rpm" 7004 centos7      cmake/packaging clash
# runbuild "Scientific_Linux_74" ".rpm" 7013 scientific7x
runbuild "Debian_921"          ".deb" 7014 debian9
runbuild "Debian_Buster"       ".deb" 7021 debian10

# Outdated versions:
# runbuild "Mint_18" ".deb" 7002 mint18                   ERROR
# runbuild "Fedora_27" ".rpm" 7015 fedora27               ERROR
# runbuild "Fedora_24_build" ".rpm" 7001 fedora24
# runbuild "Fedora_26" ".rpm" 7011 fedora26
# runbuild "Ubuntu_14.04_build" ".deb" 7005 ubuntu1404
# runbuild "Ubuntu_16.04_build" ".deb" 7000 ubuntu1604
# runbuild "Ubuntu_17.10" ".deb" 7012 ubuntu1710
# runbuild "Debian86"            ".deb" 7006 debian86     ERROR
# runbuild "OpenSUSE_Leap" ".rpm" 7003 opensuse421
