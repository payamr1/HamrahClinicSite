<?php
declare(strict_types=1);

/**
 * sitemap.xml و robots.txt
 *
 * از public/index.php صدا زده می‌شود و خودش خروجی را می‌فرستد.
 *
 * هر دو از دیتابیس ساخته می‌شوند. فایل ثابت یعنی هر بار که
 * خدمتی اضافه شود کسی باید یادش بماند sitemap را هم به‌روز کند —
 * و یادنرفتنش هیچ تضمینی ندارد.
 *
 * @var array  $app
 * @var string $path
 */

/** @var Repository $repo */
$repo = $app['repo'];
/** @var Seo $seo */
$seo = $app['seo'];

$host    = $seo->canonicalHost();
$staging = $seo->isStaging();

// ---------------------------------------------------------------
//  robots.txt
// ---------------------------------------------------------------
if ($path === '/robots.txt') {
    header('Content-Type: text/plain; charset=utf-8');
    header('X-Robots-Tag: noindex');

    if ($staging) {
        // نسخه‌ی آزمایشی: هیچ‌چیز خزیده نشود.
        // این چهارمین لایه‌ی محافظت است، کنار هدر X-Robots-Tag،
        // متای robots و canonicalِ دامنه‌ی اصلی.
        echo "User-agent: *\n";
        echo "Disallow: /\n";
        exit;
    }

    echo "User-agent: *\n";
    echo "Allow: /\n\n";

    // پنل و مسیرهای داخلی جایی در نتایج جست‌وجو ندارند
    echo "Disallow: /admin/\n";
    echo "Disallow: /_health.php\n";
    echo "Disallow: /assets/cache/\n\n";

    echo "Sitemap: https://$host/sitemap.xml\n";
    exit;
}

// ---------------------------------------------------------------
//  sitemap.xml
// ---------------------------------------------------------------
header('Content-Type: application/xml; charset=utf-8');
if ($staging) {
    header('X-Robots-Tag: noindex');
}

$rows = $repo->allPublishedPaths();

/**
 * اولویت و دوره‌ی به‌روزرسانی بر اساس نوع صفحه.
 *
 * این عددها دستور نیستند و گوگل سال‌هاست رسماً می‌گوید
 * priority را نادیده می‌گیرد؛ ولی برای موتورهای دیگر بی‌ضررند و
 * ساختار سایت را هم مستند می‌کنند.
 */
$weight = [
    'home'    => ['1.0', 'weekly'],
    'archive' => ['0.9', 'weekly'],
    'service' => ['0.8', 'monthly'],
    'doctor'  => ['0.7', 'monthly'],
    'gallery' => ['0.6', 'weekly'],
    'post'    => ['0.6', 'monthly'],
    'page'    => ['0.5', 'yearly'],
];

echo '<?xml version="1.0" encoding="UTF-8"?>' . "\n";
echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' . "\n";

foreach ($rows as $r) {
    [$prio, $freq] = $weight[$r['type']] ?? ['0.5', 'monthly'];

    // مسیر باید encode شود وگرنه آدرس فارسی XML نامعتبر می‌سازد
    $loc = 'https://' . $host . $seo->encodePath($r['path']);

    echo "  <url>\n";
    echo '    <loc>' . htmlspecialchars($loc, ENT_XML1 | ENT_QUOTES, 'UTF-8') . "</loc>\n";
    if (!empty($r['updated_at'])) {
        echo '    <lastmod>' . substr((string) $r['updated_at'], 0, 10) . "</lastmod>\n";
    }
    echo "    <changefreq>$freq</changefreq>\n";
    echo "    <priority>$prio</priority>\n";
    echo "  </url>\n";
}

echo '</urlset>' . "\n";
