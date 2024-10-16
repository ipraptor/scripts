#!/bin/sh

#==========================================
#  Autoconfig ssh security with dialog interface (checkboxes)
#  A.Palamarchuk (mrpalamarchuk93@yandex.ru) 16102024
#==========================================

export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin

dialog --yesno "Сгенерировать новый SSH ключ для текущего пользователя? | Generate new SSH key for the current user?" 7 60

if [ $? -eq 0 ]; then
    ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)"
    echo "Новый SSH ключ сгенерирован."
else
    echo "Генерация нового SSH ключа отменена."
fi
