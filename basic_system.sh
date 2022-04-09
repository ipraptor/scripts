#!/bin/sh
#=====================================
#         Docker Install
#=====================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin

wh=$(whoami)

if [[ $wh = "root" ]]
then
	echo "Script started by root"
# start update system packet
	dnf update -y
	dnf install -y epel-release
	dnf update -y
	dnf clean all
# start install packet
	dnf install -y htop tree mc vim nano wget curl net-tools lsof bash-completion
# security
	sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config	
	systemctl restart sshd
# firewall
	systemctl enable firewalld
	systemctl start firewalld
	systemctl status firewalld|Active
	firewall-cmd --add-service=ssh	#open port for ssh
	firewall-cmd --add-service=ssh --permanent	
# see sysstem list
#	systemctl list-units	
else
	echo "Please run this script by root"
fi

