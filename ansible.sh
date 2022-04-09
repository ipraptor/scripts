#===========================================================
#	INSTALL ANSIBLE TO CENTOS8 or ROCKY LINUX
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

# Install Python modules
	dnf install -y python3
	dnf install -y python3-pip
	python3 -m pip install -U pip
	python3 -m pip install -U setuptool
	cd /opt/
        dnf groupinstall -y 'development tools'
        dnf install -y bzip2-devel expat-devel gdbm-devel ncurses-devel openssl-devel readline-devel wget sqlite-devel tk-devel xz-devel zlib-devel libffi-devel

        VERSION=3.10.4
        wget https://www.python.org/ftp/python/${VERSION}/Python-${VERSION}.tgz

        tar -xf Python-${VERSION}.tgz
        cd ./Python-${VERSION}
	./configure --enable-optimizations
        make -j 4
        make altinstall
        python3.8 --version

# Install Ansible
	dnf install -y ansible
#	su -l $usern -c 'pip3 install ansible --user'
	ansible --version

else
	echo "Please run this script by root"
echo "\033[0m"
fi
