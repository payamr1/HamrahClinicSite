<?php
/**
 * چیدمان اصلی.
 *
 * متغیرهای ورودی:
 *   $app, $page, $repo, $seo
 *   $content   — HTML بدنه
 *   $schema    — آرایه‌ی گره‌های اسکیما (اختیاری)
 *   $trail     — مسیر راهنما: ['برچسب' => '/path' یا null]
 */
/** @var Seo $seo */
/** @var Repository $repo */

$s        = $app['settings'];
$siteName = $s['site_name']  ?? 'همراه کلینیک';
$phone    = $s['phone']      ?? '۰۲۱۹۱۳۰۳۱۳۲';
$phoneRaw = $s['phone_raw']  ?? '02191303132';
$hours    = $s['hours']      ?? '';

$trail   = $trail   ?? [];
$schema  = $schema  ?? [];
$content = $content ?? '';

$nodes = array_merge([$seo->clinicSchema()], $schema);
if ($trail !== []) {
    $nodes[] = $seo->breadcrumbSchema(array_merge(['خانه' => '/'], $trail));
}
?><!doctype html>
<html dir="rtl" lang="fa-IR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">

<title><?= e($page['meta_title'] ?: $page['title']) ?></title>
<meta name="description" content="<?= e($page['meta_desc']) ?>">
<meta name="robots" content="<?= e($seo->robotsValue($page)) ?>">
<link rel="canonical" href="<?= e($seo->canonicalUrl($page)) ?>">

<meta property="og:type" content="<?= $page['type'] === 'post' ? 'article' : 'website' ?>">
<meta property="og:site_name" content="<?= e($siteName) ?>">
<meta property="og:locale" content="fa_IR">
<meta property="og:title" content="<?= e($page['meta_title'] ?: $page['title']) ?>">
<meta property="og:description" content="<?= e($page['meta_desc']) ?>">
<meta property="og:url" content="<?= e($seo->canonicalUrl($page)) ?>">
<?php if (!empty($page['og_image']) || !empty($page['hero_image'])): ?>
<meta property="og:image" content="https://<?= e($seo->canonicalHost()) ?>/assets/img/<?= e($page['og_image'] ?: ($page['hero_image'] ?: 'hero-reception.jpg')) ?>">
<?php endif; ?>
<meta name="twitter:card" content="summary_large_image">

<link rel="icon" href="/assets/img/brand/mark.jpg" type="image/jpeg">
<link rel="apple-touch-icon" href="/assets/img/brand/mark.jpg">

<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@300;400;500;600;700;800&display=swap">
<link rel="stylesheet" href="<?= asset('/assets/css/site.css') ?>">

<script type="application/ld+json"><?= $seo->graph($nodes) ?></script>
</head>
<body>

<a class="skip" href="#main">رفتن به محتوای اصلی</a>

<?php if ($seo->isStaging()): ?>
<div class="staging-flag" role="status">
  نسخه‌ی آزمایشی · این صفحات برای موتورهای جست‌وجو مسدود شده‌اند
</div>
<?php endif; ?>

<div class="topbar">
  <div class="in">
    <a class="tel" href="tel:<?= e($phoneRaw) ?>">
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z"/></svg>
      <b><?= e($phone) ?></b>
    </a>
    <span class="hours"><?= e($hours) ?></span>
  </div>
</div>

<header class="nav">
  <div class="in">
    <a class="brand" href="/" aria-label="<?= e($siteName) ?>">
      <img src="<?= e(img('brand/logo.png', 600)) ?>" alt="<?= e($siteName) ?>" width="196" height="75">
    </a>

    <nav class="menu" aria-label="منوی اصلی">
      <a href="/">خانه</a>
      <a href="<?= url('/service/') ?>">کلینیک‌ها</a>
      <a href="<?= url('/team/') ?>">پزشکان</a>
      <a href="<?= url('/about-us/') ?>">درباره ما</a>
      <a href="<?= url('/blog/') ?>">مقالات</a>
      <a href="<?= url('/contact-us/') ?>">تماس</a>
    </nav>

    <a class="b b-teal" href="<?= url('/contact-us/') ?>">رزرو نوبت</a>
  </div>
</header>

<?php if ($trail !== []): ?>
<nav class="crumb" aria-label="مسیر"><div class="in">
  <a href="/">خانه</a>
  <?php foreach ($trail as $label => $href): ?>
    <i aria-hidden="true">›</i>
    <?php if ($href !== null): ?><a href="<?= url($href) ?>"><?= e((string) $label) ?></a>
    <?php else: ?><span aria-current="page"><?= e((string) $label) ?></span><?php endif; ?>
  <?php endforeach; ?>
</div></nav>
<?php endif; ?>

<main id="main"><?= $content ?></main>

<footer class="site-foot">
  <div class="in">
    <div class="fgrid">
      <div>
        <?php // نشان سبز روی زمینه‌ی سرمه‌ای خوانا است؛ لوگوتایپ سرمه‌ای نه ?>
        <img class="fmark" src="<?= e(img('brand/mark.jpg', 400)) ?>" alt="" width="46" height="46">
        <b class="fname"><?= e($siteName) ?></b>
        <span class="fen">HAMRAH MEDICAL CLINIC</span>
        <p>کلینیک فوق تخصصی قلب و عروق و آنکولوژی در تجریش تهران، با رویکرد تیم درمان چندتخصصی.</p>
      </div>
      <div>
        <h4>کلینیک‌ها</h4>
        <ul>
          <?php foreach (array_slice($repo->clinics(), 0, 5) as $c): ?>
            <li><a href="<?= url($c['page_path'] ?? '/service/') ?>"><?= e($c['name']) ?></a></li>
          <?php endforeach; ?>
        </ul>
      </div>
      <div>
        <h4>تماس با ما</h4>
        <a class="ftel" href="tel:<?= e($phoneRaw) ?>"><?= e($phone) ?></a>
        <p><?= e($s['address'] ?? '') ?><br><?= e($hours) ?></p>
      </div>
    </div>
    <div class="fbot">© <?= fa((string) (1404 + (int) (date('n') >= 3))) ?> <?= e($siteName) ?> — تمامی حقوق محفوظ است.</div>
  </div>
</footer>

</body>
</html>
