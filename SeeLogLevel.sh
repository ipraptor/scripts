#!/bin/sh
#==========================================
#  View all log levels in all applications
#==========================================
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin

journalctl -o json | sed 's/}//g' | awk -F'[:,]' 'BEGIN {
    map["0"]="PANIC"; map["1"]="ALERT"; map["2"]="CRITICAL"; map["3"]="ERROR";
    map["4"]="WARNING"; map["5"]="NOTICE"; map["6"]="INFO"; map["7"]="DEBUG"
}
{
    for (i=1; i<=NF; i++) {
        if ($i == "\"PRIORITY\"") {
            priority=$(i+1);
            gsub(/[^0-9]/, "", priority);
        }
        if ($i == "\"_COMM\"") {
            comm=$(i+1);
        }
    }
    if (!(comm in seen)) {
        print comm, map[priority];
        seen[comm]=1
    }
}'
