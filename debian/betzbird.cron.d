# ----pi crontab on 10thDez2026:
# this is for testing purposes, where 'crontab crontab4test.txt' switches off all crontab triggers
APPDIR=/usr/lib/betzbird
LOGDIR=/var/log/betzbird
# crontab variable substitution not working like in bash, therefore full path, not $APPDIR:
# the following could be only 'python3', as 'PATH=/home/pi/station3/birdvenv/bin:...' in bird-startup.service, see 'which python3' .
# PYTHON=/home/pi/birdvenv/bin/python3
PYTHON=/usr/bin/python3
# use /etc/systemd/system/bird-startup.service with systemctl instead
# @reboot bash $APPDIR/startup.sh >> /home/pi/station3/logs/cron_startup.log 2>&1
#
### min hour dayOfMonth month dayOfWeek(0=sunday)   command ###
# Calling with bash does not need file permissions like 'chmod +x *.sh'
# read sys params every 15 min:
*/14 * * * * bash $APPDIR/sysmon2.sh >> $LOGDIR/sysmon.log 2>&1 # >>/dev/null
# upload environment data every 15 min:
*/15 * * * * $PYTHON $APPDIR/dhtBird3.py >> $LOGDIR/dht_sun.log 2>&1
# shut down on sunset:
*/16 17-22 * * * $PYTHON $APPDIR/sunset3.py >> $LOGDIR/dht_sun.log 2>&1
# shut down station at 18:54 daily before disconnecting mains at 19:00 :
54 21 * * * bash $APPDIR/shutoff.sh eveningDown # has own log of it's stdout
# ----
