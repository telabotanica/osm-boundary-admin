#!/bin/bash
#
# - 2014-09-26 [Mathias CHOUET] : added configuration variables in script header
# - 2014-05-26 [Jean-Pascal MILCENT] : add sending email functionality
# - 2014-04-22 [Jean-Pascal Milcent] : created
#
ANSI2HTML_BIN="/usr/local/sbin/ansi2html.sh" # required - see http://www.pixelbeat.org/scripts/ansi2html.sh
USERNAME="username"
USERGROUP="usergroup"
OSM_HOME="/home/username"
SCRIPT_HOME="/home/username/bin/osm-boundary-admin"
LOGS_FOLDER="${OSM_HOME}/logs"
EMAIL_FROM="Root SERVERNAME <root@servername.net>"
EMAIL_TO="recipient@domain.org"
SENDMAIL_BIN="/usr/sbin/sendmail"

while true
do
    HEURE=$(date "+%H")
    # If we are at 2 AM, we launch the script
    if [ $HEURE -eq 2 ] ; then
        DATE=`date +"%F"`
        LOG="${LOGS_FOLDER}/${DATE}.log"
        LOG_HTML="${LOGS_FOLDER}/${DATE}_html.log"

        # Runs the OSM boundary admin update
        logger "osm::update : starting"
        cd ${OSM_HOME}
        echo "Lancement depuis le dossier : "`pwd` > $LOG
        sudo -u ${USERNAME} ${SCRIPT_HOME}/update-boundary-admin.sh >> $LOG 2>&1

        # Managing the logs
        cat $LOG | ${ANSI2HTML_BIN} > $LOG_HTML
        chown ${USERNAME}:${USERGROUP} ${LOGS_FOLDER}/*.log
     
        # Send an email with the log content
        (   
            echo "From: ${EMAIL_FROM}";
            echo "To: ${EMAIL_TO} ";
            echo "Subject: OSM log - $DATE";
     
            echo "MIME-Version: 1.0";
            echo "Content-Type: text/html; charset=UTF-8";
            echo "Content-Disposition: inline";
            cat $LOG_HTML
        ) | ${SENDMAIL_BIN} -t
        logger "osm::update : stopping"

        # Sleep 12h : to avoid the problem of changing the summer time and the delay of a few seconds added to each launch
        sleep 12h
    else
        # Attempt every hour until 2 AM
        logger "osm::update : attempt to launch at $HEURE o'clock"
        sleep 1h
    fi  
done
