<?php
/** آرشیو مقالات */
/** @var Repository $repo */
/** @var Seo $seo */
$posts = $repo->posts(30);
ob_start(); ?>

<header class="phead light">
  <div class="in">
    <p class="kick">بلاگ سلامت</p>
    <h1><?= e($page['title']) ?></h1>
    <p class="lede"><?= e($page['meta_desc']) ?></p>
  </div>
</header>

<section class="sec"><div class="in">
  <div class="agrid">
    <?php foreach ($posts as $p): ?>
      <a class="art-c" href="<?= url($p['path']) ?>">
        <span class="ph<?= empty($p['hero_image']) ? ' ph-empty' : '' ?>"
          <?php if (!empty($p['hero_image'])): ?>style="background-image:url('<?= e(img($p['hero_image'], 400)) ?>')"<?php endif; ?>></span>
        <span class="bd">
          <h3><?= e($p['title']) ?></h3>
          <span class="dt">
            <?php if (!empty($p['author_name'])): ?><?= e($p['author_name']) ?> · <?php endif; ?>
            <?= e(jdate($p['published_at'])) ?>
          </span>
        </span>
      </a>
    <?php endforeach; ?>
  </div>
</div></section>

<?php
$content = ob_get_clean();
$trail   = [$page['title'] => null];
$schema  = [['@type' => 'Blog', 'name' => $page['title'], 'url' => $seo->canonicalUrl($page)]];
require __DIR__ . '/../layout.php';
