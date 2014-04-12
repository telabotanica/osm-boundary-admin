#!/bin/bash
# Encodage : UTF-8
# Compilation de Gdal 1.10 pour OpenSuse 13.1
# Copyright Jean-Pascal Milcent 2014
# Licence de ce script : GPL v3 & CeCILL v2
#
# Log des modifications de ce script :
# 2014-04-11 [Jean-Pascal MILCENT] : Creation du script Gdal v 1.10

# Indiquer la version de Gdal à compiler
VERSION="svn-trunk-2014.04.11"
URL_DOWNLOAD="http://www.gdal.org/daily/gdal-${VERSION}.tar.gz"
BUILD_DIR=`pwd`"/../tmp"
INSTALL_DIR=`pwd`"/../bin"
MYSQL_CONFIG="/opt/lampp/bin/mysql_config"

RCol='\e[0m';# Text Reset
Gre='\e[0;32m'; # Text Green

echo -e "${Gre}Installation des paquets pour les librairies standards :${RCol}"
sudo zypper in libxml2-devel libexpat-devel sqlite3-devel pcre-devel

echo -e "${Gre}Création des dossiers pour la compilation${RCol}"
if [ ! -d ${BUILD_DIR}/src ] ; then
	mkdir ${BUILD_DIR}/src
fi
if [ ! -d ${BUILD_DIR}/src/targz ] ; then
	mkdir ${BUILD_DIR}/src/targz
fi

echo -e "${Gre}Récupération des sources à compiler :${RCol}"
cd ${BUILD_DIR}/src/targz
if [ ! -f gdal-${VERSION}.tar.gz ] ; then
	wget $URL_DOWNLOAD -O gdal-${VERSION}.tar.gz
fi

echo -e "${Gre}Décompression des sources :${RCol}"
# Effacement du dossier source pré-existant au cas ou
cd ${BUILD_DIR}/src
rm -rf gdal-${VERSION}
# Décompression des sources
tar xvfz targz/gdal-${VERSION}.tar.gz
# Déplacement dans le dossier des sources pour compiler
cd gdal-${VERSION}

echo -e "${Gre}Configuration, compilation et installation :${RCol}"
./configure \
	--prefix=${INSTALL_DIR}/gdal-${VERSION} \
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
	--with-fgdb=${BUILD_DIR}/src/FileGDB_API

make
make install

echo -e "${Gre}Copie des lib FileGDB dans le dossier lib de gdal :${RCol}"
cd ${INSTALL_DIR}/gdal-${VERSION}/lib64
cp ${BUILD_DIR}/src/FileGDB_API/lib/libFileGDBAPI.so ./libFileGDBAPI.so
cp ${BUILD_DIR}/src/FileGDB_API/lib/libfgdbunixrtl.so ./libfgdbunixrtl.so

echo -e "${Gre}Ajout de liens symboliques vers les lib manquantes :${RCol}"
ln -s /usr/lib64/libstdc++.so.6 libstdc++.so.6