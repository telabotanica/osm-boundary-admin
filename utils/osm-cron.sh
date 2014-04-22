#!/bin/bash
#
# - 2014-04-22 [Jean-Pascal Milcent] : created
#
while true
do
    HEURE=$(date "+%H")
    # If we are at 3AM, we launch the script
    if [ $HEURE -eq 3 ] ; then
        logger "osm::update : starting"
        sudo -u username /home/username/bin/update-boundary-admin.sh 2>&1 > $FILE_LOG
        logger "osm::update : stopping"
        # Sleep 22h : to avoid the problem of changing the summer time and the delay of a few seconds added to each launch
        sleep 22h
    else
        # Attempt every hour until 3 AM
        logger "osm::update : attempt to launch $HEURE hours"
        sleep 1h
    fi
done