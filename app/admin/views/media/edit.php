<?php
/** @var Auth $auth @var array $m @var array $tags @var array $targets @var ?array $flash @var array $app */
$media   = $app['media'];
$isVideo = $m['kind'] === 'video';
$embed   = !empty($m['embed_url']);
?>
<div class="head">
  <h1>ویرایش رسانه</h1>
  <a class="b ghost" href="/admin/?p=media">بازگشت به کتابخانه</a>
</div>

<?php if (!empty($flash)): ?>
  <p class="note ok"><?= e($flash['msg']) ?></p>
<?php endif; ?>

<form class="form two" method="post" action="/admin/?p=media/edit&amp;id=<?= (int) $m['id'] ?>">
  <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">

  <div class="col">
    <div class="preview">
      <?php if (!$isVideo): ?>
        <img src="<?= e(img($media->imagePath($m), 900)) ?>" alt="<?= e((string) $m['alt']) ?>">
      <?php elseif ($embed): ?>
        <p class="vbox embed">
          <a href="<?= e((string) $m['embed_url']) ?>" target="_blank" rel="noopener" dir="ltr">
            <?= e((string) $m['embed_url']) ?>
          </a>
        </p>
      <?php else: ?>
        <video controls preload="metadata" src="<?= e($media->url($m)) ?>"></video>
      <?php endif; ?>

      <dl class="meta">
        <div><dt>نوع</dt><dd><?= $isVideo ? 'ویدیو' : 'عکس' ?></dd></div>
        <?php if (!empty($m['width'])): ?>
          <div><dt>ابعاد</dt><dd dir="ltr"><?= (int) $m['width'] ?> × <?= (int) $m['height'] ?></dd></div>
        <?php endif; ?>
        <?php if (!empty($m['bytes'])): ?>
          <div><dt>حجم</dt><dd><?= e(fa((string) (int) round($m['bytes'] / 1024))) ?> کیلوبایت</dd></div>
        <?php endif; ?>
        <div><dt>بارگذاری</dt><dd><?= e(jdate((string) $m['created_at'])) ?></dd></div>
        <?php if (!empty($m['filename'])): ?>
          <div><dt>فایل</dt><dd dir="ltr" class="path"><?= e((string) $m['filename']) ?></dd></div>
        <?php endif; ?>
      </dl>
    </div>

    <fieldset>
      <legend>توضیح</legend>

      <label>
        <span>عنوان</span>
        <input name="title" maxlength="200" value="<?= e((string) $m['title']) ?>">
      </label>

      <?php if (!$isVideo): ?>
      <label>
        <span>متن جایگزین تصویر</span>
        <input name="alt" maxlength="255" value="<?= e((string) $m['alt']) ?>">
        <small>این متن را گوگل می‌خواند و کاربر نابینا می‌شنود.</small>
      </label>
      <?php endif; ?>

      <label>
        <span>توضیح</span>
        <textarea name="description" rows="4"><?= e((string) $m['description']) ?></textarea>
      </label>

      <div class="row">
        <label>
          <span>تاریخ ثبت</span>
          <input type="date" name="taken_on" dir="ltr" value="<?= e((string) $m['taken_on']) ?>">
        </label>
        <label>
          <span>ترتیب</span>
          <input type="number" name="sort" dir="ltr" value="<?= (int) $m['sort'] ?>">
          <small>عدد کوچک‌تر جلوتر می‌آید.</small>
        </label>
      </div>

      <label class="chk">
        <input type="checkbox" name="is_active" value="1" <?= !empty($m['is_active']) ? 'checked' : '' ?>>
        در سایت نمایش داده شود
      </label>
    </fieldset>
  </div>

  <div class="col">
    <?php $current = $tags; $kind = $m['kind']; require __DIR__ . '/_tags.php'; ?>
  </div>

  <div class="actions">
    <button class="b" type="submit">ذخیره</button>
    <button class="b danger" type="submit" name="delete" value="1"
            data-confirm="این فایل و همه‌ی تگ‌هایش برای همیشه حذف می‌شود. مطمئنید؟">
      حذف فایل
    </button>
  </div>
</form>

<script src="<?= e(asset('/assets/js/admin.js')) ?>" defer></script>
