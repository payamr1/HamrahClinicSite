<?php
/**
 * فهرست هر چیزی که می‌تواند رسانه داشته باشد، با شمار رسانه‌اش.
 *
 * @var array $targets @var array $counts
 */
$groups = [
    'doctor' => 'پزشکان و همکاران',
    'clinic' => 'بخش‌ها',
    'page'   => 'صفحه‌های خدمات',
];
?>
<div class="head">
  <h1>پزشکان، بخش‌ها و صفحه‌ها</h1>
  <a class="b" href="/admin/?p=media/upload">بارگذاری رسانه</a>
</div>

<p class="fine">
  کنار هر نام، تعداد عکس پروفایل و تعداد فایل گالری آمده. آن‌هایی که
  عکس پروفایل ندارند در سایت با باکس خالی دیده می‌شوند.
</p>

<?php foreach ($groups as $type => $label): ?>
  <?php if (empty($targets[$type])) { continue; } ?>

  <h2><?= e($label) ?> <small><?= e(fa((string) count($targets[$type]))) ?></small></h2>

  <ul class="tgt">
    <?php foreach ($targets[$type] as $t): ?>
      <?php
        $c    = $counts[$type][(int) $t['id']] ?? [];
        $prof = (int) ($c['profile'] ?? 0);
        $gal  = (int) ($c['gallery'] ?? 0);
      ?>
      <li>
        <a href="/admin/?p=entity&amp;type=<?= e($type) ?>&amp;id=<?= (int) $t['id'] ?>">
          <span class="nm"><?= e($t['label']) ?></span>
          <span class="cnt">
            <?php if ($prof > 0): ?>
              <b class="ok"><?= e(fa((string) $prof)) ?> پروفایل</b>
            <?php else: ?>
              <b class="none">بدون پروفایل</b>
            <?php endif; ?>
            <?php if ($gal > 0): ?>
              <b><?= e(fa((string) $gal)) ?> گالری</b>
            <?php endif; ?>
          </span>
        </a>
      </li>
    <?php endforeach; ?>
  </ul>
<?php endforeach; ?>
