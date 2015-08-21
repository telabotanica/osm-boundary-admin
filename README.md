osm-boundary-admin
==================

[Documentation en français](doc/README_FR.md)

## Goal
The goal of this shell script is to extract the boundaries of administrative zones provided by OpenStreetMap project,
so that they are integrated in a MySQL 5.6 database where a reference table stores the correponding polygons, as well
as their dates of addition, modification and removal.
The script maintains a PBF file up-to-date for each continent, in order to speed up daily processings.

## Dependencies
 - Gdal ogr2ogr with Mysql and OSM support
 - Mysql 5.6
 - PHP 5.3
 - OSM C tools : osmupdate, osmfilter, osmconvert (automatically downloaded and compiled by the script if necessary)

## Directory structure
 - **bin/** : contains OSM C scripts binaries : osmupdate, osmfilter, osmconvert
 - **logs/** : contains logs (one file a day)
 - **osm/** : contains downloaded OSM files plus script-updated versions
 - **poly/** : contains .poly files, that allow per-polygon filtering of OSM data (source : http://download.geofabrik.de/ )
 - **tmp/** : contains temporary files and folders created by OSM C scripts.
 - **utils/** : contains utility scripts : Gdal compilation, service, cron.
 - *config.defaut.cfg* : default configuration parameters for the script - to be renamed to "config.cfg".
 - *osmconf-boundary.ini* : ogr2ogr configuration parameters. Defines the tags that will be considered.
 - *update-boundary-admin-ref.php* : PHP script that maintains a reference table of administrative zones boundaries provided by OpenSteetMap.
 - *update-boundary-admin.sh* : main Bash script managing the download and update of pbf continent files from OSM, and the download of
a subset containing administrative zones boundaries only. Also manages the launch of script "update-boundary-admin-ref.php".

## Installation
Ensure that you have at least 50 GB free disk space, as duplication of some files may temporarily need a large amount of disk space.  
To feel at ease and foresee future file size growth, keep 100GB free space.

Clone Git repository here :
`git clone https://github.com/telabotanica/osm-boundary-admin.git`
If you don't have the Git program installed, doqnload a zip archive :
https://github.com/telabotanica/osm-boundary-admin/archive/master.zip

Check that you have the right versions of Gdal, Mysql and PHP.

If Gdal has no Mysql or OSM support, you may want to use one of the scripts in "utils" folder to compile it.
To do so :
 - copy/paste the _config.defaut.cfg_ file and rename it to _config.cfg_
 - adjust variables : MYSQL_CONFIG, GDAL_VERSION, GDAL_URL_DOWNLOAD, GDAL_BUILD_DIR, GDAL_INSTALL_DIR
 - if necessary, adapt the compilation script appropriately
 - launch the compilation script corresponding to your distribution : Mageia 3 (_mga3_), Opensuse 13.1 (_os13-1_) ou
Debian 6 (_deb6_)

## First use
Before firt use, start with :
 - copy/paste-ing the _config.defaut.cfg_  file and rename it to _config.cfg_ (if not already done)
 - adjust variables in the _config.cfg_ file to your needs
 - with a command line, place into the folder containing the script
 - launch the following command : `./update-boundary-admin.sh 2>&1 | tee $FILE_LOG`

A log file agregating the standard outputs will be created in the "logs" folder, while you will still see the info
in the terminal.

## Launch the script automatially
You might want to automate script launching using cron :
 - edit the crontab : `crontab -e`
 - add a new entry to launch the script, for example :
` 0 3 * * * /home/username/bin/update-boundary-admin.sh > /home/username/logs/`date +"%F"`.log 2>&1

You may also use _osm-service.sh_ and _osm-cron.sh_ scripts, located in _utils/_ folder.
They allow to launch the script with the rights of some given user, even if he has no shell by default.
_osm-service.sh_ script is a service allowing to launch the pseudo-cron script _osm-cron.sh_.  
To use those two :
 - copy _osm-cron.sh_ into _/usr/local/sbin_
 - edit the file
  - set the right username
  - set the right location for _update-boundary-admin.sh_ cript
  - adjust the time of day when to launch the script if needed
 - give execution rights to the file : `chmod +x osm-cron.sh`
 - copy _osm-service.sh_ into _/etc/init.d_
 - give execution rights to it : `chmod +x osm-service.sh`
 - now launch the service : `service osm-service.sh start`
 - to stop it: `service osm-service.sh stop`
 - to get service status : `service osm-service.sh status`

## Browse log files
Log files contain information about syntax highlighting. To see the colorized content, you might want to use : `cat my_file.log | more`
