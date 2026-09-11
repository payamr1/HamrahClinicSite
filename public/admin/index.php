<?php
declare(strict_types=1);

/**
 * تنها فایل پنل که داخل ریشه‌ی وب است.
 *
 * منطق پنل در app/admin/ می‌ماند — بیرون از دسترس مرورگر — تا
 * حتی اگر روزی PHP از کار بیفتد، کد پنل به‌صورت متن خوانده نشود.
 */

$appRoot = dirname(__DIR__, 2) . '/hamrah-app';
if (!is_dir($appRoot)) {
    $appRoot = dirname(__DIR__, 2);      // حالت توسعه
}

$app = require $appRoot . '/app/bootstrap.php';
require $appRoot . '/app/admin/panel.php';
