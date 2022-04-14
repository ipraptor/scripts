#!/bin/sh
#===========================================================
#	TESTING ANSIBLE AFTER INSTALL TO CENTOS8 or ROCKY LINUX
#PalamarchukAA mrpalamarchuk93@gmail.com telegram:@ipraptor
#			31-03-2022-v1
#===========================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin
export PATH

wh=$(whoami)

if [[ $wh = "root" ]]
then
# What is no root user?
echo -e "\n\033[32m"
read -p "Write NO ROOT user login :" usern

# Testing Ansible
        sshstatus=$(sudo systemctl status sshd.service | grep running | wc -l)
        if [[ $sshdstatus = 0 ]]
        then
                echo "SSH not running"
                echo "Starting sshd.service"
                systemctl start sshd
                systemctl enable sshd
        else
                echo "SSH running"
                mkdir /etc/ansible
                rm -rf /etc/ansible/hosts
                touch /etc/ansible/hosts
                read -p "Please write IP REMOTE host for test ansible " -r varip
                read -p "Write Login REMOTE host :" loginrhost
                read -sp "Write Password remote host: " pasw && echo
                sudo echo "[web]" >> /etc/ansible/hosts
                sudo echo "$varip" >> /etc/ansible/hosts
                su -l $usern -c 'cd ~/'
                su -l $usern -c 'ssh-keygen'
                su -l $usern -c 'echo $pasw | ssh-copy-id $loginrhost@$varip'
                su -l $usern -c 'echo y | ansible -i /etc/ansible/hosts web -m ping'
        fi
else
	echo "Please run this script by ROOT"
echo "\033[0m"
fi
