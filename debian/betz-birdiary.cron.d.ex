#
# Regular cron jobs for the betz-birdiary package.
#
0 4	* * *	root	[ -x /usr/bin/betz-birdiary_maintenance ] && /usr/bin/betz-birdiary_maintenance
