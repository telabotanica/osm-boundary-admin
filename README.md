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
 - OSM C tools : osmupdate, osmfilter, osmconvert (téléchargés et compilés automatiquement par le script si nécessaire)

== Organisation des dossiers
 - bin/ : contient les binaires des scripts C d'OSM : osmupdate, osmfilter, osmconvert
 - logs/ : contient les fichiers de logs du script (un par jour)
 - osm/ : contient les fichier d'OSM téléchargés et mis à jour par le script.
 - poly/ : contient les fichiers .poly permettant de filtrer par polygone les données d'OSM (source : http://download.geofabrik.de/ )
 - tmp/ : contient les fichiers et dossiers temporaires créés par les scripts C d'OSM.
 - utils/ : contient des scripts utilitaires : compilation de Gdal, service, cron.
 - config.defaut.cfg : paramètres de configuration du script. A renommer en "config.cfg".
 - osmconf-boundary.ini : paramètres de configuration pour ogr2ogr. Définit les tags à prendre en compte.
 - update-boundary-admin-ref.php : script PHP maintenant une table de référence des contours de zones administratives issues d'OpenSteetMap.
 - update-boundary-admin.sh : script Shell Bash principal assurant le téléchargement et la mise à jour de fichiers pbf
par continent des données d'OSM et d'un sous ensemble contenant seulement les contours des zones administratives. Il s'assure aussi du lancement du script "update-boundary-admin-ref.php".

== Installation
Assurez vous d'avoir au moins 50 Go d'espace disque, la duplication de certains fichiers peut consommer une quantité non négligeable d'espace disque de façon temporaire.
Pour être à l'aise et anticiper l'augmentation en taille des fichiers, prévoir 100Go d'espace disque.

Vous pouvez cloner le dépôt Git :
git clone https://github.com/telabotanica/osm-boundary-admin.git
Si vous ne disposez pas de Git, vous pouvez télécharger une archive zip :
https://github.com/telabotanica/osm-boundary-admin/archive/master.zip

Vérifiez que vous disposez bien des bonnes version de Gdal, Mysql et PHP.

Si Gdal, n'a pas le support de Mysql et OSM, vous pouvez utiliser un des scripts présents dans le dossier "utils"
pour le compiler.
Pour ce faire, copier/coller le fichier "config.defaut.cfg" et renomer le "config.cfg".
Ajuster les variables : MYSQL_CONFIG, GDAL_VERSION, GDAL_URL_DOWNLOAD, GDAL_BUILD_DIR, GDAL_INSTALL_DIR.
Si nécessaire, adapter le script de compilation à votre convenance.
Lancer le script de compilation correspondant à votre distribution : Mageia 3 (mga3), Opensuse 13.1 (os13-1) ou Debian 6 (deb6).

== Première Utilisation
Pour la première utilisation, commencez par :
 - copier/coller le fichier "config.defaut.cfg" et renomer le "config.cfg" (si ce n'est pas déjà fait)
 - ajuster les variables du fichier "config.cfg" en fonction de vos besoins
 - lancer la commande suivante : ./update-boundary-admin.sh 2>&1 | tee $FILE_LOG
Un fichier de log contenant le contenu des sorties standard sera créé dans le dossier "logs" mais vous pourrez toujours visualiser les infos dans la console.

== Automatisation du lancement du script
Vous pouvez automatiser le lancement de script via un cron, pour cela :
 - editer le cron : crontab -e
 - Ajouter une entrée pour le lancement du script, par exemple : 0 3 * * * /home/username/bin/update-boundary-admin.sh 2>&1 > $FILE_LOG

Vous pouvez aussi utiliser les scripts osm-service.sh et osm-cron.sh présents dans le dossier "utils".
Ils permettent de lancer le script avec les droits d'un utilisateur donné même si celui ci n'a pas d'accès à un shell.
Le script osm-service.sh est un service qui permet de lancer le script servant de cron "osm-cron.sh".
Pour les utiliser :
 - copier le fichier "osm-cron.sh" dans "/usr/local/sbin"
 - modifier le contenu du fichier
  - indiquer le bon utilisateur
  - indiquer le bon emplacement du script "update-boundary-admin.sh"
  - modifier l'heure du lancement du script si nécessaire
 - donner des droits d'execution au fichier : chmod +x osm-cron.sh
 - copier le fichier "osm-service.sh" dans "/etc/init.d"
 - donner des droits d'execution au fichier : chmod +x osm-service.sh
 - vous pouvez lancer le service : service osm-service.sh start
 - pour l'arrêter utiliser: service osm-service.sh stop
 - pour connaître le statut du service : service osm-service.sh status