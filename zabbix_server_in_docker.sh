#!/bin/sh
#===========================================================
#     	INSTALL ZABBIX SERVER IN DOCKER CONTAINER
#PalamarchukAA mrpalamarchuk93@gmail.com telegram:@ipraptor
#			                14-04-2022-v1
#===========================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin
export PATH

wh=$(whoami)

if [[ $wh = "root" ]]
then
  statusdocker=systemctl status docker |grep active |awk '{print $2}'
  
  if [[ $statusdocker = "inactive" ]]
  then
    systemctl start docker
  else
    read -p "Write hostname for zabbix server : " -r zbxhostame
    read -p "Write hostname for datebase server : " -r dbhostame
    read -p "Write postgres username : " -r dbuser
    read -p "Write postgres password : " -s dbpswd
    read -p "Write name for datebase : " -r dbname
    docker network create --subnet 172.20.0.0/16 --ip-range 172.20.240.0/20 zabbix-net
    docker run --name postgres-server -t -e POSTGRES_USER=$dbuser -e POSTGRES_PASSWORD=$dbpswd -e POSTGRES_DB=$dbname --network=zabbix-net --restart unless-stopped -d postgres:latest
    docker run --name zabbix-snmptraps -t -v /zbx_instance/snmptraps:/var/lib/zabbix/snmptraps:rw -v /var/lib/zabbix/mibs:/usr/share/snmp/mibs:ro --network=zabbix-net -p 162:1162/udp --restart unless-stopped -d zabbix/zabbix-snmptraps:alpine-5.4-latest
    docker run --name zabbix-server-pgsql -t -e DB_SERVER_HOST=$dbhostname -e POSTGRES_USER=$dbuser -e POSTGRES_PASSWORD=$dbpswd -e POSTGRES_DB=$dbname -e ZBX_ENABLE_SNMP_TRAPS="true" --network=zabbix-net -p 10051:10051 --volumes-from zabbix-snmptraps --restart unless-stopped -d zabbix/zabbix-server-pgsql:alpine-5.4-latest
    docker run --name zabbix-web-nginx-pgsql -t -e ZBX_SERVER_HOST=$zbxhostname -e DB_SERVER_HOST=$dbhostname -e POSTGRES_USER=$dbuser -e POSTGRES_PASSWORD=$dbpswd -e POSTGRES_DB=$dbname --network=zabbix-net -p 443:8443 -p 80:8080 -v /etc/ssl/nginx:/etc/ssl/nginx:ro --restart unless-stopped -d zabbix/zabbix-web-nginx-pgsql:alpine-5.4-latest
  fi
  
else
	echo "Please run this script by root"
echo "\033[0m"
fi
