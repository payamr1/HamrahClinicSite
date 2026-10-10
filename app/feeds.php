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
    /*
     * روی staging هیچ robots.txtی سرو نمی‌شود — ۴۰۴.
     *
     * نسخه‌ی اول این فایل اینجا «Disallow: /» می‌گذاشت، که اشتباه
     * رایجی است و دقیقاً خلاف هدف عمل می‌کند:
     *
     *   اگر خزیدن را با robots.txt ببندیم، گوگل نمی‌تواند صفحه را
     *   بخواند — یعنی نمی‌تواند noindex را هم ببیند. در آن حالت
     *   اگر لینکی از بیرون به آدرسی برسد، گوگل همان آدرس را بدون
     *   توضیح در نتایج نشان می‌دهد و ما ابزاری برای بیرون آوردنش
     *   نداریم.
     *
     * برای صفحه‌ای که نباید ایندکس شود، ابزار درست noindex است نه
     * robots.txt؛ و noindex فقط وقتی کار می‌کند که اجازه‌ی خزیدن
     * داده شود. هر ۱۲۶ صفحه هم هدر X-Robots-Tag دارند و هم متای
     * robots، پس خزنده می‌خزد، noindex را می‌خواند و رد می‌شود.
     *
     * روز سوییچ، با production شدن env، robots.txt واقعی سرو
     * می‌شود — همان پایین.
     */
    if ($staging) {
        http_response_code(404);
        header('Content-Type: text/plain; charset=utf-8');
        header('X-Robots-Tag: noindex, nofollow');
        echo "robots.txt روی نسخه‌ی آزمایشی سرو نمی‌شود.\n";
        exit;
    }

    header('Content-Type: text/plain; charset=utf-8');
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
//
//  روی staging اصلاً وجود ندارد — نه نسخه‌ی noindex، نه نسخه‌ی
//  خالی. ۴۰۴ می‌دهد، انگار هیچ‌وقت ساخته نشده.
//
//  دلیلش ساده است: sitemap کارش دعوت کردن خزنده به صفحه‌هاست، و
//  نسخه‌ی آزمایشی نباید دعوت کند. هر چیز دیگری — حتی sitemapی که
//  خودش noindex است — یعنی فهرست کامل آدرس‌های ما جایی قابل
//  برداشت باشد پیش از آنکه آماده باشیم.
//
//  کد سر جایش می‌ماند و روزی که env بشود production خودبه‌خود
//  فعال می‌شود؛ کاری لازم نیست جز همان یک تغییر در config.
// ---------------------------------------------------------------
if ($staging) {
    http_response_code(404);
    header('Content-Type: text/plain; charset=utf-8');
    header('X-Robots-Tag: noindex, nofollow');
    echo "sitemap روی نسخه‌ی آزمایشی فعال نیست.\n";
    exit;
}

header('Content-Type: application/xml; charset=utf-8');

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
