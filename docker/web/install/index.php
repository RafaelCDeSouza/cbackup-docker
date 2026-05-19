<?php
/**
 * cBackup installer entry point.
 * Uses a minimal config — no DB-dependent bootstrap components.
 */

$ssp = session_save_path();
if (!is_writable($ssp)) {
    die("Session save path $ssp is not writable for PHP process");
}

defined('YII_DEBUG') or define('YII_DEBUG', true);
defined('YII_ENV')   or define('YII_ENV', 'dev');

require(__DIR__ . '/../../vendor/autoload.php');
require(__DIR__ . '/../../vendor/yiisoft/yii2/Yii.php');
require(__DIR__ . '/../../helpers/Y.php');

$db  = require(__DIR__ . '/../../config/db.php');
$ini = file_exists(__DIR__ . '/../../config/settings.ini')
    ? parse_ini_file(__DIR__ . '/../../config/settings.ini')
    : ['cookieValidationKey' => 'gdy82VYeW2-uPceUhWbGfej1bQA2OnYPswpoNLwsY', 'defaultTimeZone' => 'UTC'];

$config = [
    'name'         => 'cBackup',
    'id'           => 'cBackup',
    'basePath'     => dirname(dirname(__DIR__)),
    'defaultRoute' => 'install',
    'bootstrap'    => ['log'],
    'aliases'      => [
        '@bower' => '@vendor/bower-asset',
        '@npm'   => '@vendor/npm-asset',
    ],
    'components' => [
        'request' => [
            'cookieValidationKey' => $ini['cookieValidationKey'],
        ],
        'urlManager' => [
            'enablePrettyUrl'     => false,
            'enableStrictParsing' => false,
            'showScriptName'      => true,
        ],
        'cache' => [
            'class' => 'yii\caching\FileCache',
        ],
        'errorHandler' => [
            'errorAction' => 'install/index',
        ],
        'log' => [
            'traceLevel' => YII_DEBUG ? 3 : 0,
            'targets'    => [
                [
                    'class'   => 'yii\log\FileTarget',
                    'levels'  => ['error', 'warning'],
                    'logVars' => ['_GET', '_POST'],
                ],
            ],
        ],
        'i18n' => [
            'translations' => [
                '*' => ['class' => 'yii\i18n\PhpMessageSource'],
            ],
        ],
        'db' => $db,
    ],
];

(new yii\web\Application($config))->run();
