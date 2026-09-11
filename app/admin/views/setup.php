<?php
/** @var Auth $auth @var ?string $error */
?>
<div class="card auth">
  <img class="logo" src="/assets/img/brand/logo.png" alt="همراه کلینیک" width="160" height="61">
  <h1>ساخت حساب مدیر</h1>

  <p class="note">
    هنوز هیچ حسابی وجود ندارد. نام کاربری و رمزی که اینجا می‌سازید
    فقط در دست خودتان است — رمز به شکل هش ذخیره می‌شود و هیچ‌جا
    قابل بازیابی نیست. این صفحه بعد از ساخت اولین حساب بسته می‌شود.
  </p>

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
      <span>نام کاربری</span>
      <input name="username" dir="ltr" autocomplete="username" required
             pattern="[a-zA-Z0-9_.\-]{3,60}">
      <small>حروف لاتین، عدد، نقطه یا خط تیره</small>
    </label>

    <label>
      <span>رمز عبور</span>
      <input type="password" name="password" dir="ltr" autocomplete="new-password"
             minlength="12" required>
      <small>دست‌کم ۱۲ نویسه. یک عبارت چندکلمه‌ای هم امن‌تر است و هم به یاد می‌ماند.</small>
    </label>

    <button class="b" type="submit">ساخت حساب</button>
  </form>
</div>
