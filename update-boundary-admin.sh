#!/bin/bash
# Encoding : UTF-8

TIME_START=$(date +%s)
DIR_BASE=$(dirname $0)

# Functions
function ageEnSeconde {
	expr `date +%s` - `stat -c %Y $1`;
};

function displaytime {
	# Source : http://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	local S=$((T%60))
	[[ $D > 0 ]] && printf '%d days ' $D
	[[ $H > 0 ]] && printf '%d hours ' $H
	[[ $M > 0 ]] && printf '%d minutes ' $M
	[[ $D > 0 || $H > 0 || $M > 0 ]] && printf 'and '
	printf '%d seconds\n' $S
};

download() {
	local url=$1
	local file=$2
	wget --progress=dot $url -O $file 2>&1 | grep --line-buffered -E -o "100%|[1-9]0%|^[^%]+$" | uniq
	echo -e "${Gra}Download $2 : ${Gre}DONE${RCol}"
}

# Load config
if [ -f ${DIR_BASE}/config.cfg ] ; then
	source ${DIR_BASE}/config.cfg
	echo -e "${Gra}Config : ${Gre}OK${RCol}"
else
	echo -e "\e[1;31mPlease configure the script by renaming the file 'config.defaut.cfg' to 'config.cfg.\e[0m"
	exit;
fi

# Check if the osm-c tools are needed
if [ ! -f ${DIR_BIN}/osmupdate ] || [ ! -f ${DIR_BIN}/osmconvert ] || [ ! -f ${DIR_BIN}/osmfilter ] ; then
	echo -e "${Yel}Downloading and building the osm-c tools...${RCol}";
	cd $DIR_BIN
	if [ ! -f ${DIR_BIN}/osmupdate ] ; then
		wget -O - http://m.m.i24.cc/osmupdate.c | cc -x c - -o osmupdate
	fi
	if [ ! -f ${DIR_BIN}/osmconvert ] ; then
		wget -O - http://m.m.i24.cc/osmconvert.c | cc -x c - -lz -O3 -o osmconvert
	fi
	if [ ! -f ${DIR_BIN}/osmfilter ] ; then
		wget -O - http://m.m.i24.cc/osmfilter.c |cc -x c - -O3 -o osmfilter
	fi
	cd $DIR_BASE
else
	echo -e "${Gra}OSM C tools : ${Gre}OK${RCol}"
fi

# Check if the ogr2ogr was built with support of Mysql and OSM
if [ ! -f ${DIR_BIN_OGR}/ogr2ogr ] &&	 [ ! -f ${DIR_BIN_OGR}/ogrinfo ] ; then
	echo -e "${Red}Please build a Gdal version with MySQL and OSM support.${RCol}"
	exit;
else
	if [ $(${DIR_BIN_OGR}/ogrinfo --formats|grep "OSM\|MySQL" |wc -l) -ne 2 ] ; then
		echo -e "${Red}Your version of GDAL does not support OSM and MySQL formats.${RCol}"
		exit;
	else
		echo -e "${Gra}GDAL supports Mysql and OSM : ${Gre}OK${RCol}"
	fi
fi

# Processing for each area
for AREA in "${AREAS[@]}"
do
	AREA_TIME_START=$(date +%s)

	# Maintain up to date the .osm.pbf file
	if [ ! -f "${DIR_OSM}/${AREA}.osm.pbf" ] ; then
		echo -e "${Yel}Downloading initial PBF file for area «${AREA}»...${RCol}";
		if [ $AREA == "france" ] ; then
			URL="http://download.geofabrik.de/europe/${AREA}-latest.osm.pbf"
		else
			URL="http://download.geofabrik.de/${AREA}-latest.osm.pbf"
		fi
		download $URL "${DIR_OSM}/${AREA}.osm.pbf"
	else
		# Check if an update has been made less than 8 hours
		if [ `ageEnSeconde "${DIR_OSM}/${AREA}.osm.pbf"` -gt 28800 ] ; then
			echo -e "${Yel}Updating the PBF file for area «${AREA}»...${RCol}";
			mv ${DIR_OSM}/${AREA}.osm.pbf ${DIR_OSM}/${AREA}_old.osm.pbf
			${DIR_BIN}/osmupdate -B=${DIR_POLY}/${AREA}.poly -v -t=${DIR_TMP}/osmupdate/temp --day ${DIR_OSM}/${AREA}_old.osm.pbf ${DIR_OSM}/${AREA}.osm.pbf
			rm -f ${DIR_OSM}/${AREA}_old.osm.pbf
		else
			echo -e "${Gre}${AREA}.osm.pbf is up to date${RCol}";
		fi
	fi

	# Create boundary extract
	if [ ! -f "${DIR_OSM}/${AREA}.osm.pbf" ] ; then
		echo -e "${Red}Can not find the file : ${AREA}.osm.pbf.${RCol}";
		exit 1;
	else
		if [ ! -f "${DIR_OSM}/${AREA}_boundary.osm.pbf" ] || [ `ageEnSeconde "${DIR_OSM}/${AREA}_boundary.osm.pbf"` -gt 28800 ] ; then
			echo -e "${Yel}Filtering the administrative boundaries for area «${AREA}»...${RCol}"
			${DIR_BIN}/osmconvert ${DIR_OSM}/${AREA}.osm.pbf --out-o5m > ${DIR_OSM}/${AREA}.o5m
			${DIR_BIN}/osmfilter -t=${DIR_TMP}/osmfilter_tempfile \
				${DIR_OSM}/${AREA}.o5m \
				--keep= \
				--keep-nodes= \
				--keep-ways= \
				--keep-relations="type=boundary and boundary=administrative and admin_level=*" \
				--out-o5m | ${DIR_BIN}/osmconvert - --out-pbf -o=${DIR_OSM}/${AREA}_boundary.osm.pbf
			rm -f ${DIR_OSM}/${AREA}.o5m
		else
			echo -e "${Gre}${AREA}_boundary.osm.pbf is up to date${RCol}";
		fi
	fi

	# Import into Mysql
	if [ ! -f "${DIR_OSM}/${AREA}_boundary.osm.pbf" ] ; then
		echo -e "${Red}Can not find the file : ${AREA}_boundary.osm.pbf${RCol}";
		exit 1;
	else
		echo -e "${Yel}Importing into MySQL for area «${AREA}»...${RCol}";
		${DIR_BIN_OGR}/ogr2ogr \
			--config OSM_CONFIG_FILE $OSM_CONF_INI \
			--config MYSQL_UNIX_PORT $MYSQL_UNIX_PORT \
			-overwrite \
			-progress \
			-f "MySQL" MYSQL:${MYSQL_DATABASE},user=${MYSQL_USER},password=${MYSQL_PASSWORD},host=${MYSQL_HOST},port=${MYSQL_PORT} \
			-lco engine=MYISAM \
			-lco spatial_index=no \
			"${DIR_OSM}/${AREA}_boundary.osm.pbf" $LAYERS
	fi

	# Create and maintain the ref table
	echo -e "${Yel}Updating the reference table for area «${AREA}»...${RCol}"
	$BIN_PHP ./update-boundary-admin-ref.php ${AREA}

	# Show time elapsed
	AREA_TIME_END=$(date +%s)
	AREA_TIME_DIFF=$(($AREA_TIME_END - $AREA_TIME_START));
	echo -e "${Whi}Time elapsed for area '${AREA}' : "`displaytime "$AREA_TIME_DIFF"`"${RCol}"

done

# Show time elapsed
TIME_END=$(date +%s)
TIME_DIFF=$(($TIME_END - $TIME_START));
echo -e "${Whi}Total time elapsed : "`displaytime "$TIME_DIFF"`"${RCol}"