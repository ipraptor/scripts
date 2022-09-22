###=========================================================
### Checking addresses by DNS and ICMP by a list from a file
### in script directory.
### By IPraptor i@ipraptor.ru 22-09-22/1
###=========================================================

# Переменные путей
$InputFile = "$PSScriptRoot\listIP.txt"
$OutputFile = "$PSScriptRoot\Out.txt"

# Создаём новый файл если его нет
if (-not (Test-Path $InputFile -PathType Leaf)) {
     Set-Content -Encoding UTF8 -Path $InputFile -Value ""
     Write-Verbose "Created 'FileThatDoesNotExist.txt'." -Verbose
}            

# Парсим файл
$addresses = get-content $InputFile
$reader = New-Object IO.StreamReader $InputFile

# Запускаем цикл с перебором
while($reader.ReadLine() -ne $null){ $TotalIPs++ }

    echo "===New testing===" >> $OutputFile

    #цикл построчного чтения строк из файла
    foreach($ip in $addresses) {
        
        # Прогресс бар
        # $i++
        # $percentdone = (($i / $TotalIPs) * 100)
        # $percentdonerounded = "{0:N0}" -f $percentdone
        # Write-Progress -Activity "Performing nslookups and ICMP" -CurrentOperation "Working on IP: $address (IP $i of $TotalIPs)" -Status "$percentdonerounded% complete" -PercentComplete $percentdone

        # Проверка доступности хоста по ICMP
        $ping = (test-Connection -ComputerName $ip -Count 2 -Quiet)
        # Проверка разрешения имения DNS из адреса
        $dns = ([System.Net.Dns]::Resolve($ip) | foreach {echo $_.HostName})

        # Проверяем доступен или недоступен хост и отправляем информацию в файл
        if ($ping -eq "True") {
            $string = "ping | $ip | OK"
        }
        else {
            $string = "ping | $ip | ERR"
        }
        echo $string >> $OutputFile

        # Проверяем разрешения IP адреса в имя и отправляем информацию в файл
        if($dns -eq $ip){
            $string = "dns | $ip | not resolved"
        }
        else {
            $string = "dns | $ip | $dns"
        }
        echo $string >> $OutputFile
    }

#Очистка пустых строк
@(gc $OutputFile) -match '\S'  | out-file $OutputFile
