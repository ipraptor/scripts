###########################################
# by PalamarchukAA 160322-01
# Auto-installation of zabbix agent, if the agent is already installed, we backup the old one and replace it with a new one.
###########################################

#присваиваем путь к директории для резервной копии
$backupdir = "A:\scripts\backup"

#присваиваем путь к агенту
$zabbixmsi = "A:\zabbix_agent-6.0.3-windows-amd64-openssl.msi"

#пусть к логам
$log = "A:\zabbix.log"

#проверяем существует ли директория, если нет создаём
[system.io.directory]::CreateDirectory($backupdir)

#Фиксируем количество ошибок перед запуском установки
$errorcount = $Error.Count

#Проверяем есть ли ключи забикса в реестре
$zabinfo = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Zabbix SIA\Zabbix Agent (64-bit)").ProductVersion

#Проверяем количество ошибок если изменилось запускаем процесс установки
if ($Error.Count -ne $errorcount){
    write-host "Install Zabbix Agent..."
    msiexec.exe /i $zabbixmsi /quiet /passive /qn /L*V $log SERVER=192.168.1.126 TLSCONNECT=psk TLSACCEPT=psk TLSPSKIDENTITY=MyPSKID TLSPSKVALUE=1f87b595725ac58dd977beef14b97461a7c1045b9a1c963065002c5473194952
}
else { #делаем резервную копию установленного агента и затем переустанавливаем его
    write-host "Detected installed Zabbix agent, created backup and reinstall zabbix agent"
    $nowdate = Get-Date -Format ddMMy-HHmmss #Получаем текущую дату
    $backuppath = $backupdir + "\" + $nowdate
    [system.io.directory]::CreateDirectory($backuppath) #создаём директорию для сохранения бэкапа
    Copy-Item -Path "c:/Program Files/zabbix agent/*" -Destination $backuppath -Recurse
    write-host "Complete!"
}
