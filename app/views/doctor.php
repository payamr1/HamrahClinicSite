<?php
/**
 * صفحه‌ی پزشک.
 * از نظر سئو مهم‌ترین صفحه‌ی سایت است: اسکیمای Physician با شماره‌ی
 * نظام پزشکی، همان چیزی است که گوگل برای اعتبار محتوای سلامت (YMYL)
 * بررسی می‌کند.
 */
/** @var Repository $repo */
/** @var Seo $seo */

$doc = $repo->doctorByPageId((int) $page['id']);
if ($doc === null) {
    $doc = ['name' => $page['title'], 'specialty' => '', 'photo' => null, 'license_no' => null];
}
$clinics  = !empty($doc['id']) ? $repo->clinicsOfDoctor((int) $doc['id']) : [];
$articles = !empty($doc['id']) ? $repo->postsByDoctor((int) $doc['id'], 6) : [];

$phone = $app['settings']['phone']     ?? '۰۲۱۹۱۳۰۳۱۳۲';
$tel   = $app['settings']['phone_raw'] ?? '02191303132';
$hero  = $page['hero_image'] ?: 'hero-reception.jpg';

ob_start(); ?>

<header class="phead">
  <div class="pic" style="background-image:url('<?= e(img($hero, 1600)) ?>')" aria-hidden="true"></div>
  <div class="veil" aria-hidden="true"></div>
  <div class="in">
    <div class="dhero">
      <?php if (!empty($doc['photo'])): ?>
        <div class="por" style="background-image:url('<?= e(img($doc['photo'], 600)) ?>')"
             role="img" aria-label="<?= e($doc['name']) ?>"></div>
      <?php else: ?>
        <div class="por por-empty" aria-hidden="true"></div>
      <?php endif; ?>

      <div>
        <?php if (!empty($doc['is_founder'])): ?>
          <p class="kick">مدیر و مؤسس کلینیک</p>
        <?php endif; ?>
        <h1><?= e($doc['name']) ?></h1>

        <?php
          $lede = $page['lede'] ?: trim(implode('، ', array_filter([
              $doc['specialty'] ?? null,
              $doc['fellowship'] ?? null,
              $doc['university'] ?? null,
          ])));
        ?>
        <?php if ($lede !== ''): ?><p class="lede"><?= e($lede) ?></p><?php endif; ?>

        <div class="tagrow">
          <?php if (!empty($doc['specialty'])): ?>
            <span class="tag teal"><?= e($doc['specialty']) ?></span>
          <?php endif; ?>
          <?php if (!empty($doc['fellowship'])): ?>
            <span class="tag"><?= e(excerpt($doc['fellowship'], 46)) ?></span>
          <?php endif; ?>
          <?php if (!empty($doc['license_no'])): ?>
            <span class="tag">نظام پزشکی <?= e(fa($doc['license_no'])) ?></span>
          <?php endif; ?>
        </div>

        <div class="dhero-acts">
          <a class="b b-teal" href="<?= url('/contact-us/') ?>">رزرو نوبت با ایشان</a>
          <a class="b b-ghost" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
        </div>
      </div>
    </div>
  </div>
</header>

<div class="in"><div class="lay">

  <article class="prose">
    <?php if (!empty($doc['bio'])): ?>
      <?= $doc['bio'] ?>
    <?php elseif (!empty($page['body'])): ?>
      <?= $page['body'] ?>
    <?php else: ?>
      <div class="empty-note">
        <p><b>شرح حال این پزشک هنوز نوشته نشده است.</b></p>
        <p>سوابق تحصیلی در جدول زیر آمده؛ متن معرفی از پنل مدیریت اضافه می‌شود.</p>
      </div>
    <?php endif; ?>

    <h2>سوابق</h2>
    <dl class="rec">
      <?php if (!empty($doc['specialty'])): ?>
        <div><dt>تخصص</dt><dd><b><?= e($doc['specialty']) ?></b></dd></div>
      <?php endif; ?>
      <?php if (!empty($doc['university'])): ?>
        <div><dt>دانشگاه</dt><dd><?= e($doc['university']) ?></dd></div>
      <?php endif; ?>
      <?php if (!empty($doc['fellowship'])): ?>
        <div><dt>فلوشیپ</dt><dd><?= e($doc['fellowship']) ?></dd></div>
      <?php endif; ?>
      <?php if (!empty($doc['license_no'])): ?>
        <div><dt>نظام پزشکی</dt><dd><?= e(fa($doc['license_no'])) ?></dd></div>
      <?php endif; ?>
      <?php if (!empty($doc['schedule'])): ?>
        <div><dt>حضور در کلینیک</dt><dd><?= e($doc['schedule']) ?></dd></div>
      <?php endif; ?>
    </dl>
  </article>

  <aside class="side">
    <div class="sbox hi">
      <h4>رزرو نوبت</h4>
      <?php if (!empty($doc['schedule'])): ?>
        <p>حضور در کلینیک: <?= e($doc['schedule']) ?></p>
      <?php else: ?>
        <p>برای هماهنگی زمان ویزیت تماس بگیرید.</p>
      <?php endif; ?>
      <a class="b b-teal b-full" href="<?= url('/contact-us/') ?>">انتخاب ساعت</a>
      <a class="sbox-tel" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
    </div>

    <?php if ($clinics !== []): ?>
    <div class="sbox">
      <h4>بخش‌هایی که ویزیت دارند</h4>
      <ul class="slist">
        <?php foreach ($clinics as $c): ?>
          <li><a href="<?= url($c['page_path'] ?? '/service/') ?>">
            <b><?= e($c['name']) ?></b>
            <?php if (!empty($c['tagline'])): ?><span><?= e($c['tagline']) ?></span><?php endif; ?>
          </a></li>
        <?php endforeach; ?>
      </ul>
    </div>
    <?php endif; ?>
  </aside>

</div></div>

<?php if ($articles !== []): ?>
<section class="sec alt"><div class="in">
  <div class="shead">
    <span class="lbl">نوشته‌ها</span>
    <h2>مقالات <?= e($doc['name']) ?></h2>
  </div>
  <div class="cgrid">
    <?php foreach ($articles as $a): ?>
      <a class="card" href="<?= url($a['path']) ?>">
        <span class="bd">
          <h3><?= e($a['title']) ?></h3>
          <span class="ft">
            <span class="cnt"><?= e(jdate($a['published_at'])) ?></span>
            <span class="go">خواندن ←</span>
          </span>
        </span>
      </a>
    <?php endforeach; ?>
  </div>
</div></section>
<?php endif; ?>

<section class="sec"><div class="in"><div class="band">
  <div>
    <h2>رزرو نوبت با <?= e($doc['name']) ?></h2>
    <p><?= e($doc['schedule'] ?: ($app['settings']['hours'] ?? '')) ?></p>
  </div>
  <div class="acts">
    <a class="b b-teal" href="<?= url('/contact-us/') ?>">رزرو نوبت</a>
    <a class="b b-ghost" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
  </div>
</div></div></section>

<?php
$content = ob_get_clean();
$trail   = ['پزشکان' => '/team/', $doc['name'] => null];

$phys = $seo->physicianSchema(array_merge($doc, ['path' => $page['path']]));
if ($clinics !== []) {
    $phys['medicalSpecialty'] = array_values(array_map(fn($c) => $c['name'], $clinics));
}
$schema = [
    $phys,
    [
        '@type'      => 'ProfilePage',
        'name'       => $page['title'],
        'url'        => $seo->canonicalUrl($page),
        'mainEntity' => ['@type' => 'Physician', 'name' => $doc['name']],
    ],
];

require __DIR__ . '/layout.php';
