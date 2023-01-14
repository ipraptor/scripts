#!/bin/sh
#===========================================================
#CREATE CP
#PalamarchukAA mrpalamarchuk93@gmail.com i@ipraptor.ru
#14-01-2022-v1
#===========================================================

PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin/:/root/bin
export PATH
vDATE=$(date +%d_%m_%y)
mkdir -p ~/report/$vDATE/

### LOG INFORMATION ###
vLOG=~/report/$vDATE/log_$HOSTNAME.txt
touch $vLOG
less /var/log/messages | grep -i 'error' > $vLOG
less /var/log/messages* | grep -i 'error' >> $vLOG
ls -laht $FWDIR/log/ | grep -i 'elg' | head >> $vLOG
less $FWDIR/log/cpm.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/lpd.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/cplog_debug.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/fwm.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/cpca.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/postgres.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/dbsync.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/cpdiag.elg | grep -i 'error' | head >> $vLOG
echo  ====for SG only==== >> $vLOG
less $FWDIR/log/tp_events.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/tp_events.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/sxl_statd.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/fwd.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/ahclientd.elg | grep -i 'error' | head >> $vLOG
less $FWDIR/log/vpnd.elg | grep -i 'error' | head >> $vLOG

vCPINF=~/report/$vDATE/cpinfo_$HOSTNAME.txt
touch $vCPINF
clish -c "cpinfo -y all" > $vCPINF

vCPH=~/report/$vDATE/cphaprob_$HOSTNAME.txt
touch $vCPH
clish -c "cphaprob stat" > $vCPH

vSHCONF=~/report/$vDATE/showconfig_$HOSTNAME.txt
touch $vSHCONF
clish -c "show configuration" > $vSHCONF

vNETST=~/report/$vDATE/netstat_$HOSTNAME.txt
touch $vNETST
netstat -i > $vNETST

vHOTFX=~/report/$vDATE/hotfix_$HOSTNAME.txt
touch $vHOTFX
clish -c "cpinfo -y all" | grep hotfix > $vCPINF

vCONF=~/report/$vDATE/config_$HOSTNAME.txt
touch $vCONF
clish -c "show configuration" | grep ntp > $vCONF
clish -c "show configuration" | grep dns >> $vCONF
df -h >> $vCONF
clish -c "show clock" >> $vCONF

vTOP=~/report/$vDATE/top_$HOSTNAME.txt
touch $vTOP
top | head -n 20 > $vTOP

vFWACCEL=~/report/$vDATE/fwaccel_$HOSTNAME.txt
touch $vFWACCEL
clish -c "fwaccel stat" > $vFWACCEL

vCPLIC=~/report/$vDATE/cplic_$HOSTNAME.txt
touch $vCPLIC
clish -c "cplic print" > $vCPLIC
