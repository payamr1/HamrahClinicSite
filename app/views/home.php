<?php
/**
 * صفحه‌ی اصلی — پورت ماکاپ تأییدشده (الگوی Medicana) با داده‌ی واقعی.
 */
/** @var Repository $repo */
/** @var Seo $seo */

$clinics = $repo->clinics();
$doctors = $repo->doctors();   // همه‌ی پزشکان، نه فقط شش تای اول
$posts   = $repo->posts(4);

$nClinics = count($clinics);
$nDoctors = $repo->countOfType('doctor');
$nService = $repo->countOfType('service');

$hero  = $page['hero_image'] ?: 'hero-reception.jpg';
$phone = $app['settings']['phone']     ?? '۰۲۱۹۱۳۰۳۱۳۲';
$tel   = $app['settings']['phone_raw'] ?? '02191303132';

ob_start(); ?>

<header class="hero">
  <div class="pic" style="background-image:url('<?= e(img($hero, 1600)) ?>')"
       role="img" aria-label="پذیرش همراه کلینیک"></div>
  <div class="veil" aria-hidden="true"></div>

  <ul class="chips" aria-label="یک نگاه به کلینیک">
    <li><b><?= fa((string) $nClinics) ?></b><span>کلینیک تخصصی</span></li>
    <li><b><?= fa((string) $nDoctors) ?></b><span>پزشک متخصص</span></li>
    <li><b><?= fa((string) $nService) ?></b><span>خدمت درمانی</span></li>
  </ul>

  <div class="in">
    <p class="kick">تنها مرکز کاردیو آنکولوژی تجریش</p>
    <h1>همراه شما، در <em>تمام مسیر</em> درمان</h1>
    <p class="lede">قلب، آنکولوژی، تغذیه و روان — در یک پرونده‌ی مشترک. تیم درمان
      هفتگی درباره‌ی وضعیت شما تصمیم می‌گیرد، نه هر پزشک جداگانه.</p>

    <div class="hero-acts">
      <a class="b b-teal" href="<?= url('/contact-us/') ?>">رزرو نوبت آنلاین</a>
      <a class="b b-ghost" href="<?= url('/service/') ?>">مشاهده‌ی کلینیک‌ها</a>
    </div>

    <div class="tiles">
      <a class="tile" href="<?= url('/service/') ?>">
        <b>کلینیک‌های ما</b><span><?= fa((string) $nClinics) ?> بخش تخصصی</span>
      </a>
      <a class="tile" href="<?= url('/team/') ?>">
        <b>پزشکان</b><span><?= fa((string) $nDoctors) ?> متخصص</span>
      </a>
      <a class="tile" href="<?= url('/contact-us/') ?>">
        <b>نوبت آنلاین</b><span>در چند دقیقه</span>
      </a>
    </div>
  </div>
</header>

<div class="fbar"><div class="in"><div class="box">
  <a href="<?= url('/contact-us/') ?>">
    <span><b>رزرو نوبت سریع</b><span>انتخاب پزشک و ساعت</span></span>
  </a>
  <a href="<?= url('/service/') ?>">
    <span><b>کلینیک‌ها و خدمات</b><span><?= fa((string) $nService) ?> خدمت درمانی</span></span>
  </a>
  <a href="tel:<?= e($tel) ?>">
    <span><b>مشاوره‌ی تلفنی</b><span><?= e($phone) ?></span></span>
  </a>
</div></div></div>

<?php if ($clinics !== []): ?>
<section class="sec"><div class="in">
  <div class="shead">
    <span class="lbl">کلینیک‌های تخصصی</span>
    <h2><?= fa((string) $nClinics) ?> بخش، یک پرونده‌ی مشترک</h2>
    <p>در همراه کلینیک درمان جسم، تغذیه و روان از هم جدا نیستند. هر بخش به
       سوابق بخش‌های دیگر دسترسی دارد.</p>
  </div>
  <div class="cgrid">
    <?php foreach ($clinics as $c): ?>
      <a class="card" href="<?= url($c['page_path'] ?? '/service/') ?>">
        <?php if (!empty($c['image'])): ?>
          <span class="ph" style="background-image:url('<?= e(img($c['image'], 400)) ?>')"></span>
        <?php else: ?>
          <span class="ph ph-empty"></span>
        <?php endif; ?>
        <span class="bd">
          <h3><?= e($c['name']) ?></h3>
          <?php if (!empty($c['summary'])): ?><p><?= e($c['summary']) ?></p><?php endif; ?>
          <span class="ft">
            <span class="cnt">
              <?php
                $bits = [];
                if ((int) $c['service_count'] > 0) { $bits[] = fa((string) $c['service_count']) . ' خدمت'; }
                if ((int) $c['doctor_count']  > 0) { $bits[] = fa((string) $c['doctor_count'])  . ' پزشک'; }
                echo e(implode(' · ', $bits) ?: ($c['tagline'] ?? ''));
              ?>
            </span>
            <span class="go">مشاهده ←</span>
          </span>
        </span>
      </a>
    <?php endforeach; ?>
  </div>
</div></section>
<?php endif; ?>

<section class="sec"><div class="in"><div class="stats">
  <div class="stat"><b><?= fa((string) $nClinics) ?></b><span>کلینیک تخصصی</span></div>
  <div class="stat"><b><?= fa((string) $nDoctors) ?></b><span>پزشک با بورد تخصصی</span></div>
  <div class="stat"><b><?= fa((string) $nService) ?></b><span>خدمت درمانی</span></div>
  <div class="stat"><b><?= fa('5') ?></b><span>فلوشیپ کاردیو آنکولوژی و اکو</span></div>
</div></div></section>

<section class="sec"><div class="in"><div class="split">
  <div>
    <div class="shead">
      <span class="lbl">رویکرد ما</span>
      <h2>بیمار سرطانی نباید برای قلبش جای دیگری برود</h2>
      <p>برخی داروهای شیمی‌درمانی و رادیوتراپی قفسه‌ی سینه می‌توانند عملکرد قلب
         را تحت تأثیر بگذارند. در همراه کلینیک، متخصص قلب از روز اول در تیم درمان
         حضور دارد — نه بعد از بروز علامت.</p>
    </div>
    <div class="feat">
      <div>
        <b>تیم چندتخصصی (MDT)</b>
        <p>آنکولوژیست، متخصص قلب، متخصص تغذیه و روان‌پزشک هفتگی درباره‌ی یک
           پرونده تصمیم می‌گیرند.</p>
      </div>
      <div>
        <b>پایش قلب در طول درمان</b>
        <p>اکوکاردیوگرافی پایه پیش از شروع دوره و پایش دوره‌ای، تا کوچک‌ترین
           تغییر زودتر دیده شود.</p>
      </div>
      <div>
        <b>همراهی، نه فقط درمان</b>
        <p>حمایت روانی بیمار و خانواده، و برنامه‌ی تغذیه‌ی متناسب با دوره‌ی درمان.</p>
      </div>
    </div>
  </div>
  <div class="art" style="background-image:url('<?= e(img($hero, 1600)) ?>')"
       role="img" aria-label="محیط همراه کلینیک"></div>
</div></div></section>

<?php if ($doctors !== []): ?>
<section class="sec alt"><div class="in">
  <div class="shead">
    <span class="lbl">تیم درمان</span>
    <h2>پزشکان همراه کلینیک</h2>
  </div>
  <div class="dgrid">
    <?php foreach ($doctors as $d): ?>
      <a class="doc" href="<?= url($d['path'] ?? '/team/') ?>">
        <?php if (!empty($d['photo'])): ?>
          <span class="ph" style="background-image:url('<?= e(img($d['photo'], 400)) ?>')"></span>
        <?php else: ?>
          <span class="ph ph-empty"></span>
        <?php endif; ?>
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
  <p class="sec-more">
    <a class="b b-out" href="<?= url('/team/') ?>">صفحه‌ی پزشکان</a>
  </p>
</div></section>
<?php endif; ?>

<?php if ($posts !== []): ?>
<section class="sec"><div class="in">
  <div class="shead">
    <span class="lbl">بلاگ سلامت</span>
    <h2>مقالات علمی و کاربردی</h2>
    <p>نوشته‌ی پزشکان کلینیک، به زبان ساده — درباره‌ی قلب، شیمی‌درمانی، تغذیه و سلامت روان.</p>
  </div>
  <div class="agrid">
    <?php foreach ($posts as $p): ?>
      <a class="art-c" href="<?= url($p['path']) ?>">
        <span class="ph<?= empty($p['hero_image']) ? ' ph-empty' : '' ?>"
          <?php if (!empty($p['hero_image'])): ?>style="background-image:url('<?= e(img($p['hero_image'], 400)) ?>')"<?php endif; ?>></span>
        <span class="bd">
          <h3><?= e($p['title']) ?></h3>
          <span class="dt">
            <?php if (!empty($p['author_name'])): ?><?= e($p['author_name']) ?> · <?php endif; ?>
            <?= e(jdate($p['published_at'])) ?>
          </span>
        </span>
      </a>
    <?php endforeach; ?>
  </div>
</div></section>
<?php endif; ?>

<section class="sec"><div class="in"><div class="band">
  <div>
    <h2>هنوز مطمئن نیستید کدام بخش؟</h2>
    <p>تماس بگیرید. راهنمای ما مسیر درست را به شما نشان می‌دهد.</p>
  </div>
  <div class="acts">
    <a class="b b-teal" href="<?= url('/contact-us/') ?>">رزرو نوبت آنلاین</a>
    <a class="b b-ghost" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
  </div>
</div></div></section>

<?php
$content = ob_get_clean();
$trail   = [];

// اسکیمای صفحه‌ی اصلی: خود کلینیک در layout هست، اینجا وب‌سایت و پزشکان
$schema = [
    [
        '@type'  => 'WebSite',
        'name'   => $app['settings']['site_name'] ?? 'همراه کلینیک',
        'url'    => 'https://' . $seo->canonicalHost() . '/',
        'inLanguage' => 'fa-IR',
    ],
];
foreach ($doctors as $d) {
    $schema[] = $seo->physicianSchema($d);
}

require __DIR__ . '/layout.php';
