<?php
/**
 * صفحه‌ی مقاله.
 * سربرگ روشن است نه سرمه‌ای — مقاله برای خواندن است و باند تیره در
 * صفحه‌ای که چند دقیقه مطالعه دارد خسته‌کننده می‌شود.
 */
/** @var Repository $repo */
/** @var Seo $seo */

$author  = $repo->authorOfPage((int) $page['id']);
$related = $repo->relatedPosts($page, 3);
$clinic  = !empty($page['clinic_id']) ? $repo->clinicById((int) $page['clinic_id']) : null;
$mins    = readingTime($page['body'] ?? '');

$phone = $app['settings']['phone']     ?? '۰۲۱۹۱۳۰۳۱۳۲';
$tel   = $app['settings']['phone_raw'] ?? '02191303132';

ob_start(); ?>

<header class="phead light">
  <div class="in">
    <?php if ($clinic !== null): ?>
      <p class="kick"><?= e($clinic['name']) ?></p>
    <?php endif; ?>
    <h1><?= e($page['title']) ?></h1>
    <?php if (!empty($page['lede'])): ?>
      <p class="lede"><?= e($page['lede']) ?></p>
    <?php else: ?>
      <p class="lede"><?= e($page['meta_desc']) ?></p>
    <?php endif; ?>

    <div class="byline">
      <?php if ($author !== null): ?>
        <?php if (!empty($author['photo'])): ?>
          <span class="av" style="background-image:url('<?= e(img($author['photo'], 400)) ?>')"
                role="img" aria-label="<?= e($author['name']) ?>"></span>
        <?php else: ?>
          <span class="av av-empty" aria-hidden="true"></span>
        <?php endif; ?>
        <span class="who">
          <b><?= e($author['name']) ?></b>
          <span><?= e($author['specialty']) ?><?php if (!empty($author['license_no'])): ?>
            · نظام پزشکی <?= e(fa($author['license_no'])) ?><?php endif; ?></span>
        </span>
      <?php endif; ?>
      <span class="when">
        <?php if (!empty($page['published_at'])): ?>
          <b><?= e(jdate($page['published_at'])) ?></b>
        <?php endif; ?>
        <span>حدود <?= e(fa((string) $mins)) ?> دقیقه مطالعه</span>
      </span>
    </div>
  </div>
</header>

<div class="in"><div class="lay">

  <article class="prose">
    <?php if (!empty($page['hero_image'])): ?>
      <figure class="fig">
        <span class="ph" style="background-image:url('<?= e(img($page['hero_image'], 900)) ?>')"
              role="img" aria-label="<?= e($page['title']) ?>"></span>
      </figure>
    <?php endif; ?>

    <?php if (!empty($page['body'])): ?>
      <?= $page['body'] ?>
    <?php else: ?>
      <div class="empty-note">
        <p><b>متن این مقاله هنوز منتقل نشده است.</b></p>
        <p>آدرس، عنوان و توضیحات سئوی آن ثبت شده و در گوگل دست‌نخورده می‌ماند.</p>
      </div>
    <?php endif; ?>

    <?php if ($author !== null): ?>
    <aside class="author">
      <?php if (!empty($author['photo'])): ?>
        <span class="av" style="background-image:url('<?= e(img($author['photo'], 400)) ?>')"></span>
      <?php else: ?>
        <span class="av av-empty"></span>
      <?php endif; ?>
      <div>
        <h4><?= e($author['name']) ?></h4>
        <p class="sp"><?= e($author['specialty']) ?><?php if (!empty($author['license_no'])): ?>
          · نظام پزشکی <?= e(fa($author['license_no'])) ?><?php endif; ?></p>
        <?php if (!empty($author['fellowship'])): ?>
          <p><?= e($author['fellowship']) ?></p>
        <?php endif; ?>
        <?php if (!empty($author['path'])): ?>
          <a class="more" href="<?= url($author['path']) ?>">مشاهده‌ی پروفایل و رزرو نوبت ←</a>
        <?php endif; ?>
      </div>
    </aside>
    <?php endif; ?>
  </article>

  <aside class="side">
    <div class="sbox hi">
      <h4>نگران این علائم هستید؟</h4>
      <p>ارزیابی اولیه در <?= e($clinic['name'] ?? 'کلینیک') ?> همراه انجام می‌شود.</p>
      <a class="b b-teal b-full" href="<?= url('/contact-us/') ?>">مشاوره با متخصص</a>
      <a class="sbox-tel" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
    </div>

    <div class="sbox">
      <h4>مشخصات</h4>
      <dl class="facts">
        <?php if ($author !== null): ?>
          <div><dt>نویسنده</dt><dd><?= e($author['name']) ?></dd></div>
        <?php endif; ?>
        <?php if ($clinic !== null): ?>
          <div><dt>دسته</dt><dd><?= e($clinic['name']) ?></dd></div>
        <?php endif; ?>
        <?php if (!empty($page['published_at'])): ?>
          <div><dt>انتشار</dt><dd><?= e(jdate($page['published_at'], false)) ?></dd></div>
        <?php endif; ?>
        <div><dt>مطالعه</dt><dd><?= e(fa((string) $mins)) ?> دقیقه</dd></div>
      </dl>
    </div>
  </aside>

</div></div>

<?php if ($related !== []): ?>
<section class="sec alt"><div class="in">
  <div class="shead">
    <span class="lbl">در همین موضوع</span>
    <h2>مقالات مرتبط</h2>
  </div>
  <div class="cgrid">
    <?php foreach ($related as $r): ?>
      <a class="card" href="<?= url($r['path']) ?>">
        <span class="bd">
          <h3><?= e($r['title']) ?></h3>
          <p><?= e(excerpt($r['lede'] ?: $r['meta_desc'], 100)) ?></p>
          <span class="ft">
            <span class="cnt"><?= e(jdate($r['published_at'])) ?></span>
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
    <h2>سؤالی درباره‌ی این موضوع دارید؟</h2>
    <p>پشتیبانی ۲۴ ساعته، هفت روز هفته.</p>
  </div>
  <div class="acts">
    <a class="b b-teal" href="<?= url('/contact-us/') ?>">رزرو نوبت</a>
    <a class="b b-ghost" href="tel:<?= e($tel) ?>"><?= e($phone) ?></a>
  </div>
</div></div></section>

<?php
$content = ob_get_clean();

$trail = ['مقالات' => '/blog/'];
$trail[$page['title']] = null;

// اتصال Article به Physician — همان سیگنالی که گوگل برای YMYL می‌خواهد
$schema = [
    $seo->articleSchema($page, $author),
    [
        '@type'       => 'MedicalWebPage',
        'name'        => $page['title'],
        'description' => $page['meta_desc'],
        'url'         => $seo->canonicalUrl($page),
    ],
];

require __DIR__ . '/layout.php';
