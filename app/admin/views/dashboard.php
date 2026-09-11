<?php
/** @var array $stats @var array $recent @var ?array $flash @var array $app */
$media = $app['media'];
?>
<?php if (!empty($flash)): ?>
  <p class="note ok"><?= e($flash['msg']) ?></p>
<?php endif; ?>

<div class="head">
  <h1>میزکار</h1>
  <a class="b" href="/admin/?p=media/upload">بارگذاری رسانه</a>
</div>

<div class="tiles">
  <a class="tile" href="/admin/?p=media&kind=image">
    <b><?= e(fa((string) $stats['images'])) ?></b><span>عکس</span>
  </a>
  <a class="tile" href="/admin/?p=media&kind=video">
    <b><?= e(fa((string) $stats['videos'])) ?></b><span>ویدیو</span>
  </a>
  <a class="tile <?= $stats['untagged'] > 0 ? 'warn' : '' ?>" href="/admin/?p=media&untagged=1">
    <b><?= e(fa((string) $stats['untagged'])) ?></b><span>بدون تگ</span>
  </a>
  <a class="tile" href="/admin/?p=targets">
    <b><?= e(fa((string) $stats['doctors'])) ?></b><span>پزشک</span>
  </a>
  <a class="tile" href="/admin/?p=targets">
    <b><?= e(fa((string) $stats['clinics'])) ?></b><span>بخش</span>
  </a>
  <span class="tile mute">
    <b><?= e(fa((string) $stats['pages'])) ?></b><span>صفحه‌ی منتشرشده</span>
  </span>
</div>

<?php if ($stats['untagged'] > 0): ?>
  <p class="note warn">
    <?= e(fa((string) $stats['untagged'])) ?> فایل هیچ تگی ندارد و در هیچ صفحه‌ای دیده نمی‌شود.
    <a href="/admin/?p=media&untagged=1">تگ‌گذاری کنید ←</a>
  </p>
<?php endif; ?>

<h2>تازه‌ترین بارگذاری‌ها</h2>

<?php if ($recent === []): ?>
  <div class="empty">
    <p>هنوز فایلی بارگذاری نشده است.</p>
    <a class="b" href="/admin/?p=media/upload">اولین فایل را بگذارید</a>
  </div>
<?php else: ?>
  <div class="grid">
    <?php foreach ($recent as $m): ?>
      <?php require __DIR__ . '/media/_card.php'; ?>
    <?php endforeach; ?>
  </div>
<?php endif; ?>
