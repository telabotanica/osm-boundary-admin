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
 * @category   php 5.3
 * @author     Jean-Pascal MILCENT <jpm@tela-botanica.org>
 * @copyright  Copyright (c) 2014, Tela Botanica (accueil@tela-botanica.org)
 * @license    CeCILL v2 <http://www.cecill.info/licences/Licence_CeCILL_V2-fr.txt>
 * @license    GNU GPL <http://www.gnu.org/licenses/gpl.html>
 */

// Get params
$zone = $argv[1];
define('DS', DIRECTORY_SEPARATOR);
$config = parse_ini_file(__DIR__.DS.'config.cfg');
$configOsm = parse_ini_file(__DIR__.DS.'osmconf-boundary.ini', true);
$fields = getFields($configOsm['multipolygons'], (bool) $configOsm['attribute_name_laundering']);
$fieldsNames = array_keys($fields);

// Create queries
$queriesInit[] = createMultiPolygonsRefTable($fields);
$queriesInit[] = "ALTER TABLE multipolygons_ref ADD INDEX osm_version ( osm_version ) ;";
$queriesInit[] = "ALTER TABLE multipolygons_ref ADD INDEX date_add ( date_add ) ;";
$queriesInit[] = "ALTER TABLE multipolygons_ref ADD INDEX date_update ( date_update ) ;";
$queriesInit[] = "ALTER TABLE multipolygons_ref ADD INDEX date_vanish ( date_vanish ) ;";
$queriesInit[] = "ALTER TABLE multipolygons_ref ADD INDEX zone ( zone ) ;";
$queriesInit[] = "ALTER TABLE multipolygons CHANGE osm_id osm_id BIGINT NULL DEFAULT NULL ;";
$queriesInit[] = "ALTER TABLE multipolygons ADD INDEX osm_id ( osm_id ) COMMENT '';";
$queriesInit[] = "ALTER TABLE multipolygons ADD INDEX version ( version ) COMMENT '';";

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

// Multipolygons added
$fieldsToInsert = implode(', ', $fieldsNames);
$query = "INSERT INTO multipolygons_ref ($fieldsToInsert, date_add, date_update, date_vanish, zone) ".
	"SELECT $fieldsToInsert, NOW(), NULL, NULL, '$zone' ".
	'FROM multipolygons AS m '.
	'WHERE m.osm_id IS NOT NULL '.
	"AND m.osm_id NOT IN (SELECT osm_id FROM multipolygons_ref WHERE zone = '$zone' ) ";
$rowsAddedNumber = $db->exec($query);
echo "Nombre de multi-polygones ajoutés : $rowsAddedNumber\n";

// Multipolygons vanished
$query = 'UPDATE multipolygons_ref '.
	'SET date_vanish = NOW() '.
	"WHERE zone = '$zone' ".
	'AND osm_id NOT IN (SELECT osm_id FROM multipolygons WHERE osm_id IS NOT NULL ) ';
$rowsVanishedNumber = $db->exec($query);
echo "Nombre de multi-polygones ayant disparu : $rowsVanishedNumber\n";

// Multipolygons updated
$fieldsToUpdate = array();
foreach ($fieldsNames as $fieldName) {
	$fieldsToUpdate[] = 'mr.'.$fieldName.' = m.'.$fieldName;
}
$setClause = implode(",\n", $fieldsToUpdate);
$query = 'UPDATE multipolygons_ref AS mr '.
	'	INNER JOIN multipolygons AS m ON (mr.osm_id = m.osm_id) '.
	"SET $setClause,".
	'	date_update = NOW() '.
	"WHERE zone = '$zone' ".
	'AND mr.osm_version < m.osm_version '.
	'AND m.osm_id IS NOT NULL ';
$rowsUpdatedNumber = $db->exec($query);
echo "Nombre de multi-polygones modifiés : $rowsUpdatedNumber\n";

# Multipolygons centroid update
$query = 'UPDATE multipolygons_ref '.
	'SET shape_centroid = CENTROID(shape) '.
	'WHERE shape IS NOT NULL '.
	'AND (date_add > (NOW() - INTERVAL 8 HOUR) OR date_update > (NOW() - INTERVAL 8 HOUR) ) ';
$centroidUpdatedNumber = $db->exec($query);
echo "Nombre de centroïdes mis à jour : $centroidUpdatedNumber\n";

//+----------------------------------------------------------------------------------------------------------+
// FUNCTIONS

function getFields($config, $laundering) {
	$fields = array(
		'shape' => 'geometry NOT NULL'
	);
	$config['osm_id'] ? $fields['osm_id'] = 'bigint(20) unsigned DEFAULT NULL' : '';
	$config['osm_id'] ? $fields['osm_way_id'] = 'bigint(20) unsigned DEFAULT NULL' : '';
	$config['osm_version'] ? $fields['osm_version'] = 'int(11) unsigned DEFAULT NULL' : '';
	$config['osm_timestamp'] ? $fields['osm_timestamp'] = 'datetime DEFAULT NULL' : '';
	$config['osm_uid'] ? $fields['osm_uid'] = 'int(11) unsigned DEFAULT NULL' : '';
	$config['osm_user'] ? $fields['osm_user'] = 'text' : '';
	$config['osm_changeset'] ? $fields['osm_changeset'] = 'text' : '';

	$attributes = explode(',', $config['attributes']);
	$chrToReplace = array(':', '-');
	foreach ($attributes as $attr) {
		$fieldName = trim($laundering ? strtolower(str_replace($chrToReplace, '_', $attr)) : $attr);
		$fields[$fieldName] = 'text';
	}
	(!isset($config['other_tags']) || $config['other_tags']) ? $fields['other_tags'] = 'text' : '';
	return $fields;
}

function createMultiPolygonsRefTable($fields) {
	$fieldsInfos = '';
	foreach ($fields as $fieldName => $fieldFormat) {
		$fieldsInfos .= "\t  ".$fieldName.' '.$fieldFormat.",\n";
	}
	$query = "CREATE TABLE IF NOT EXISTS multipolygons_ref (
	  id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
	  shape_centroid point DEFAULT NULL,
	  $fieldsInfos
	  date_add DATETIME,
	  date_update DATETIME,
	  date_vanish DATETIME,
	  zone varchar(50),
	  UNIQUE KEY id (id),
	  KEY osm_id (osm_id)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;";
	return $query;
}