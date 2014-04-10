#!/bin/bash
# Encodage : UTF-8
# Compilation de Gdal 1.10
# Copyright Jean-Pascal Milcent 2014
# Licence de ce script : GPL v3 & CeCILL v2
#
# Log des modifications de ce script :
# 2014-04-08 [Jean-Pascal MILCENT] : Creation du script Gdal v 1.10

# Indiquer la version de Gdal à compiler
VERSION="svn-trunk-2014.04.07"
URL_DOWNLOAD="http://www.gdal.org/daily/gdal-${VERSION}.tar.gz"
BUILD_DIR="${HOME}/bin"
INSTALL_DIR="${HOME}/Applications"
MYSQL_CONFIG="/opt/lampp/bin/mysql_config"

echo "Installation des paquets pour les librairies standards :"
sudo urpmi lib64xml2-devel lib64expat1-devel lib64sqlite3-devel lib64pcre-devel

echo "Récupération des sources à compiler :"
cd ${BUILD_DIR}/src/targz

if [ ! -f gdal-${VERSION}.tar.gz ] ; then
	wget $URL_DOWNLOAD -O gdal-${VERSION}.tar.gz
fi

echo "Décompression des sources :"
# Effacement du dossier source pré-existant au cas ou
cd ${BUILD_DIR}/src
rm -rf gdal-${VERSION}
# Décompression des sources
tar xvfz targz/gdal-${VERSION}.tar.gz
# Déplacement dans le dossier des sources pour compiler
cd gdal-${VERSION}

echo "Configuration, compilation et installation :"
./configure \
	--prefix=${INSTALL_DIR}/gdal-${VERSION} \
	--with-threads \
	--with-ogr \
	--with-geos \
	--with-libz=internal \
	--with-libtiff=internal \
	--with-geotiff=internal \
	--with-png=internal \
	--with-libtiff=internal \
	--with-geotiff=internal \
	--with-jpeg=internal \
	--with-hide-internal-symbols \
	--with-expat \
	--with-xml2 \
	--with-sqlite3=yes \
	--with-pcre \
	--with-mysql=$MYSQL_CONFIG \
	--with-fgdb=${INSTALL_DIR}/lib/FileGDB_API

make
make install

echo "Création des liens symboliques vers les lib FileGDB dans le dossier lib de gdal :"
cd ${INSTALL_DIR}/gdal-${VERSION}/lib
ln -s ${INSTALL_DIR}/lib/FileGDB_API/lib/libFileGDBAPI.so libFileGDBAPI.so
ln -s ${INSTALL_DIR}/lib/FileGDB_API/lib/libfgdbunixrtl.so libfgdbunixrtl.so

echo "Création des liens pour les autres lib manquante... :"
ln -s /usr/lib64/libpng15.so.15 libpng15.so.15
