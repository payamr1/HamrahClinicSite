<?php
/**
 * انتخاب تگ‌ها — قلب این بخش.
 *
 * هر فایل می‌تواند هم‌زمان به چند پزشک، چند بخش و چند صفحه‌ی خدمت
 * تگ بخورد، و برای هرکدام جداگانه مشخص شود که «عکس پروفایل» است
 * یا «گالری». پس نقش روی هر تگ می‌نشیند، نه روی خود فایل.
 *
 * ‎$current تگ‌های فعلی است؛ در فرم بارگذاری خالی می‌آید.
 *
 * @var array  $targets   ['doctor'=>[], 'clinic'=>[], 'page'=>[]]
 * @var array  $current   ردیف‌های media_tag
 * @var string $kind      image | video
 */
$kind    = $kind ?? 'image';
$current = $current ?? [];

// تگ‌های فعلی را برای جست‌وجوی سریع صاف می‌کنیم
$have = [];
$site = false;
foreach ($current as $t) {
    if ($t['entity_type'] === 'site') {
        $site = true;
        continue;
    }
    $have[$t['entity_type'] . ':' . (int) $t['entity_id']] = $t['role'];
}

$groups = [
    'doctor' => 'پزشکان و همکاران',
    'clinic' => 'بخش‌ها',
    'page'   => 'صفحه‌های خدمات',
];
?>
<fieldset class="tags">
  <legend>این فایل مال کیست؟</legend>

  <p class="fine">
    یک فایل می‌تواند هم‌زمان چند تگ داشته باشد — مثلاً عکسی که سه
    پزشک در آن هستند، به هر سه تگ می‌خورد و در گالری هر سه دیده
    می‌شود.
    <?php if ($kind === 'image'): ?>
      «پروفایل» یعنی همان عکسی که در فهرست‌ها روی کارت می‌آید؛ اگر
      برای یک نفر چند عکس پروفایل بگذارید، نوبتی عوض می‌شوند.
    <?php else: ?>
      ویدیو فقط در گالری می‌نشیند و عکس پروفایل نمی‌شود.
    <?php endif; ?>
  </p>

  <label class="site-tag<?= $site ? ' on' : '' ?>">
    <input type="checkbox" name="tag[]" value="site" <?= $site ? 'checked' : '' ?>>
    <span>
      <b>مال کل کلینیک است</b>
      <small>
        برای عکس ساختمان، پذیرش و تجهیزات — چیزی که به پزشک یا بخش
        خاصی مربوط نیست. هر فایلِ گالری در صفحه‌ی گالری دیده می‌شود،
        این تیک فقط می‌گوید صاحبش کل کلینیک است.
      </small>
    </span>
  </label>

  <input class="tag-filter" type="search" placeholder="جست‌وجوی نام…"
         aria-label="فیلتر فهرست" autocomplete="off">

  <?php foreach ($groups as $type => $label): ?>
    <?php if (empty($targets[$type])) { continue; } ?>
    <div class="tgroup">
      <h4><?= e($label) ?></h4>
      <ul class="tlist">
        <?php foreach ($targets[$type] as $t): ?>
          <?php
            $key  = $type . ':' . (int) $t['id'];
            $role = $have[$key] ?? null;
            $on   = $role !== null;
          ?>
          <li class="trow<?= $on ? ' on' : '' ?>" data-name="<?= e($t['label']) ?>">
            <label class="tpick">
              <input type="checkbox" name="tag[]" value="<?= e($key) ?>" <?= $on ? 'checked' : '' ?>>
              <span><?= e($t['label']) ?></span>
            </label>

            <?php if ($kind === 'image'): ?>
              <span class="roles">
                <label>
                  <input type="radio" name="role[<?= e($key) ?>]" value="gallery"
                         <?= $role !== 'profile' ? 'checked' : '' ?>>
                  گالری
                </label>
                <label>
                  <input type="radio" name="role[<?= e($key) ?>]" value="profile"
                         <?= $role === 'profile' ? 'checked' : '' ?>>
                  پروفایل
                </label>
              </span>
            <?php else: ?>
              <input type="hidden" name="role[<?= e($key) ?>]" value="gallery">
            <?php endif; ?>
          </li>
        <?php endforeach; ?>
      </ul>
    </div>
  <?php endforeach; ?>
</fieldset>
