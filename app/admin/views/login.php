<?php
/** @var Auth $auth @var ?string $error @var string $r @var ?array $flash */
?>
<div class="card auth">
  <img class="logo" src="/assets/img/brand/logo.png" alt="همراه کلینیک" width="160" height="61">
  <h1>ورود به پنل</h1>

  <?php if (!empty($flash)): ?>
    <p class="note ok"><?= e($flash['msg']) ?></p>
  <?php endif; ?>
  <?php if ($error): ?>
    <p class="note bad"><?= e($error) ?></p>
  <?php endif; ?>

  <form method="post" action="/admin/">
    <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
    <input type="hidden" name="r" value="<?= e($r) ?>">

    <label>
      <span>نام کاربری</span>
      <input name="username" autocomplete="username" dir="ltr" required autofocus>
    </label>

    <label>
      <span>رمز عبور</span>
      <input type="password" name="password" autocomplete="current-password" dir="ltr" required>
    </label>

    <button class="b" type="submit">ورود</button>
  </form>

  <p class="fine">
    پس از پنج تلاش ناموفق، ورود برای پانزده دقیقه بسته می‌شود.
  </p>
</div>
