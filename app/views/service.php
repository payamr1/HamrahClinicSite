<?php
/**
 * صفحه‌ی خدمت / کلینیک تخصصی.
 * چیدمان: متن سمت راست (لبه‌ی شروع خواندن)، ستون کناری سمت چپ.
 */
/** @var Repository $repo */
/** @var Seo $seo */

$clinic  = !empty($page['clinic_id']) ? $repo->clinicById((int) $page['clinic_id']) : null;
$faqs    = $repo->faqs((int) $page['id']);
$docs    = $clinic ? $repo->doctorsOfClinic((int) $clinic['id']) : [];
$sibling = $clinic ? $repo->servicesOfClinic((int) $clinic['id'], 8) : [];
$sibling = array_values(array_filter($sibling, fn($s) => (int) $s['id'] !== (int) $page['id']));

$phone = $app['settings']['phone']     ?? '۰۲۱۹۱۳۰۳۱۳۲';
$tel   = $app['settings']['phone_raw'] ?? '02191303132';
$hero  = $page['hero_image'] ?: 'hero-reception.jpg';

ob_start(); ?>

<header class="phead">
  <div class="pic" style="background-image:url('<?= e(asset('/assets/img/' . $hero)) ?>')" aria-hidden="true"></div>
  <div class="veil" aria-hidden="true"></div>
  <div class="in">
    <?php if ($clinic || !empty($page['kicker'])): ?>
      <p class="kick"><?= e($page['kicker'] ?: $clinic['name']) ?></p>
    <?php endif; ?>
    <h1><?= e($page['title']) ?></h1>
    <?php if (!empty($page['lede'])): ?>
      <p class="lede"><?= e($page['lede']) ?></p>
    <?php elseif ($clinic && !empty($clinic['summary'])): ?>
      <p class="lede"><?= e($clinic['summary']) ?></p>
    <?php endif; ?>

    <dl class="phead-meta">
      <?php if ($docs !== []): ?>
        <div><dt>پزشکان</dt><dd><?= fa((string) count($docs)) ?> متخصص</dd></div>
      <?php endif; ?>
      <?php if ($sibling !== []): ?>
        <div><dt>خدمات مرتبط</dt><dd><?= fa((string) count($sibling)) ?> خدمت</dd></div>
      <?php endif; ?>
      <div><dt>نوبت‌دهی</dt><dd><?= e($phone) ?></dd></div>
    </dl>
  </div>
</header>

<div class="in"><div class="lay">

  <article class="prose">
    <?php if (!empty($page['body'])): ?>
      <?= $page['body'] ?>
    <?php else: ?>
      <div class="empty-note">
        <p><b>متن این صفحه هنوز منتقل نشده است.</b></p>
        <p>مسیر، عنوان و توضیحات سئوی آن ثبت شده و در گوگل دست‌نخورده می‌ماند.
           متن اصلی از پنل مدیریت اضافه می‌شود.</p>
      </div>
    <?php endif; ?>
  </article>

  <aside class="side">
    <div class="sbox hi">
      <h4>رزرو نوبت این بخش</h4>
      <p>اگر مطمئن نیستید کدام خدمت مناسب شماست، تماس بگیرید.</p>
      <a class="b b-teal b-full" href="<?= url('/contact-us/') ?>">رزرو نوبت آنلاین</a>
      <a class="sbox-tel" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
    </div>

    <?php if ($docs !== []): ?>
    <div class="sbox">
      <h4>پزشکان این بخش</h4>
      <ul class="slist">
        <?php foreach (array_slice($docs, 0, 6) as $d): ?>
          <li><a href="<?= url($d['path'] ?? '/team/') ?>">
            <b><?= e($d['name']) ?></b><span><?= e($d['specialty']) ?></span>
          </a></li>
        <?php endforeach; ?>
      </ul>
    </div>
    <?php endif; ?>

    <div class="sbox">
      <h4>ساعات کاری</h4>
      <p class="sbox-hours"><?= e($app['settings']['hours'] ?? '') ?></p>
      <p class="sbox-addr"><?= e($app['settings']['address'] ?? '') ?></p>
    </div>
  </aside>

</div></div>

<?php if ($faqs !== []): ?>
<section class="sec alt"><div class="in">
  <div class="shead">
    <span class="lbl">پرسش‌های پرتکرار</span>
    <h2>سؤالات متداول</h2>
  </div>
  <div class="faq">
    <?php foreach ($faqs as $i => $f): ?>
      <details<?= $i === 0 ? ' open' : '' ?>>
        <summary><?= e($f['question']) ?></summary>
        <div class="ans"><?= $f['answer'] ?></div>
      </details>
    <?php endforeach; ?>
  </div>
</div></section>
<?php endif; ?>

<?php if ($docs !== []): ?>
<section class="sec"><div class="in">
  <div class="shead">
    <span class="lbl">تیم این بخش</span>
    <h2>پزشکان <?= e($clinic['name'] ?? '') ?></h2>
    <p>همگی دارای بورد تخصصی و شماره‌ی نظام پزشکی قابل استعلام.</p>
  </div>
  <div class="dgrid">
    <?php foreach ($docs as $d): ?>
      <a class="doc" href="<?= url($d['path'] ?? '/team/') ?>">
        <span class="ph<?= empty($d['photo']) ? ' ph-empty' : '' ?>"
          <?php if (!empty($d['photo'])): ?>style="background-image:url('<?= e(asset('/assets/img/' . $d['photo'])) ?>')"<?php endif; ?>></span>
        <span class="bd">
          <h3><?= e($d['name']) ?></h3>
          <span class="sp"><?= e($d['specialty']) ?></span>
          <?php if (!empty($d['fellowship'])): ?>
            <span class="sub"><?= e(excerpt($d['fellowship'], 70)) ?></span>
          <?php endif; ?>
          <?php if (!empty($d['license_no'])): ?>
            <span class="no">نظام پزشکی <?= e(fa($d['license_no'])) ?></span>
          <?php endif; ?>
        </span>
      </a>
    <?php endforeach; ?>
  </div>
</div></section>
<?php endif; ?>

<?php if ($sibling !== []): ?>
<section class="sec alt"><div class="in">
  <div class="shead">
    <span class="lbl">زیرمجموعه</span>
    <h2>خدمات این کلینیک</h2>
  </div>
  <div class="cgrid">
    <?php foreach ($sibling as $s): ?>
      <a class="card" href="<?= url($s['path']) ?>">
        <span class="bd">
          <h3><?= e($s['title']) ?></h3>
          <p><?= e(excerpt($s['lede'] ?: $s['meta_desc'], 110)) ?></p>
          <span class="ft"><span class="cnt"></span><span class="go">مشاهده ←</span></span>
        </span>
      </a>
    <?php endforeach; ?>
  </div>
</div></section>
<?php endif; ?>

<section class="sec"><div class="in"><div class="band">
  <div>
    <h2>نوبت <?= e($clinic['name'] ?? $page['title']) ?></h2>
    <p>پشتیبانی ۲۴ ساعته، هفت روز هفته.</p>
  </div>
  <div class="acts">
    <a class="b b-teal" href="<?= url('/contact-us/') ?>">رزرو نوبت آنلاین</a>
    <a class="b b-ghost" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
  </div>
</div></div></section>

<?php
$content = ob_get_clean();

$trail = [];
$trail['کلینیک‌ها'] = '/service/';
if ($clinic && !empty($clinic['page_id']) && (int) $clinic['page_id'] !== (int) $page['id']) {
    $cp = $repo->pageById((int) $clinic['page_id']);
    if ($cp !== null) { $trail[$clinic['name']] = $cp['path']; }
}
$trail[$page['title']] = null;

$schema = [[
    '@type'       => 'MedicalWebPage',
    'name'        => $page['title'],
    'description' => $page['meta_desc'],
    'url'         => $seo->canonicalUrl($page),
    'about'       => ['@id' => 'https://' . $seo->canonicalHost() . '/#clinic'],
]];
$faqNode = $seo->faqSchema($faqs);
if ($faqNode !== null) { $schema[] = $faqNode; }
foreach ($docs as $d) { $schema[] = $seo->physicianSchema($d); }

require __DIR__ . '/layout.php';
