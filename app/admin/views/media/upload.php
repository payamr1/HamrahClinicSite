<?php
/** @var Auth $auth @var ?string $error @var array $targets */
?>
<div class="head">
  <h1>بارگذاری رسانه</h1>
  <a class="b ghost" href="/admin/?p=media">بازگشت به کتابخانه</a>
</div>

<?php if ($error): ?>
  <p class="note bad"><?= e($error) ?></p>
<?php endif; ?>

<form class="form two" method="post" action="/admin/?p=media/upload" enctype="multipart/form-data">
  <input type="hidden" name="csrf" value="<?= e($auth->csrf()) ?>">

  <div class="col">
    <fieldset>
      <legend>فایل</legend>

      <?php
        /*
         * سقف واقعی را خود سرور تعیین می‌کند و معمولاً از سقف ما
         * کمتر است. نشان دادن عدد درست، از شکست بی‌توضیح روی یک
         * فایل بزرگ جلوتر است.
         */
        $toBytes = static function (string $v): int {
            $n = (int) $v;
            return match (strtolower(substr(trim($v), -1))) {
                'g' => $n * 1024 ** 3,
                'm' => $n * 1024 ** 2,
                'k' => $n * 1024,
                default => $n,
            };
        };
        $limit = min(array_filter([
            $toBytes((string) ini_get('upload_max_filesize')),
            $toBytes((string) ini_get('post_max_size')),
        ]) ?: [Media::MAX_VIDEO]);
        $limitMb = max(1, (int) floor($limit / 1024 / 1024));
      ?>

      <label class="drop">
        <input type="file" name="files[]" multiple
               accept="image/jpeg,image/png,image/webp,video/mp4,video/webm">
        <span>
          <b>فایل‌ها را اینجا رها کنید یا کلیک کنید</b>
          <small>
            JPG، PNG، WebP، MP4 یا WebM ·
            سقف این سرور <?= e(fa((string) $limitMb)) ?> مگابایت برای هر فایل ·
            می‌توانید چند فایل را با هم انتخاب کنید
          </small>
        </span>
      </label>

      <p class="fine">
        عکس‌ها پیش از ذخیره خودشان آماده می‌شوند: اگر بزرگ‌تر از
        ۲۴۰۰ پیکسل باشند کوچک می‌شوند، چرخش عکس موبایل اصلاح
        می‌شود، و دوباره فشرده می‌شوند. اطلاعات EXIF هم پاک
        می‌شود — عکس موبایل مختصات جغرافیایی با خودش دارد و آن
        نباید روی سایت عمومی برود.
      </p>

      <div class="or">یا</div>

      <label>
        <span>نشانی ویدیوی آپارات یا یوتیوب</span>
        <input name="embed_url" dir="ltr" placeholder="https://www.aparat.com/v/…">
        <small>
          برای ویدیوی بلند این راه بهتر است: فایل روی هاست شما جا
          نمی‌گیرد و پخشش هم سریع‌تر است.
        </small>
      </label>
    </fieldset>

    <fieldset>
      <legend>توضیح</legend>

      <label>
        <span>عنوان</span>
        <input name="title" maxlength="200" placeholder="مثلاً: اتاق شیمی‌درمانی">
      </label>

      <label>
        <span>متن جایگزین تصویر</span>
        <input name="alt" maxlength="255" placeholder="آنچه در عکس دیده می‌شود">
        <small>
          این متن را گوگل می‌خواند و کاربر نابینا می‌شنود. یک جمله‌ی
          توصیفی بنویسید، نه فهرستی از کلمه‌ی کلیدی.
        </small>
      </label>

      <label>
        <span>توضیح</span>
        <textarea name="description" rows="4"></textarea>
      </label>

      <label>
        <span>تاریخ ثبت</span>
        <input type="date" name="taken_on" dir="ltr">
        <small>اختیاری. تاریخ بارگذاری جداگانه ذخیره می‌شود.</small>
      </label>
    </fieldset>
  </div>

  <div class="col">
    <?php $current = []; $kind = 'image'; require __DIR__ . '/_tags.php'; ?>
  </div>

  <div class="actions">
    <button class="b" type="submit">بارگذاری</button>
  </div>
</form>

<script src="<?= e(asset('/assets/js/admin.js')) ?>" defer></script>
