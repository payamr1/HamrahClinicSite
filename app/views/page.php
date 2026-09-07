<?php
/** قالب عمومی — برای صفحات ثابت و هر نوعی که قالب اختصاصی ندارد */
/** @var Seo $seo */
ob_start(); ?>

<header class="phead">
  <div class="pic" aria-hidden="true"></div>
  <div class="veil" aria-hidden="true"></div>
  <div class="in">
    <?php if (!empty($page['kicker'])): ?>
      <p class="kick"><?= e($page['kicker']) ?></p>
    <?php endif; ?>
    <h1><?= e($page['title']) ?></h1>
    <?php if (!empty($page['lede'])): ?>
      <p class="lede"><?= e($page['lede']) ?></p>
    <?php endif; ?>
  </div>
</header>

<div class="in">
  <article class="prose">
    <?php if (!empty($page['body'])): ?>
      <?= $page['body'] ?>
    <?php else: ?>
      <div class="empty-note">
        <p><b>این صفحه هنوز محتوا ندارد.</b></p>
        <p>مسیر و متای سئوی آن ثبت شده است؛ متن از پنل مدیریت اضافه می‌شود.</p>
        <dl class="kv">
          <div><dt>مسیر</dt><dd dir="ltr"><?= e($page['path']) ?></dd></div>
          <div><dt>نوع</dt><dd><?= e($page['type']) ?></dd></div>
          <div><dt>عنوان سئو</dt><dd><?= e($page['meta_title']) ?></dd></div>
          <div><dt>توضیحات سئو</dt><dd><?= e($page['meta_desc']) ?></dd></div>
        </dl>
      </div>
    <?php endif; ?>
  </article>
</div>

<?php
$content = ob_get_clean();
$trail   = [$page['title'] => null];
require __DIR__ . '/layout.php';
