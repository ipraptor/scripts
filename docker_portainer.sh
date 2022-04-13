#!/bin/sh
#=====================================
#         Portainer install
#=====================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin

wh=$(whoami)

if [[ $wh = "root" ]]
then
	systemctl start docker
	systemctl enable docker
	docker volume create portainer_data
	docker run -d -p 8000:8000 -p 9000:9000 --name=portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce
	firewall-cmd --add-port=9000/tcp --permanent
	echo "your port 9000"
else
	echo "Please run this script by root"
fi

