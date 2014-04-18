osm-boundary-admin
==================

== But
Le but de ce script shell est d'extraire les contours des zones administratives provenant du projet OpenStreetMap.
Ceci afin de les intégrer dans une base Mysql 5.6 où une table de référence stocke les polygones correspondant
et indique les dates d'ajout, de modification et de disparition.
Le script maintient donc à jour des fichiers PBF pour chaque continent afin d'accélérer les traitements journaliers.

== Dépendances
 - Gdal ogr2ogr avec support de Mysql et OSM
 - Mysql 5.6
 - PHP 5.3
 - OSM C tools : osmupdate, osmfilter, osmconvert

== Installation
TODO

