#!/bin/bash
# 
# tags: debian10,debian11,debian12,ubuntu2004,ubuntu2204,alma8,alma9,centos9,centos8,centos7,oracle8,oracle9,rocky8,rocky9

init() {
  set -x

  LOG_PIPE=/tmp/log.pipe.$$
  mkfifo ${LOG_PIPE}

  LOG_FILE=/root/zabbix.log
  touch ${LOG_FILE}
  chmod 600 ${LOG_FILE}
  tee < ${LOG_PIPE} ${LOG_FILE} &
  exec > ${LOG_PIPE}
  exec 2> ${LOG_PIPE}

  if [ -e '/etc/redhat-release' ]; then
    while ps uxaww | egrep '^yum|^dnf'; do echo "waiting..."; sleep 3; done

    yum -y update --exclude=qemu-guest-agent && yum install -y epel-release
    [ -e '/etc/yum.repos.d/epel.repo' ] && sed -i '/[epel]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo
  else
    while ps uxaww | egrep '^apt|^apt-get|^dpkg'; do echo "waiting..."; sleep 3; done

    export DEBIAN_FRONTEND='noninteractive'
	apt-mark hold qemu-guest-agent || :
	apt-get update
	apt-get -y upgrade
	apt-get -y install wget
	apt-mark unhold qemu-guest-agent || :
  fi

  OS_NAME=$(cat /etc/os-release    | egrep '^NAME'       | awk '{ sub(/.*NAME="/,"");sub(/".*/,"");print tolower($1)}')
  OS_VERSION=$(cat /etc/os-release | egrep '^VERSION_ID' | awk '{ sub(/.*VERSION_ID="/,"");sub(/".*/,"");print}')

  ZABBIX_VERSION="($ZABBIX_VERSION)"

  LINUX_PKGS='pwgen mariadb-server'
  ZABBIX_PKGS='zabbix-server-mysql zabbix-agent'
  REPO_URL='https://repo.zabbix.com/zabbix'
}

installZabbix() {
  if [ -e '/etc/redhat-release' ]; then
    yum install -y ${REPO_URL}
    yum clean all
    yum install -y ${LINUX_PKGS} ${ZABBIX_PKGS}

    if [ -e '/etc/yum.repos.d/zabbix.repo' ]; then
      [ -n "$(grep 'zabbix-frontend' /etc/yum.repos.d/zabbix.repo)" ] && yum --enablerepo=zabbix-frontend install -y zabbix-web-mysql-scl zabbix-nginx-conf-scl
    fi

    systemctl enable mariadb && systemctl restart mariadb
  else
    wget ${REPO_URL} -O /tmp/repo.deb
    dpkg -i /tmp/repo.deb
    apt-get update && apt-get install -y ${LINUX_PKGS} ${ZABBIX_PKGS} apache2*-

    [ -e '/tmp/repo.deb' ] && rm -f /tmp/repo.deb

    localectl set-locale en_US.UTF-8
  fi
}

configMySQL() {
  if [ ! -e '/root/.my.cnf' ]; then
    ROOT_PASS=$(pwgen -s 12 1)

    [ -e '/usr/bin/mysqladmin' ] && /usr/bin/mysqladmin -u root password ${ROOT_PASS}

    touch /root/.my.cnf
    chmod 600 /root/.my.cnf
    echo '[client]' > /root/.my.cnf
    echo "password=${ROOT_PASS}" >> /root/.my.cnf
  fi

  [ -e '/etc/zabbix/zabbix_server.conf' ] && ZABBIX_PASS=$(grep 'DBPassword=' /etc/zabbix/zabbix_server.conf | awk -F '=' '{ print $2 }')
  [ -z "${ZABBIX_PASS}" ]                 && ZABBIX_PASS=$(pwgen -s 12 1)

  if [ "${ZABBIX_VERSION}" = "5.0" ]; then
    echo "create database if not exists zabbix character set utf8 collate utf8_bin;" | mysql --defaults-file=/root/.my.cnf
  else
    echo "create database if not exists zabbix character set utf8mb4 collate utf8mb4_bin;" | mysql --defaults-file=/root/.my.cnf
  fi

  [ -z "$(echo "select * from mysql.user where User='zabbix';" | mysql --defaults-file=/root/.my.cnf -N)" ] && echo "create user zabbix@localhost identified by '${ZABBIX_PASS}';" | mysql --defaults-file=/root/.my.cnf
  [ -n "$(echo "show databases like 'zabbix';" | mysql --defaults-file=/root/.my.cnf -N)" ] && echo "grant all privileges on zabbix.* to zabbix@localhost;" | mysql --defaults-file=/root/.my.cnf

  echo 'set global log_bin_trust_function_creators = 1;' | mysql --defaults-file=/root/.my.cnf

  if [ -e '/usr/share/zabbix-sql-scripts/mysql/server.sql.gz' ]; then
    [ -z "$(echo 'show tables' | mysql --defaults-file=/root/.my.cnf -N zabbix)" ] && zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p${ZABBIX_PASS} zabbix
  fi

  if [ -e "$(find /usr/share/doc/ -name 'zabbix-server-mysql*')/create.sql.gz" ]; then
    [ -z "$(echo 'show tables' | mysql --defaults-file=/root/.my.cnf -N zabbix)" ] && zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uzabbix -p${ZABBIX_PASS} zabbix
  fi

  echo 'set global log_bin_trust_function_creators = 0;' | mysql --defaults-file=/root/.my.cnf 
}

configZabbix() {
  [ -n "${ZABBIX_PASS}" ] && sed -i "/DBPassword=/cDBPassword=${ZABBIX_PASS}" /etc/zabbix/zabbix_server.conf

  sed -i '/AllowUnsupportedDBVersions/cAllowUnsupportedDBVersions=1' /etc/zabbix/zabbix_server.conf
  sed -i '/DBHost/cDBHost=localhost' /etc/zabbix/zabbix_server.conf
  sed -i '/ProxyConfigFrequency=/cProxyConfigFrequency=60' /etc/zabbix/zabbix_server.conf

  if [ -e '/etc/nginx/conf.d/zabbix.conf' ]; then
    sed -i '/listen/s/#//' /etc/nginx/conf.d/zabbix.conf
    sed -i 's/listen\s*80;/listen 8080;/' /etc/nginx/conf.d/zabbix.conf
  fi

  if [ -e '/etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf' ]; then
    echo 'php_value[date.timezone] = UTC' >> /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
    sed -i 's/^listen.acl_users\s*=\s*apache\s*$/listen.acl_users = apache,nginx/' /etc/opt/rh/rh-php72/php-fpm.d/zabbix.conf
  fi

  if [ -e '/etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf' ]; then
    sed -i '/listen/s/#//' /etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf
    sed -i 's/listen\s*80;/listen 8080;/' /etc/opt/rh/rh-nginx116/nginx/conf.d/zabbix.conf
  fi

  [ -e '/etc/nginx/sites-enabled/default' ] && rm -f /etc/nginx/sites-enabled/default
  [ -e '/etc/zabbix/php-fpm.conf' ]         && echo 'php_value[date.timezone] = UTC' >> /etc/zabbix/php-fpm.conf
  [ -e '/etc/php-fpm.d/zabbix.conf' ]       && echo 'php_value[date.timezone] = UTC' >> /etc/php-fpm.d/zabbix.conf
  [ -n "${ZABBIX_PASS}" ]                   && cat << EOF > /etc/zabbix/web/zabbix.conf.php
<?php
\$DB['TYPE']                     = "MYSQL";
\$DB['SERVER']                   = "localhost";
\$DB['PORT']                     = "3306";
\$DB['DATABASE']                 = "zabbix";
\$DB['USER']                     = "zabbix";
\$DB['PASSWORD']                 = "${ZABBIX_PASS}";
\$DB['SCHEMA']                   = "";
\$DB['ENCRYPTION']               = false;
\$DB['KEY_FILE']                 = "";
\$DB['CERT_FILE']                = "";
\$DB['CA_FILE']                  = "";
\$DB['VERIFY_HOST']              = false;
\$DB['CIPHER_LIST']              = "";
\$DB['DOUBLE_IEEE754']           = true;
\$ZBX_SERVER                     = "localhost";
\$ZBX_SERVER_PORT                = "10051";
\$ZBX_SERVER_NAME                = "Zabbix";
\$IMAGE_FORMAT_DEFAULT           = IMAGE_FORMAT_PNG;
EOF

  if [ -e '/etc/zabbix/web/zabbix.conf.php' ]; then
    [ -e '/etc/redhat-release' ] && USER='apache' || USER='www-data'

    chmod 0600 /etc/zabbix/web/zabbix.conf.php
    chown ${USER} /etc/zabbix/web/zabbix.conf.php
  fi
}

main() {
  init

  case "${OS_NAME}${OS_VERSION}" in
    debian10)
      LINUX_PKGS="${LINUX_PKGS} locales"
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-frontend-php zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          echo 'Zabbix-server version 6.4 missing for Debian10'
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+debian10_all.deb"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+buster_all.deb"
          ;;
      esac
      ;;
    debian11)
      LINUX_PKGS="${LINUX_PKGS} locales"
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-frontend-php zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+debian11_all.deb"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+debian11_all.deb"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-2+debian11_all.deb"
          ;;
      esac
      ;;
    debian12)
      LINUX_PKGS="${LINUX_PKGS} locales"
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-frontend-php zabbix-sql-scripts zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+debian12_all.deb"
          ;;
        6.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-5+debian12_all.deb"
          ;;
        5.0)
          echo 'Zabbix-server version 5.0 missing for Debian12'
          ;;
        esac
      ;;
    ubuntu20.04)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-frontend-php zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+ubuntu20.04_all.deb"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+ubuntu20.04_all.deb"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+focal_all.deb"
          ;;
      esac
      ;;
    ubuntu22.04)
      LINUX_PKGS="${LINUX_PKGS} locales"
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-frontend-php zabbix-sql-scripts zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+ubuntu22.04_all.deb"
          ;;
        6.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+ubuntu22.04_all.deb"
          ;;
        5.0)
          echo 'Zabbix-server version 5.0 missing for Ubuntu22.04'
          ;;
      esac
      ;;
    almalinux8*)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          dnf -y module switch-to php:7.4
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-selinux-policy zabbix-sql-scripts"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-selinux-policy zabbix-sql-scripts"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el8.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
      esac
      ;;
    almalinux9*)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-selinux-policy zabbix-sql-scripts zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          echo 'Zabbix-server version 5.0 missing for AlmaLinux9'
          ;;
      esac
      ;;
    centos9)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-selinux-policy zabbix-sql-scripts zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          echo 'Zabbix-server version 5.0 missing for CentOS9'
          ;;
      esac
      ;;
    centos8)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts zabbix-selinux-policy"
          dnf -y module switch-to php:7.4
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts zabbix-selinux-policy"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el8.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
      esac
      ;;
    centos7)
      case "${ZABBIX_VERSION}" in
        6.4)
          echo 'Zabbix-server version 6.4 missing for CentOS7'
          ;;
        6.0)
          echo 'Zabbix-server version 6.0 missing for CentOS7'
          ;;
        5.0)
          yum -y install centos-release-scl
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/7/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el7.noarch.rpm"
          ;;
      esac
      ;;
    oracle8*)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts zabbix-selinux-policy"
          dnf -y module switch-to php:7.4
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts zabbix-selinux-policy"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el8.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
      esac
      ;;
    oracle9*)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-selinux-policy zabbix-sql-scripts zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          echo 'Zabbix-server version 5.0 missing for Oracle9'
          ;;
      esac
      ;;
    rocky8*)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts zabbix-selinux-policy"
          dnf -y module switch-to php:7.4
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-sql-scripts zabbix-selinux-policy"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el8.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
      esac
      ;;
    rocky9*)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-web-mysql zabbix-selinux-policy zabbix-sql-scripts zabbix-nginx-conf"

      case "${ZABBIX_VERSION}" in
        6.4)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          echo 'Zabbix-server version 5.0 missing for Rocky9'
          ;;
      esac
      ;;
  esac

  [ -n "$(echo ${REPO_URL} | egrep '\.deb$|\.rpm$')" ]       && installZabbix
  [ -n "$(ps aux | grep '^mysql')" ]                         && configMySQL
  [ -e '/etc/zabbix/zabbix_server.conf'   ]                  && configZabbix

  FPM_SERVICE=$(systemctl -l   | grep -i fpm   | awk '{ print $1 }')
  NGINX_SERVICE=$(systemctl -l | grep -i nginx | awk '{ print $1 }')

  [ -z "${FPM_SERVICE}" ]                                    && FPM_SERVICE="php-fpm"
  [ -e '/usr/lib/systemd/system/rh-php72-php-fpm.service' ]  && FPM_SERVICE="rh-php72-php-fpm"
  [ -z "${NGINX_SERVICE}" ]                                  && NGINX_SERVICE="nginx"
  [ -e '/usr/lib/systemd/system/rh-nginx116-nginx.service' ] && NGINX_SERVICE="rh-nginx116-nginx"
  [ -e '/usr/bin/firewall-cmd' ]                             && firewall-cmd --permanent --zone=public --add-port=8080/tcp && firewall-cmd --reload

  systemctl restart zabbix-server zabbix-agent ${NGINX_SERVICE} ${FPM_SERVICE}
  systemctl enable  zabbix-server zabbix-agent ${NGINX_SERVICE} ${FPM_SERVICE}
}

main

