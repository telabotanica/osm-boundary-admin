#!/bin/bash
# Encodage : UTF-8
# Compilation de Gdal 1.10 pour OpenSuse 13.1
# Copyright Jean-Pascal Milcent 2014
# Licence de ce script : GPL v3 & CeCILL v2
#
# Log des modifications de ce script :
# 2014-04-11 [Jean-Pascal MILCENT] : Creation du script Gdal v 1.10

# Load config
if [ -f ./../config.cfg ] ; then
	source ./../config.cfg
else
	echo "${Red}Veuillez paramétrer le script en renommant le fichier 'config.defaut.cfg' en 'config.cfg'.${RCol}"
	exit;
fi

echo -e "${Gre}Installation des paquets pour les librairies standards :${RCol}"
sudo zypper in libxml2-devel libexpat-devel sqlite3-devel pcre-devel

echo -e "${Gre}Création des dossiers pour la compilation${RCol}"
if [ ! -d ${GDAL_BUILD_DIR}/src ] ; then
	mkdir ${GDAL_BUILD_DIR}/src
fi
if [ ! -d ${GDAL_BUILD_DIR}/src/targz ] ; then
	mkdir ${GDAL_BUILD_DIR}/src/targz
fi

echo -e "${Gre}Récupération des sources à compiler :${RCol}"
cd ${GDAL_BUILD_DIR}/src/targz
if [ ! -f gdal-${GDAL_VERSION}.tar.gz ] ; then
	wget $GDAL_URL_DOWNLOAD -O gdal-${GDAL_VERSION}.tar.gz
fi

echo -e "${Gre}Décompression des sources :${RCol}"
# Effacement du dossier source pré-existant au cas ou
cd ${GDAL_BUILD_DIR}/src
rm -rf gdal-${GDAL_VERSION}
# Décompression des sources
tar xvfz targz/gdal-${GDAL_VERSION}.tar.gz
# Déplacement dans le dossier des sources pour compiler
cd gdal-${GDAL_VERSION}

echo -e "${Gre}Configuration, compilation et installation :${RCol}"
./configure \
	--prefix=${GDAL_INSTALL_DIR}/gdal-${GDAL_VERSION} \
	--with-threads \
	--with-ogr \
	--with-geos \
	--with-libz=internal \
	--with-libtiff=internal \
	--with-geotiff=internal \
	--with-png=internal \
	--with-jpeg=internal \
	--with-openjpeg \
	--with-curl \
	--with-hide-internal-symbols \
	--with-expat \
	--with-xml2 \
	--with-sqlite3=yes \
	--with-pcre \
	--with-mysql=$MYSQL_CONFIG \
	--with-fgdb=${GDAL_BUILD_DIR}/src/FileGDB_API

make
make install

echo -e "${Gre}Copie des lib FileGDB dans le dossier lib de gdal :${RCol}"
cd ${GDAL_INSTALL_DIR}/gdal-${GDAL_VERSION}/lib64
cp ${GDAL_BUILD_DIR}/src/FileGDB_API/lib/libFileGDBAPI.so ./libFileGDBAPI.so
cp ${GDAL_BUILD_DIR}/src/FileGDB_API/lib/libfgdbunixrtl.so ./libfgdbunixrtl.so

echo -e "${Gre}Ajout de liens symboliques vers les lib manquantes :${RCol}"
ln -s /usr/lib64/libstdc++.so.6 libstdc++.so.6

echo -e "${Gre}Gdal est en version :${RCol}"
cd ${GDAL_INSTALL_DIR}/gdal-${GDAL_VERSION}/bin/gdal-config --version