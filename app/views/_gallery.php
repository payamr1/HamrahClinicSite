<?php
/**
 * گالری عکس و ویدیو — مشترک بین صفحه‌ی پزشک، بخش و گالری عمومی.
 *
 * دو تصمیم که عمداً گرفته شده:
 *
 *  ۱. برای دیدن عکس در اندازه‌ی کامل، فقط یک لینک ساده گذاشته‌ایم.
 *     یک lightbox جاوااسکریپتی چند ده کیلوبایت می‌گیرد تا کاری کند
 *     که مرورگر خودش بلد است.
 *
 *  ۲. ویدیوی آپارات و یوتیوب تا وقتی کاربر کلیک نکند بارگذاری
 *     نمی‌شود. iframe آن‌ها به‌تنهایی از کل صفحه‌ی ما سنگین‌تر است
 *     و کوکی شخص ثالث هم می‌آورد.
 *
 * @var array  $items   ردیف‌های media
 * @var string $heading عنوان بخش
 * @var string $lead    یک جمله زیر عنوان، اختیاری
 * @var array  $app
 */
$media = $app['media'];
$items = $items ?? [];
if ($items === []) {
    return;
}
$hasEmbed = false;
?>
<section class="sec gal-sec"><div class="in">
  <?php if (!empty($heading)): ?>
    <div class="shead">
      <span class="lbl">گالری</span>
      <h2><?= e($heading) ?></h2>
      <?php if (!empty($lead)): ?><p><?= e($lead) ?></p><?php endif; ?>
    </div>
  <?php endif; ?>

  <div class="gal">
    <?php foreach ($items as $m): ?>
      <?php if ($m['kind'] === 'image'): ?>

        <figure class="gitem">
          <a href="<?= e(img($media->imagePath($m), 1600)) ?>"
             target="_blank" rel="noopener"
             aria-label="<?= e($m['alt'] ?: ($m['title'] ?: 'دیدن عکس در اندازه‌ی کامل')) ?>">
            <img src="<?= e(img($media->imagePath($m), 600)) ?>"
                 alt="<?= e((string) $m['alt']) ?>"
                 loading="lazy" decoding="async"
                 <?php if (!empty($m['width'])): ?>
                   width="<?= (int) $m['width'] ?>" height="<?= (int) $m['height'] ?>"
                 <?php endif; ?>>
          </a>
          <?php if (!empty($m['title']) || !empty($m['description'])): ?>
            <figcaption>
              <?php if (!empty($m['title'])): ?><b><?= e($m['title']) ?></b><?php endif; ?>
              <?php if (!empty($m['description'])): ?><span><?= e($m['description']) ?></span><?php endif; ?>
              <time datetime="<?= e(substr((string) ($m['taken_on'] ?: $m['created_at']), 0, 10)) ?>">
                <?= e(jdate((string) ($m['taken_on'] ?: $m['created_at']))) ?>
              </time>
            </figcaption>
          <?php endif; ?>
        </figure>

      <?php elseif (!empty($m['embed_url'])): ?>
        <?php $hasEmbed = true; ?>

        <figure class="gitem vid">
          <button type="button" class="vplay" data-embed="<?= e((string) $m['embed_url']) ?>">
            <span class="vposter" aria-hidden="true"></span>
            <span class="vicon" aria-hidden="true"></span>
            <span class="vtxt"><?= e($m['title'] ?: 'پخش ویدیو') ?></span>
          </button>
          <noscript>
            <a href="<?= e((string) $m['embed_url']) ?>" target="_blank" rel="noopener">
              دیدن ویدیو ↗
            </a>
          </noscript>
          <?php if (!empty($m['description'])): ?>
            <figcaption><span><?= e($m['description']) ?></span></figcaption>
          <?php endif; ?>
        </figure>

      <?php else: ?>

        <figure class="gitem vid">
          <video controls preload="none"
                 <?php if (!empty($m['poster'])): ?>poster="<?= e(img('../uploads/' . $m['poster'], 800)) ?>"<?php endif; ?>
                 src="<?= e($media->url($m)) ?>"></video>
          <?php if (!empty($m['title']) || !empty($m['description'])): ?>
            <figcaption>
              <?php if (!empty($m['title'])): ?><b><?= e($m['title']) ?></b><?php endif; ?>
              <?php if (!empty($m['description'])): ?><span><?= e($m['description']) ?></span><?php endif; ?>
            </figcaption>
          <?php endif; ?>
        </figure>

      <?php endif; ?>
    <?php endforeach; ?>
  </div>
</div></section>

<?php if ($hasEmbed): ?>
  <script src="<?= e(asset('/assets/js/video.js')) ?>" defer></script>
<?php endif; ?>
