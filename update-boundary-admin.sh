#!/bin/bash
# Encoding : UTF-8

TIME_START=$(date +%s)

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

# Load config
if [ -f config.cfg ] ; then
	source config.cfg
else
	echo "Veuillez paramétrer le script en renommant le fichier 'config.defaut.cfg' en 'config.cfg'."
	exit;
fi

# Check if the osm-c tools are needed
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

# Check if the ogr2ogr was built with support of Mysql and OSM
if [ ! -f ${DIR_BIN_OGR}/ogr2ogr ] &&	 [ ! -f ${DIR_BIN_OGR}/ogrinfo ] ; then
	echo "Please build a Gdal version with MySQL and OSM support."
else
	if [ $(${DIR_BIN_OGR}/ogrinfo --formats|grep "OSM\|MySQL" |wc -l) -ne 2 ] ; then
		echo "Votre version de Gdal ne supporte pas les formats OSM et MySQL. Veuillez la compiler avec ces formats."
	else
		echo "GDAL supports Mysql and OSM."
	fi
fi

# Processing for each area
AREAS=( "france" "africa" )
for AREA in "${AREAS[@]}"
do
	AREA_TIME_START=$(date +%s)

	# Maintain up to date the .osm.pbf file
	if [ ! -f "${DIR_OSM}/${AREA}.osm.pbf" ] ; then
		echo "Téléchargement du fichier PBF initial pour la zone «${AREA}»...";
		if [ $AREA == "france" ] ; then
			URL="http://download.geofabrik.de/europe/${AREA}-latest.osm.pbf"
		else
			URL="http://download.geofabrik.de/${AREA}-latest.osm.pbf"
		fi
		wget $URL -O "${DIR_OSM}/${AREA}.osm.pbf"
	else
		# Check if an update has been made less than 8 hours
		if [ `ageEnSeconde "${DIR_OSM}/${AREA}.osm.pbf"` -gt 28800 ] ; then
			echo "Mise à jour du fichier PBF pour la zone «${AREA}»...";
			mv ${DIR_OSM}/${AREA}.osm.pbf ${DIR_OSM}/${AREA}_old.osm.pbf
			${DIR_BIN}/osmupdate -B=${DIR_POLY}/${AREA}.poly -v -t=${DIR_TMP}/osmupdate/temp --day ${DIR_OSM}/${AREA}_old.osm.pbf ${DIR_OSM}/${AREA}.osm.pbf
			rm -f ${DIR_OSM}/${AREA}_old.osm.pbf
		else
			echo "${AREA}.osm.pbf up to date";
		fi
	fi

	# Create boundary extract
	if [ ! -f "${DIR_OSM}/${AREA}.osm.pbf" ] ; then
		echo "Impossible de trouver le fichier ${AREA}.osm.pbf.";
		exit 1;
	else
		if [ ! -f "${DIR_OSM}/${AREA}_boundary.osm.pbf" ] || [ `ageEnSeconde "${DIR_OSM}/${AREA}_boundary.osm.pbf"` -gt 28800 ] ; then
			echo "Filtrage des zones administratives en cours pour la zone «${AREA}»..."
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
			echo "${AREA}_boundary.osm.pbf up to date";
		fi
	fi

	# Import into Mysql
	if [ ! -f "${DIR_OSM}/${AREA}_boundary.osm.pbf" ] ; then
		echo "Impossible de trouver le fichier ${AREA}_boundary.osm.pbf.";
		exit 1;
	else
		echo "Importation dans MySQL en cours pour la zone «${AREA}»...";
		${DIR_BIN_OGR}/ogr2ogr \
			--config OSM_CONFIG_FILE $OSM_CONF_INI \
			--config MYSQL_UNIX_PORT $MYSQL_UNIX_PORT \
			-overwrite \
			-progress \
			-f "MySQL" MYSQL:${MYSQL_DATABASE},user=${MYSQL_USER},password=${MYSQL_PASSWORD},host=${MYSQL_HOST},port=${MYSQL_PORT} \
			-lco engine=MYISAM \
			-lco spatial_index=no \
			"${DIR_OSM}/${AREA}_boundary.osm.pbf" multipolygons points
	fi

	# Create and maintain the ref table
	echo -e "Mise à jour de la table de référence pour la zone «${AREA}»..."
	$BIN_PHP ./update-boundary-admin-ref.php ${AREA}

	# Show time elapsed
	AREA_TIME_END=$(date +%s)
	AREA_TIME_DIFF=$(($AREA_TIME_END - $AREA_TIME_START));
	echo "Time elapsed for area '${AREA}' : "`displaytime "$AREA_TIME_DIFF"`
done

# Show time elapsed
TIME_END=$(date +%s)
TIME_DIFF=$(($TIME_END - $TIME_START));
echo "Total time elapsed : "`displaytime "$TIME_DIFF"`