#!/bin/bash
# logfile=/var/log/betzbird/curl.log # "/dev/null"

if [[ -z $1 ]];then
    msg="noarg"
else
    msg=$1
fi

# here could be added notification methods, e.g. macrodroid, whatsapp, mqtt
