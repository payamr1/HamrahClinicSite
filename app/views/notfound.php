<?php
/** ۴۰۴ */
ob_start(); ?>

<div class="in">
  <section class="nf">
    <p class="code">۴۰۴</p>
    <h1>این صفحه پیدا نشد</h1>
    <p class="lede">آدرسی که دنبالش بودید وجود ندارد یا جابه‌جا شده است.</p>
    <div class="nf-acts">
      <a class="b b-teal" href="/">صفحه‌ی اصلی</a>
      <a class="b b-out" href="<?= url('/service/') ?>">فهرست کلینیک‌ها</a>
      <a class="b b-out" href="<?= url('/contact-us/') ?>">تماس با ما</a>
    </div>
  </section>
</div>

<?php
$content = ob_get_clean();
$trail   = [];
require __DIR__ . '/layout.php';
