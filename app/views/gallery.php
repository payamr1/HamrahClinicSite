<?php
/**
 * گالری عمومی کلینیک.
 *
 * آدرس ‎/گالری/ از قبل ایندکس شده بود و صفحه‌اش خالی مانده بود؛
 * همان آدرس نگه داشته می‌شود.
 *
 * فیلترها با query string کار می‌کنند نه جاوااسکریپت، پس هر نما
 * آدرس خودش را دارد و قابل اشتراک‌گذاری است. canonical همه‌ی نماها
 * به آدرس تمیز گالری اشاره می‌کند تا محتوای تکراری نسازند.
 *
 * @var Repository $repo
 * @var Seo $seo
 */
$mediaLib = $app['media'];

$kind = in_array($_GET['kind'] ?? '', ['image', 'video'], true) ? $_GET['kind'] : 'all';
$fType = in_array($_GET['t'] ?? '', ['doctor', 'clinic', 'page'], true) ? $_GET['t'] : null;
$fId   = $fType !== null ? (int) ($_GET['i'] ?? 0) : null;
if ($fId !== null && $fId <= 0) {
    $fType = null;
    $fId   = null;
}

$items  = $mediaLib->siteGallery($kind, $fType, $fId);
$facets = $mediaLib->galleryFacets();

// دسته‌بندی دکمه‌های فیلتر
$byType = ['doctor' => [], 'clinic' => [], 'page' => []];
foreach ($facets as $f) {
    $byType[$f['type']][] = $f;
}
$groupLabel = ['doctor' => 'پزشکان', 'clinic' => 'بخش‌ها', 'page' => 'خدمات'];

/** ساخت آدرس یک فیلتر، با حفظ بقیه‌ی شرط‌ها */
$link = function (array $over) use ($kind, $fType, $fId): string {
    $q = array_filter([
        'kind' => ($over['kind'] ?? $kind) === 'all' ? null : ($over['kind'] ?? $kind),
        't'    => array_key_exists('t', $over) ? $over['t'] : $fType,
        'i'    => array_key_exists('t', $over) ? ($over['i'] ?? null) : $fId,
    ], fn($v) => $v !== null && $v !== '');

    return url('/گالری/') . ($q ? '?' . http_build_query($q) : '');
};

$filtered = $kind !== 'all' || $fType !== null;
$phone    = $app['settings']['phone']     ?? '۰۲۱۹۱۳۰۳۱۳۲';
$tel      = $app['settings']['phone_raw'] ?? '02191303132';

// نام چیزی که رویش فیلتر شده، برای عنوان
$activeLabel = '';
if ($fType !== null) {
    foreach ($facets as $f) {
        if ($f['type'] === $fType && $f['id'] === $fId) {
            $activeLabel = $f['label'];
            break;
        }
    }
}

ob_start(); ?>

<header class="phead">
  <div class="pic" style="background-image:url('<?= e(img($page['hero_image'] ?: 'hero-reception.jpg', 1600)) ?>')" aria-hidden="true"></div>
  <div class="veil" aria-hidden="true"></div>
  <div class="in">
    <p class="kick">گالری</p>
    <h1><?= e($page['title']) ?></h1>
    <p class="lede"><?= e($page['meta_desc']) ?></p>
  </div>
</header>

<div class="in">

  <?php if ($facets !== [] || $items !== []): ?>
  <nav class="galbar" aria-label="فیلتر گالری">
    <div class="grow">
      <span class="glbl">نوع</span>
      <a class="gchip <?= $kind === 'all'   ? 'on' : '' ?>" href="<?= e($link(['kind' => 'all'])) ?>">همه</a>
      <a class="gchip <?= $kind === 'image' ? 'on' : '' ?>" href="<?= e($link(['kind' => 'image'])) ?>">عکس</a>
      <a class="gchip <?= $kind === 'video' ? 'on' : '' ?>" href="<?= e($link(['kind' => 'video'])) ?>">ویدیو</a>
    </div>

    <?php foreach ($groupLabel as $type => $label): ?>
      <?php if (empty($byType[$type])) { continue; } ?>
      <div class="grow">
        <span class="glbl"><?= e($label) ?></span>
        <?php foreach ($byType[$type] as $f): ?>
          <a class="gchip <?= ($fType === $type && $fId === $f['id']) ? 'on' : '' ?>"
             href="<?= e($link(['t' => $type, 'i' => $f['id']])) ?>">
            <?= e($f['label']) ?><span class="gn"><?= e(fa((string) $f['n'])) ?></span>
          </a>
        <?php endforeach; ?>
      </div>
    <?php endforeach; ?>

    <?php if ($filtered): ?>
      <a class="gclear" href="<?= e(url('/گالری/')) ?>">برداشتن فیلترها ✕</a>
    <?php endif; ?>
  </nav>
  <?php endif; ?>

  <?php if ($activeLabel !== ''): ?>
    <p class="gnote">در حال دیدن رسانه‌های <b><?= e($activeLabel) ?></b> — <?= e(fa((string) count($items))) ?> مورد.</p>
  <?php endif; ?>

</div>

<?php if ($items === []): ?>
  <section class="sec"><div class="in">
    <div class="empty-note">
      <?php if ($filtered): ?>
        <p><b>با این فیلتر چیزی پیدا نشد.</b></p>
        <p><a href="<?= e(url('/گالری/')) ?>">دیدن همه‌ی گالری ←</a></p>
      <?php else: ?>
        <p><b>گالری هنوز خالی است.</b></p>
        <p>تصاویر محیط کلینیک، بخش‌های درمانی و تجهیزات به‌زودی اینجا قرار می‌گیرد.</p>
      <?php endif; ?>
    </div>
  </div></section>
<?php else: ?>
  <?php $heading = ''; $lead = ''; require __DIR__ . '/_gallery.php'; ?>
<?php endif; ?>

<section class="sec alt"><div class="in"><div class="band">
  <div>
    <h2>سؤالی دارید؟</h2>
    <p><?= e($app['settings']['hours'] ?? '') ?></p>
  </div>
  <div class="acts">
    <a class="b b-teal" href="<?= url('/contact-us/') ?>">تماس با ما</a>
    <a class="b b-ghost" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
  </div>
</div></div></section>

<?php
$content = ob_get_clean();
$trail   = [$page['title'] => null];

// نمای فیلترشده canonical خودش را به آدرس تمیز گالری می‌دهد —
// canonicalUrl از $page['path'] می‌سازد و query را نمی‌آورد، پس
// خودبه‌خود درست است. عمداً noindex نمی‌زنیم: noindex در کنار
// canonicalِ جای دیگر دو سیگنال متناقض است و گوگل ممکن است هر
// دو را نادیده بگیرد.

$schema = [[
    '@type'       => 'ImageGallery',
    'name'        => $page['title'],
    'description' => $page['meta_desc'],
    'url'         => $seo->canonicalUrl($page),
    'isPartOf'    => ['@id' => 'https://' . $seo->canonicalHost() . '/#clinic'],
]];

require __DIR__ . '/layout.php';
