<?php
// declare(encoding='UTF-8');
/**
 * Maintient une table de référence des contours de zones administrative issues d'OSM.
 *
 * Le driver OSM pour Gdal, ne supporte pas les polygones incomplets.
 * Lorsqu'il trouve un tel polygone, il n'apparait pas dans la table multipolygons.
 *
 * Pour palier à ce problème, ce script maintient à jour une table de référence des multipolygons "multipolygons_ref".
 * La date de dernière apparition dans la table multipolygons est indiquée.
 *
 *
 * @category	php 5.3
 * @author		Jean-Pascal MILCENT <jpm@tela-botanica.org>
 * @copyright	Copyright (c) 2014, Tela Botanica (accueil@tela-botanica.org)
 * @license		CeCILL v2 <http://www.cecill.info/licences/Licence_CeCILL_V2-fr.txt>
 * @license		GNU GPL <http://www.gnu.org/licenses/gpl.html>
 */
define('DS', DIRECTORY_SEPARATOR);
$config = parse_ini_file(__DIR__.DS.'config.cfg');
$configOsm = parse_ini_file(__DIR__.DS.'osmconf-boundary.ini', true);

// Get params
$laundering = $configOsm['attribute_name_laundering'] ? true : false;
$fields = array(
	'OGR_FID' => 'bigint(20) NOT NULL AUTO_INCREMENT',
	'SHAPE' => 'geometry NOT NULL'
);
if ($configOsm['multipolygons']['osm_id'] == 'yes') {
	$fields['osm_id'] = 'bigint(20) unsigned DEFAULT NULL';
	$fields['osm_way_id'] = 'bigint(20) unsigned DEFAULT NULL';
}
$configOsm['multipolygons']['osm_version'] == 'yes' ? $fields['osm_version'] = 'int(11) DEFAULT NULL' : '';
$configOsm['multipolygons']['osm_timestamp'] == 'yes' ? $fields['osm_timestamp'] = 'datetime DEFAULT NULL' : '';
$configOsm['multipolygons']['osm_uid'] == 'yes' ? $fields['osm_uid'] = 'int(11) DEFAULT NULL' : '';
$configOsm['multipolygons']['osm_user'] == 'yes' ? $fields['osm_user'] = 'text' : '';
$configOsm['multipolygons']['osm_user'] == 'yes' ? $fields['osm_changeset'] = 'text' : '';

$attributes = explode(',', $configOsm['multipolygons']['attributes']);
$chrToReplace = array(':', '-');
foreach ($attributes as $attr) {
	$fieldName = trim($laundering ? strtolower(str_replace($chrToReplace, '_', $attr)) : $attr);
	$fields[$fieldName] = 'text';
}
$fieldsInfos = '';
foreach ($fields as $fieldName => $fieldFormat) {
	$fieldsInfos += $fieldName.' '.$fieldFormat.",\n";
}
$queriesInit[] = "CREATE TABLE IF NOT EXISTS multipolygons_ref (
  $fieldsInfos
  UNIQUE KEY `OGR_FID` (`OGR_FID`),
  KEY `osm_id` (`osm_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;";
$queriesInit[] = "ALTER TABLE multipolygons CHANGE osm_id osm_id BIGINT NULL DEFAULT NULL ;";
$queriesInit[] = "ALTER TABLE multipolygons ADD INDEX osm_id ( osm_id ) COMMENT '';";

// Initialize the database connection
try {
	$connection = 'mysql:host='.$config['MYSQL_HOST'].';dbname='.$config['MYSQL_DATABASE'];
	$pdoOptions= array(PDO::MYSQL_ATTR_INIT_COMMAND => 'SET NAMES utf8');
	$db = new PDO($connection, $config['MYSQL_USER'], $config['MYSQL_PASSWORD'], $pdoOptions);
	$db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
}
catch(PDOException $e) {
	$msg = 'ERREUR PDO dans ' . $e->getFile() . ' L.' . $e->getLine() . ' : ' . $e->getMessage();
	die($msg);
}
// Update the database structure
try {
	foreach ($queriesInit as $query) {
		$db->exec($query);
	}
} catch(PDOException $e) {
	$msg = 'ERREUR PDO dans ' . $e->getFile() . ' L.' . $e->getLine() . ' : ' . $e->getMessage();
}

// New multipolygons
$query = 'INSERT INTO multipolygons_ref '.
	'SELECT *, NOW(), NULL, NULL '.
	'FROM multipolygons AS m '.
	'WHERE m.osm_id IS NOT NULL '.
	'AND m.osm_id NOT IN (SELECT osm_id FROM multipolygons_ref) ';
$rowsAddedNumber = $db->exec($query);
echo "Nombre de multi-polygones ajoutés : $rowsAddedNumber\n";

// Multipolygons vanished
$query = 'UPDATE multipolygons_ref '.
	'SET date_vanish = NOW() '.
	'WHERE osm_id NOT IN (SELECT osm_id FROM multipolygons WHERE osm_id IS NOT NULL) ';
$rowsVanishedNumber = $db->exec($query);
echo "Nombre de multi-polygones ayant disparu : $rowsVanishedNumber\n";

// Multipolygons updated
$fieldsToUpdate = array();
foreach ($fields as $fieldName => $fieldFormat) {
	$fieldsToUpdate[] = 'mr.'.$fieldName.' = m.'.$fieldName;
}
$setClause = implode(",\n", $fieldsToUpdate);
$query = 'UPDATE multipolygons_ref AS mr '.
	'	INNER JOIN multipolygons AS m ON (mr.osm_id = m.osm_id) '.
	"SET $setClause,".
	'	date_update = NOW() '.
	'WHERE mr.osm_version < m.osm_version '.
	'AND m.osm_id IS NOT NULL ';
$rowsUpdatedNumber = $db->exec($query);
echo "Nombre de multi-polygones modifiés : $rowsUpdatedNumber\n";