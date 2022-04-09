#!/bin/sh
#=====================================
#  Install zabbix agent linux centos
#=====================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin

wh=$(whoami)
if [[ $wh == "root" ]]
then
  rpm -ivh http://repo.zabbix.com/zabbix/3.2/rhel/7/x86_64/zabbix-release-3.2-1.el7.noarch.rpm
  dnf update -y
  yum install -y zabbix-agent
  systemctl start zabbix-agent
  systemctl enable zabbix-agent
  sed -i 's/Server=/Server=zabbix-server.local/' /etc/zabbix/zabbix_agentd.conf
  sed -i 's/ServerActive=/ServerActive=zabbix-server.local/' /etc/zabbix/zabbix_agentd.conf
  sed -i 's/Hostname=/Hostname=zagent.local/' /etc/zabbix/zabbix_agentd.conf
else
  echo "Please run this script by root"
fi