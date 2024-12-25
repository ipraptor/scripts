omv_version=$(dpkg -l openmediavault | awk '$2 == "openmediavault" { print substr($3,1,1) }')
file="openmediavault-omvextrasorg_latest_all${omv_version}.deb"
wget "https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/${file}"
dpkg -i "${file}" || apt-get -f install -y
