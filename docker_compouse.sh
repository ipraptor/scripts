#!/bin/sh
#=====================================
#         Docker Install
#=====================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin

wh=$(whoami)

if [[ $wh = "root" ]]
then
# Install Docker
	dnf -y install -y yum-utils device-mapper-persistent-data lvm2
	dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
	dnf list docker-ce
	dnf -y install docker-ce --nobest
	usermod -aG docker $(whoami)
	newgrp docker
	systemctl enable --now docker
	docker -v
	systemctl start docker
	systemctl enable docker
# Install Docker Compose
	curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
	docker-compose -v
# Setting firewall
	firewall-cmd --zone=public --add-masquerade --permanent
	firewall-cmd --reload
else
	echo "Please run this script by root"
fi

