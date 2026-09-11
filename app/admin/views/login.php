<?php
/**
 * ورود دو مرحله‌ای: شماره → کد پیامکی.
 *
 * @var Auth    $auth
 * @var ?string $error
 * @var ?array  $flash
 * @var string  $step   phone | code
 * @var string  $phone
 * @var int     $wait   ثانیه تا اجازه‌ی ارسال دوباره
 * @var bool    $smsOk
 * @var string  $smsHint
 */
?>
<div class="card auth">
  <img class="logo" src="/assets/img/brand/logo.png" alt="همراه کلینیک" width="160" height="61">

  <?php if ($step === 'phone'): ?>

    <h1>ورود به پنل</h1>
    <p class="sub">شماره‌ی موبایلتان را وارد کنید تا کد ورود پیامک شود.</p>

    <?php if (!empty($flash)): ?><p class="note ok"><?= e($flash['msg']) ?></p><?php endif; ?>
    <?php if ($error): ?><p class="note bad"><?= e($error) ?></p><?php endif; ?>
    <?php if (!$smsOk): ?>
      <p class="note warn">سرویس پیامک تنظیم نشده است. <?= e($smsHint) ?></p>
    <?php endif; ?>

    <form method="post" action="/admin/">
      <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
      <input type="hidden" name="step" value="phone">

      <label>
        <span>شماره‌ی موبایل</span>
        <input name="phone" dir="ltr" inputmode="numeric" autocomplete="tel"
               placeholder="۰۹۱۲۱۲۳۴۵۶۷" required autofocus>
      </label>

      <button class="b" type="submit">فرستادن کد</button>
    </form>

    <p class="fine">
      فقط شماره‌هایی که در پنل ثبت شده‌اند کد می‌گیرند.
    </p>

  <?php else: ?>

    <h1>کد را وارد کنید</h1>
    <p class="sub">
      کد شش‌رقمی به <b dir="ltr"><?= e(fa(Sms::maskPhone($phone))) ?></b> فرستاده شد.
      تا سه دقیقه معتبر است.
    </p>

    <?php if ($error): ?><p class="note bad"><?= e($error) ?></p><?php endif; ?>

    <form method="post" action="/admin/">
      <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
      <input type="hidden" name="step" value="code">

      <label>
        <span>کد ورود</span>
        <input class="otp" name="code" dir="ltr" inputmode="numeric"
               autocomplete="one-time-code" pattern="[0-9۰-۹]{6}"
               maxlength="6" required autofocus>
      </label>

      <button class="b" type="submit">ورود</button>
    </form>

    <form class="again" method="post" action="/admin/">
      <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
      <input type="hidden" name="step" value="phone">
      <input type="hidden" name="phone" value="<?= e($phone) ?>">
      <button type="submit" class="link" <?= $wait > 0 ? 'disabled data-wait="' . (int) $wait . '"' : '' ?>>
        <?= $wait > 0 ? 'ارسال دوباره تا ' . e(fa((string) $wait)) . ' ثانیه' : 'ارسال دوباره‌ی کد' ?>
      </button>
    </form>

    <form method="post" action="/admin/">
      <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
      <input type="hidden" name="step" value="back">
      <button type="submit" class="link quiet">شماره‌ی دیگری وارد می‌کنم</button>
    </form>

  <?php endif; ?>
</div>

<script src="<?= e(asset('/assets/js/admin.js')) ?>" defer></script>
