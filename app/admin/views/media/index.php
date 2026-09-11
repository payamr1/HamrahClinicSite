<?php
/** @var array $items @var array $filter @var int $total @var int $page @var int $pages @var ?array $flash */
$qs = function (array $over = []) use ($filter, $page): string {
    $q = array_filter([
        'p'        => 'media',
        'kind'     => $filter['kind'],
        'q'        => $filter['q'],
        'untagged' => $filter['untagged'] ? 1 : null,
        'page'     => $page > 1 ? $page : null,
    ], fn($v) => $v !== null && $v !== '');
    return '/admin/?' . http_build_query(array_filter(array_merge($q, $over), fn($v) => $v !== null && $v !== ''));
};
?>
<?php if (!empty($flash)): ?>
  <p class="note ok"><?= e($flash['msg']) ?></p>
<?php endif; ?>

<div class="head">
  <h1>کتابخانه‌ی رسانه <small><?= e(fa((string) $total)) ?> فایل</small></h1>
  <a class="b" href="/admin/?p=media/upload">بارگذاری رسانه</a>
</div>

<form class="filters" method="get" action="/admin/">
  <input type="hidden" name="p" value="media">
  <input type="search" name="q" value="<?= e((string) $filter['q']) ?>" placeholder="جست‌وجو در عنوان و توضیح…">
  <select name="kind">
    <option value="">همه</option>
    <option value="image" <?= $filter['kind'] === 'image' ? 'selected' : '' ?>>عکس</option>
    <option value="video" <?= $filter['kind'] === 'video' ? 'selected' : '' ?>>ویدیو</option>
  </select>
  <label class="chk">
    <input type="checkbox" name="untagged" value="1" <?= $filter['untagged'] ? 'checked' : '' ?>>
    فقط بدون تگ
  </label>
  <button class="b ghost" type="submit">فیلتر</button>
  <?php if ($filter['q'] || $filter['kind'] || $filter['untagged']): ?>
    <a class="clear" href="/admin/?p=media">برداشتن فیلترها</a>
  <?php endif; ?>
</form>

<?php if ($items === []): ?>
  <div class="empty">
    <p>فایلی با این شرط پیدا نشد.</p>
  </div>
<?php else: ?>
  <div class="grid">
    <?php foreach ($items as $m): ?>
      <?php require __DIR__ . '/_card.php'; ?>
    <?php endforeach; ?>
  </div>

  <?php if ($pages > 1): ?>
    <nav class="pager">
      <?php for ($i = 1; $i <= $pages; $i++): ?>
        <a class="<?= $i === $page ? 'on' : '' ?>" href="<?= e($qs(['page' => $i > 1 ? $i : null])) ?>"><?= e(fa((string) $i)) ?></a>
      <?php endfor; ?>
    </nav>
  <?php endif; ?>
<?php endif; ?>
