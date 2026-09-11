<?php
/** @var Auth $auth @var ?string $error @var bool $smsOk @var string $smsHint */
?>
<div class="card auth">
  <img class="logo" src="/assets/img/brand/logo.png" alt="همراه کلینیک" width="160" height="61">
  <h1>ساخت حساب مدیر</h1>

  <p class="note">
    هنوز هیچ حسابی وجود ندارد. شماره‌ای که اینجا وارد می‌کنید از این
    پس تنها راه ورود به پنل است — هر بار یک کد شش‌رقمی به همین شماره
    پیامک می‌شود. این صفحه بعد از ساخت اولین حساب بسته می‌شود.
  </p>

  <?php if (!$smsOk): ?>
    <p class="note warn">
      <b>اول سرویس پیامک را تنظیم کنید.</b><br>
      <?= e($smsHint) ?><br>
      اگر حساب را پیش از تنظیم پیامک بسازید، راهی برای ورود نخواهید داشت.
    </p>
  <?php endif; ?>

  <?php if ($error): ?>
    <p class="note bad"><?= e($error) ?></p>
  <?php endif; ?>

  <form method="post" action="/admin/">
    <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">

    <label>
      <span>نام و نام خانوادگی</span>
      <input name="name" required autofocus>
    </label>

    <label>
      <span>شماره‌ی موبایل</span>
      <input name="phone" dir="ltr" inputmode="numeric" autocomplete="tel"
             placeholder="۰۹۱۲۱۲۳۴۵۶۷" required>
      <small>کد ورود همیشه به همین شماره فرستاده می‌شود.</small>
    </label>

    <button class="b" type="submit" <?= $smsOk ? '' : 'disabled' ?>>ساخت حساب</button>
  </form>
</div>
