<?php
/** @var Auth $auth @var array $user @var ?string $error @var ?array $flash @var array $admins */
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
      <div><dt>موبایل</dt><dd dir="ltr"><?= e(fa((string) $user['phone'])) ?></dd></div>
      <div><dt>نقش</dt><dd><?= $user['role'] === 'owner' ? 'مدیر' : 'ویرایشگر' ?></dd></div>
      <?php if (!empty($user['last_login_at'])): ?>
        <div><dt>ورود پیشین</dt><dd><?= e(jdate((string) $user['last_login_at'])) ?></dd></div>
      <?php endif; ?>
    </dl>
    <p class="fine">
      ورود به پنل فقط با کد پیامکی است و رمز عبوری وجود ندارد، پس
      چیزی برای عوض کردن نیست. اگر شماره‌تان عوض شد، مدیر دیگری
      باید شماره‌ی تازه را اضافه کند.
    </p>
  </fieldset>

  <fieldset>
    <legend>مدیران پنل</legend>
    <ul class="tgt">
      <?php foreach ($admins as $a): ?>
        <li>
          <a href="#" onclick="return false" style="cursor:default">
            <span class="nm">
              <?= e($a['name']) ?>
              <small dir="ltr" style="color:var(--ink-3)"><?= e(fa((string) $a['phone'])) ?></small>
            </span>
            <span class="cnt">
              <b class="<?= $a['role'] === 'owner' ? 'ok' : '' ?>">
                <?= $a['role'] === 'owner' ? 'مدیر' : 'ویرایشگر' ?>
              </b>
              <?php if (empty($a['is_active'])): ?><b class="none">غیرفعال</b><?php endif; ?>
            </span>
          </a>
        </li>
      <?php endforeach; ?>
    </ul>
  </fieldset>

  <?php if ($user['role'] === 'owner'): ?>
  <form method="post" action="/admin/?p=account">
    <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">
    <fieldset>
      <legend>افزودن مدیر</legend>

      <label>
        <span>نام و نام خانوادگی</span>
        <input name="name" required>
      </label>

      <label>
        <span>شماره‌ی موبایل</span>
        <input name="phone" dir="ltr" inputmode="numeric" placeholder="۰۹۱۲۱۲۳۴۵۶۷" required>
      </label>

      <label>
        <span>نقش</span>
        <select name="role">
          <option value="editor">ویرایشگر</option>
          <option value="owner">مدیر</option>
        </select>
      </label>

      <button class="b" type="submit">افزودن</button>
    </fieldset>
  </form>
  <?php endif; ?>
</div>
