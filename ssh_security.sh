#!/bin/bash
# Создаем резервную копию файла конфигурации sshd
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
# Изменяем порт SSH на 2222
sudo sed -i 's/#Port 22/Port 2222/g' /etc/ssh/sshd_config
# Перезапускаем службу sshd
sudo systemctl restart sshd
echo "SSH port change to TCP/2222"
