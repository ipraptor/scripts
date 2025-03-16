#!/bin/sh
#=====================================
#  Install zabbix agent linux centos
#=====================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin

wh=$(whoami)
if [[ $wh == "root" ]]
then
  wget https://repo.zabbix.com/zabbix/4.4/debian/pool/main/z/zabbix-release/zabbix-release_4.4-1+stretch_all.deb
  dpkg -i zabbix-release_4.4-1+buster_all.deb
  apt update
  apt install zabbix-agent
  systemctl start zabbix-agent
  systemctl enable zabbix-agent
  sed -i 's/Server=/Server=zabbix-server.local/' /etc/zabbix/zabbix_agentd.conf
  sed -i 's/ServerActive=/ServerActive=zabbix-server.local/' /etc/zabbix/zabbix_agentd.conf
  sed -i 's/Hostname=/Hostname=zagent.local/' /etc/zabbix/zabbix_agentd.conf
else
  echo "Please run this script by root"
fi
