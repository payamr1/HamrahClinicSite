<?php
/**
 * قالب پنل.
 *
 * ‎$content از پیش ساخته شده و اینجا فقط جاسازی می‌شود.
 * ‎$user وقتی خالی است که هنوز وارد نشده‌ایم (ورود و راه‌اندازی).
 *
 * @var string      $content
 * @var string      $title
 * @var array|null  $user
 * @var Auth        $auth
 * @var array       $app
 */
$u   = $user ?? null;
$nav = [
    ''        => ['میزکار',            'M3 11l9-8 9 8v10H3z'],
    'media'   => ['کتابخانه‌ی رسانه',  'M4 5h16v14H4zM8 9h.01M4 16l4-4 3 3 4-4 5 5'],
    'targets' => ['پزشکان و بخش‌ها',   'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm-8 8c0-3 4-5 8-5s8 2 8 5'],
];
?>
<!doctype html>
<html lang="fa" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow, noarchive">
<title><?= e($title ?? 'پنل') ?> · پنل همراه کلینیک</title>
<link rel="icon" href="/assets/img/brand/mark.jpg" type="image/jpeg">
<link rel="preload" href="<?= e(asset('/assets/fonts/NarengiVF.woff2')) ?>"
      as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="<?= e(asset('/assets/css/admin.css')) ?>">
</head>
<body class="<?= $u ? '' : 'plain' ?>">

<?php if ($u): ?>
<header class="top">
  <a class="brand" href="/admin/">
    <img src="/assets/img/brand/mark.jpg" alt="" width="28" height="28">
    <span>پنل همراه کلینیک</span>
  </a>

  <nav class="nav">
    <?php foreach ($nav as $key => [$label, $d]): ?>
      <?php $on = ($_GET['p'] ?? '') === $key || (($_GET['p'] ?? '') !== '' && $key !== '' && str_starts_with((string) ($_GET['p'] ?? ''), $key)); ?>
      <a class="<?= $on ? 'on' : '' ?>" href="/admin/<?= $key === '' ? '' : '?p=' . $key ?>">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="<?= e($d) ?>"/></svg>
        <?= e($label) ?>
      </a>
    <?php endforeach; ?>
  </nav>

  <div class="me">
    <a class="site" href="/" target="_blank" rel="noopener">دیدن سایت ↗</a>
    <a href="/admin/?p=account"><?= e($u['name']) ?></a>
    <form method="post" action="/admin/?p=logout">
      <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
      <button type="submit">خروج</button>
    </form>
  </div>
</header>
<?php endif; ?>

<?php if (!empty($app['sms']) && $app['sms']->isEmergencyMode()): ?>
  <p class="emerg">
    حالت اضطراری ورود روشن است — کد ورود به‌جای پیامک در لاگ سرور
    نوشته می‌شود. بعد از ورود، <code>emergency_log_code</code> را در
    <code>config.php</code> دوباره <code>false</code> کنید.
  </p>
<?php endif; ?>

<main class="<?= $u ? 'wrap' : 'centre' ?>">
  <?= $content ?>
</main>

</body>
</html>
