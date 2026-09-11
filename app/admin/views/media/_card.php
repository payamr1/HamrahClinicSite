<?php
/**
 * یک کارت در شبکه‌ی کتابخانه.
 * ‎$m ردیف media و ‎$media نمونه‌ی کلاس است.
 *
 * @var array $m
 * @var array $app
 */
$media   = $app['media'];
$isVideo = ($m['kind'] ?? 'image') === 'video';
$embed   = !empty($m['embed_url']);
?>
<a class="mcard<?= empty($m['is_active']) ? ' off' : '' ?>" href="/admin/?p=media/edit&amp;id=<?= (int) $m['id'] ?>">
  <span class="thumb">
    <?php if (!$isVideo): ?>
      <img src="<?= e(img($media->imagePath($m), 400)) ?>"
           alt="" loading="lazy"
           <?php if (!empty($m['width'])): ?>width="<?= (int) $m['width'] ?>" height="<?= (int) $m['height'] ?>"<?php endif; ?>>
    <?php elseif ($embed): ?>
      <span class="vbox embed">آپارات / یوتیوب</span>
    <?php else: ?>
      <span class="vbox">ویدیو</span>
    <?php endif; ?>
    <?php if ($isVideo): ?><span class="badge">ویدیو</span><?php endif; ?>
    <?php if (empty($m['is_active'])): ?><span class="badge off">پنهان</span><?php endif; ?>
  </span>

  <span class="bd">
    <b><?= e($m['title'] ?: ($m['alt'] ?: basename((string) ($m['filename'] ?: $m['embed_url'])))) ?></b>
    <small><?= e(jdate((string) $m['created_at'])) ?></small>
  </span>
</a>
