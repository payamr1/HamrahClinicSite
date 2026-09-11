<?php
/** @var Auth $auth @var array $user @var ?string $error @var ?array $flash */
?>
<div class="head">
  <h1>حساب من</h1>
</div>

<?php if (!empty($flash)): ?>
  <p class="note ok"><?= e($flash['msg']) ?></p>
<?php endif; ?>
<?php if ($error): ?>
  <p class="note bad"><?= e($error) ?></p>
<?php endif; ?>

<div class="form one">
  <fieldset>
    <legend>مشخصات</legend>
    <dl class="meta">
      <div><dt>نام</dt><dd><?= e($user['name']) ?></dd></div>
      <div><dt>نام کاربری</dt><dd dir="ltr"><?= e($user['username']) ?></dd></div>
      <div><dt>نقش</dt><dd><?= $user['role'] === 'owner' ? 'مدیر' : 'ویرایشگر' ?></dd></div>
      <?php if (!empty($user['last_login_at'])): ?>
        <div><dt>ورود پیشین</dt><dd><?= e(jdate((string) $user['last_login_at'])) ?></dd></div>
      <?php endif; ?>
    </dl>
  </fieldset>

  <form method="post" action="/admin/?p=account">
    <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
    <fieldset>
      <legend>تغییر رمز عبور</legend>

      <label>
        <span>رمز فعلی</span>
        <input type="password" name="current" dir="ltr" autocomplete="current-password" required>
      </label>

      <label>
        <span>رمز تازه</span>
        <input type="password" name="new" dir="ltr" autocomplete="new-password" minlength="12" required>
        <small>دست‌کم ۱۲ نویسه.</small>
      </label>

      <button class="b" type="submit">تغییر رمز</button>
    </fieldset>
  </form>
</div>
