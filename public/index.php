<?php
declare(strict_types=1);

/**
 * همراه کلینیک — نقطه‌ی ورود.
 *
 * پوشه‌ی برنامه بیرون از ریشه‌ی وب است تا کد و config از طریق
 * مرورگر قابل خواندن نباشند:
 *
 *   ~/new.hamrahclinic.ir/   ← همین پوشه (ریشه‌ی وب)
 *   ~/hamrah-app/            ← app/ و db/ و config.php
 */

$appRoot = dirname(__DIR__) . '/hamrah-app';
if (!is_dir($appRoot)) {
    // حالت توسعه: مخزن به‌صورت کامل در یک پوشه قرار دارد
    $appRoot = dirname(__DIR__);
}

$app = require $appRoot . '/app/bootstrap.php';

/** @var Router $router */
$router = $app['router'];
/** @var Repository $repo */
$repo = $app['repo'];
/** @var Seo $seo */
$seo = $app['seo'];

$path   = Router::requestPath();
$result = $router->resolve($path);

// ---- ریدایرکت -------------------------------------------------
if ($result['action'] === 'redirect') {
    header('Location: ' . url($result['to']), true, $result['code'] ?? 301);
    exit;
}

// ---- هدرهای مشترک ---------------------------------------------
header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');

// ---- ۴۰۴ ------------------------------------------------------
if ($result['action'] === 'notfound') {
    http_response_code(404);
    header('X-Robots-Tag: noindex');
    $page = [
        'path'       => $path,
        'type'       => 'notfound',
        'title'      => 'صفحه پیدا نشد',
        'meta_title' => 'صفحه پیدا نشد | همراه کلینیک',
        'meta_desc'  => 'آدرسی که دنبالش بودید وجود ندارد یا جابه‌جا شده است.',
        'noindex'    => 1,
    ];
    echo view($app['viewDir'], 'notfound', compact('app', 'page', 'repo', 'seo'));
    exit;
}

// ---- صفحه ------------------------------------------------------
$page = $result['page'];

if ($seo->shouldNoindex($page)) {
    header('X-Robots-Tag: noindex, nofollow');
}

// انتخاب قالب بر اساس نوع صفحه
$template = match ($page['type']) {
    'home'    => 'home',
    'service' => 'service',
    'doctor'  => 'doctor',
    'post'    => 'article',
    'archive' => 'archive/' . ($page['slug'] ?: 'service'),
    default   => 'page',
};

if (!is_file($app['viewDir'] . '/' . $template . '.php')) {
    $template = 'page';
}

try {
    echo view($app['viewDir'], $template, compact('app', 'page', 'repo', 'seo'));
} catch (\Throwable $e) {
    http_response_code(500);
    if ($app['debug']) {
        echo '<pre dir="ltr">' . e($e->getMessage()) . "\n\n" . e($e->getTraceAsString()) . '</pre>';
    } else {
        error_log('[hamrah] ' . $e->getMessage());
        echo '<!doctype html><meta charset="utf-8"><h1>خطای موقت</h1><p>لطفاً بعداً تلاش کنید.</p>';
    }
}
