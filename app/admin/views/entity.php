<?php
/**
 * رسانه‌ی یک پزشک، بخش یا صفحه‌ی خدمت — سه دسته‌ی جدا.
 *
 * @var string $type @var int $id @var string $label
 * @var array  $profiles @var array $photos @var array $videos
 * @var array  $app
 */
$media = $app['media'];
$kindLabel = ['doctor' => 'پزشک', 'clinic' => 'بخش', 'page' => 'صفحه‌ی خدمت'][$type] ?? '';
?>
<div class="head">
  <h1><?= e($label) ?> <small><?= e($kindLabel) ?></small></h1>
  <a class="b" href="/admin/?p=media/upload">بارگذاری رسانه</a>
</div>

<?php if (!empty($flash)): ?>
  <p class="note ok"><?= e($flash['msg']) ?></p>
<?php endif; ?>

<h2>
  عکس پروفایل
  <small><?= e(fa((string) count($profiles))) ?> عکس</small>
</h2>
<p class="fine">
  این عکس‌ها روی کارت این <?= e($kindLabel) ?> در فهرست‌های سایت
  دیده می‌شوند. اگر بیش از یکی باشد، نوبتی عوض می‌شوند.
</p>

<?php if ($profiles === []): ?>
  <div class="empty small">
    <p>عکس پروفایلی ثبت نشده. تا وقتی عکس نرسیده، سایت یک باکس خالی نشان می‌دهد.</p>
  </div>
<?php else: ?>
  <div class="grid">
    <?php foreach ($profiles as $m): ?>
      <?php require __DIR__ . '/media/_card.php'; ?>
    <?php endforeach; ?>
  </div>
<?php endif; ?>

<h2>گالری عکس <small><?= e(fa((string) count($photos))) ?> عکس</small></h2>

<?php if ($photos === []): ?>
  <div class="empty small"><p>عکسی در گالری این مورد نیست.</p></div>
<?php else: ?>
  <div class="grid">
    <?php foreach ($photos as $m): ?>
      <?php require __DIR__ . '/media/_card.php'; ?>
    <?php endforeach; ?>
  </div>
<?php endif; ?>

<h2>گالری ویدیو <small><?= e(fa((string) count($videos))) ?> ویدیو</small></h2>

<?php if ($videos === []): ?>
  <div class="empty small"><p>ویدیویی در گالری این مورد نیست.</p></div>
<?php else: ?>
  <div class="grid">
    <?php foreach ($videos as $m): ?>
      <?php require __DIR__ . '/media/_card.php'; ?>
    <?php endforeach; ?>
  </div>
<?php endif; ?>
