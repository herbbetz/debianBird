#!/bin/bash
appdir="/usr/lib/betzbird"
logfile=/var/log/betzbird/startup.log # "/dev/null"

if [[ -z $1 ]];then
    msg="noarg"
else
    msg=$1
fi

bash "$appdir/messages.sh" "$msg"
echo "$(date) shutdown by ""$msg" >> $logfile
sync
shutdown -h now