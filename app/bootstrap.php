<?php
declare(strict_types=1);

/**
 * راه‌اندازی برنامه.
 * از public/index.php صدا زده می‌شود و آرایه‌ی $app را برمی‌گرداند.
 */

mb_internal_encoding('UTF-8');
date_default_timezone_set('Asia/Tehran');

$appDir = __DIR__;                 // .../hamrah-app/app
$rootDir = dirname($appDir);       // .../hamrah-app

// ---- تنظیمات ---------------------------------------------------
$configFile = $rootDir . '/config.php';
if (!is_file($configFile)) {
    http_response_code(503);
    header('Content-Type: text/html; charset=utf-8');
    exit('<!doctype html><meta charset="utf-8"><h1>پیکربندی انجام نشده</h1>'
       . '<p>فایل <code>config.php</code> در پوشه‌ی برنامه وجود ندارد. '
       . 'نسخه‌ی <code>config.php.example</code> را کپی کنید و مقادیر دیتابیس را پر کنید.</p>');
}
$config = require $configFile;

// ---- نمایش خطا ------------------------------------------------
$debug = (bool) ($config['debug'] ?? false);
error_reporting(E_ALL);
ini_set('display_errors', $debug ? '1' : '0');
ini_set('log_errors', '1');

// ---- کلاس‌ها --------------------------------------------------
require $appDir . '/Database.php';
require $appDir . '/Router.php';
require $appDir . '/Seo.php';
require $appDir . '/Repository.php';
require $appDir . '/Images.php';
require $appDir . '/Media.php';
require $appDir . '/Sms.php';
require $appDir . '/helpers.php';

// ---- دیتابیس --------------------------------------------------
try {
    $db = new Database($config['db']);
} catch (\PDOException $e) {
    http_response_code(503);
    header('Content-Type: text/html; charset=utf-8');
    echo '<!doctype html><meta charset="utf-8"><h1>اتصال به دیتابیس برقرار نشد</h1>';
    if ($debug) {
        echo '<pre>' . htmlspecialchars($e->getMessage(), ENT_QUOTES, 'UTF-8') . '</pre>';
    }
    exit;
}

// ---- بهینه‌ساز تصویر ------------------------------------------
// ریشه‌ی وب همان پوشه‌ای است که index.php در آن اجرا می‌شود
$webRoot = $_SERVER['DOCUMENT_ROOT'] ?: dirname($appDir) . '/public';
$images  = new Images($webRoot);
img_init($images);

// ---- کتابخانه‌ی رسانه ------------------------------------------
// uploads کنار assets/img می‌نشیند تا Images بتواند از همان‌جا
// نسخه‌ی کوچک‌شده بسازد
$media = new Media($db, $webRoot . '/assets/uploads', '/assets/uploads', $images);
media_init($media);

// ---- تنظیمات عمومی از دیتابیس ---------------------------------
$settings = [];
try {
    foreach ($db->all('SELECT k, v FROM settings') as $row) {
        $settings[$row['k']] = $row['v'];
    }
} catch (\Throwable) {
    // جدول هنوز ساخته نشده — صفحه‌ی سلامت این را گزارش می‌دهد
}

// ---- پیامک -----------------------------------------------------
// بعد از خواندن settings، چون نام سایت در متن پیامکِ حالت ارسال
// ساده می‌آید
$sms = new Sms(($config['sms'] ?? []) + [
    'site_name' => $settings['site_name'] ?? 'همراه کلینیک',
    // در حالت debug، پیام خطای خام کاوه‌نگار هم نشان داده می‌شود
    'debug'     => $debug,
]);

return [
    'config'   => $config,
    'settings' => $settings,
    'db'       => $db,
    'router'   => new Router($db),
    'repo'     => new Repository($db),
    'seo'      => new Seo($config, $settings),
    'images'   => $images,
    'media'    => $media,
    'sms'      => $sms,
    'debug'    => $debug,
    'appDir'   => $appDir,
    'rootDir'  => $rootDir,
    'viewDir'  => $appDir . '/views',
];
