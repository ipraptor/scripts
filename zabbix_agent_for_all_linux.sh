#!/bin/bash
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
    while ps uxaww | egrep '^yum|^dnf'; do echo 'waiting...'; sleep 3; done

    yum -y update
    [ -e '/etc/yum.repos.d/epel.repo' ] && sed -i '/[epel]/a excludepkgs=zabbix*' /etc/yum.repos.d/epel.repo
  else
    while ps uxaww | egrep '^apt|^apt-get|^dpkg'; do echo 'waiting...'; sleep 3; done

    export DEBIAN_FRONTEND='noninteractive'
    apt-get update && apt-get -y upgrade && apt-get -y install wget
  fi

  OS_NAME=$(cat /etc/os-release    | egrep '^NAME'       | awk '{ sub(/.*NAME="/,"");sub(/".*/,"");print tolower($1)}')
  OS_VERSION=$(cat /etc/os-release | egrep '^VERSION_ID' | awk '{ sub(/.*VERSION_ID="/,"");sub(/".*/,"");print}')

  ZABBIX_VERSION="($ZABBIX_VERSION)"
  ZABBIX_SERVER="($ZABBIX_SERVER)"

  ZABBIX_PKGS='zabbix-agent2'
  REPO_URL='https://repo.zabbix.com/zabbix'
}

installZabbix() {
  if [ -e '/etc/redhat-release' ]; then
    yum install -y ${REPO_URL}
    yum clean all
    yum install -y ${ZABBIX_PKGS}
  else
    wget ${REPO_URL} -O /tmp/repo.deb
    dpkg -i /tmp/repo.deb
    [ -e '/tmp/repo.deb' ] && rm -f /tmp/repo.deb

    apt-get update
    apt-get install -y ${ZABBIX_PKGS}
  fi
}

configZabbix() {
  [ -e '/etc/zabbix/zabbix_agentd.conf' ] && sed -i "s/^Server=127.0.0.1/Server=${ZABBIX_SERVER}/" /etc/zabbix/zabbix_agentd.conf
  [ -e '/etc/zabbix/zabbix_agent2.conf' ] && sed -i "s/^Server=127.0.0.1/Server=${ZABBIX_SERVER}/" /etc/zabbix/zabbix_agent2.conf

  [ -e '/etc/zabbix/zabbix_agentd.conf' ] && sed -i 's/^ServerActive=127.0.0.1/#ServerActive=127.0.0.1/' /etc/zabbix/zabbix_agentd.conf
  [ -e '/etc/zabbix/zabbix_agent2.conf' ] && sed -i 's/^ServerActive=127.0.0.1/#ServerActive=127.0.0.1/' /etc/zabbix/zabbix_agent2.conf
}

main() {
  init

  case "${OS_NAME}${OS_VERSION}" in
    debian12)
      ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"

      case "${ZABBIX_VERSION}" in
        6.4)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+debian12_all.deb"
          ;;
        6.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-5+debian12_all.deb"
          ;;
        5.0)
          echo 'Zabbix-proxy version 5.0 missing for Debian12'
          ;;
      esac
      ;;
    debian11)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+debian11_all.deb"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+debian11_all.deb"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-2+debian11_all.deb"
          ;;
      esac
      ;;
    debian10)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+debian10_all.deb"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+debian10_all.deb"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/debian/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+buster_all.deb"
          ;;
      esac
      ;;
    ubuntu22.04)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+ubuntu22.04_all.deb"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+ubuntu22.04_all.deb"
          ;;
        5.0)
          ZABBIX_PKGS="zabbix-agent"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-2+ubuntu22.04_all.deb"
          ;;
      esac
      ;;
    ubuntu20.04)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+ubuntu20.04_all.deb"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-4+ubuntu20.04_all.deb"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/ubuntu/pool/main/z/zabbix-release/zabbix-release_${ZABBIX_VERSION}-1+focal_all.deb"
          ;;
      esac
      ;;
    almalinux9*)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-3.el9.noarch.rpm"
          ;;
      esac
      ;;
    almalinux8*)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el8.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
      esac
      ;;
    centos9)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-3.el9.noarch.rpm"
          ;;
      esac
      ;;
    centos8)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
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
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/7/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el7.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/7/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el7.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/7/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el7.noarch.rpm"
          ;;
      esac
      ;;
    oracle9*)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-3.el9.noarch.rpm"
          ;;
      esac
      ;;
    oracle8*)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el8.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
      esac
      ;;
    rocky9*)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el9.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el9.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/9/x86_64/zabbix-release-${ZABBIX_VERSION}-3.el9.noarch.rpm"
          ;;
      esac
      ;;
    rocky8*)
      case "${ZABBIX_VERSION}" in
        6.4)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
        6.0)
          ZABBIX_PKGS="${ZABBIX_PKGS} zabbix-agent2-plugin-*"
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-4.el8.noarch.rpm"
          ;;
        5.0)
          REPO_URL="${REPO_URL}/${ZABBIX_VERSION}/rhel/8/x86_64/zabbix-release-${ZABBIX_VERSION}-1.el8.noarch.rpm"
          ;;
      esac
      ;;
  esac

  [ -n "$(echo ${REPO_URL} | egrep '\.deb$|\.rpm$')" ]   && installZabbix
  [ -n "$(find /etc/zabbix/ -name zabbix_agent?.conf)" ] && configZabbix
  [ -e '/usr/bin/firewall-cmd' ]                         && firewall-cmd --permanent --zone=public --add-port=10050/tcp && firewall-cmd --reload

  systemctl restart zabbix-agent2
  systemctl enable zabbix-agent2
}

main
