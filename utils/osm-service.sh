#!/bin/sh

### BEGIN INIT INFO
# Provides:          osm-service.sh
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Should-Start:      $all
# Should-Stop:       $all
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start/stop OSM scripts
# Description:       Start/stop OSM scripts.
### END INIT INFO

case "$1" in

start)

echo "Start osm-cron :"
nohup /usr/local/sbin/osm-cron.sh 1>/dev/null 2>/dev/null &

;;

stop)

echo "Strop osm-cron"
PID=`ps -eaf | grep osm-cron.sh | grep -v grep | tr -s ' ' | cut -d' ' -f2 | head -n1`
kill -9 ${PID}

;;

status)

echo -n "osm-cron PID :"
PID=`ps -eaf | grep osm-cron.sh | grep -v grep | tr -s ' ' | cut -d' ' -f2 | head -n1`
echo ${PID}

;;


*)

echo "Usage:  {start|stop|status}"

exit 1

;;

esac