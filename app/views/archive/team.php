<?php
/** آرشیو پزشکان */
/** @var Repository $repo */
/** @var Seo $seo */
$doctors = $repo->doctors(40);
ob_start(); ?>

<header class="phead">
  <div class="pic" style="background-image:url('<?= e(asset('/assets/img/hero-reception.jpg')) ?>')" aria-hidden="true"></div>
  <div class="veil" aria-hidden="true"></div>
  <div class="in">
    <p class="kick">تیم درمان</p>
    <h1><?= e($page['title']) ?></h1>
    <p class="lede"><?= e($page['meta_desc']) ?></p>
  </div>
</header>

<section class="sec"><div class="in">
  <div class="dgrid">
    <?php foreach ($doctors as $d): ?>
      <a class="doc" href="<?= url($d['path'] ?? '/team/') ?>">
        <span class="ph<?= empty($d['photo']) ? ' ph-empty' : '' ?>"
          <?php if (!empty($d['photo'])): ?>style="background-image:url('<?= e(asset('/assets/img/' . $d['photo'])) ?>')"<?php endif; ?>></span>
        <span class="bd">
          <h3><?= e($d['name']) ?></h3>
          <span class="sp"><?= e($d['specialty']) ?></span>
          <?php if (!empty($d['fellowship'])): ?><span class="sub"><?= e(excerpt($d['fellowship'], 70)) ?></span><?php endif; ?>
          <?php if (!empty($d['license_no'])): ?><span class="no">نظام پزشکی <?= e(fa($d['license_no'])) ?></span><?php endif; ?>
        </span>
      </a>
    <?php endforeach; ?>
  </div>
</div></section>

<?php
$content = ob_get_clean();
$trail   = [$page['title'] => null];
$schema  = [['@type' => 'CollectionPage', 'name' => $page['title'], 'url' => $seo->canonicalUrl($page)]];
foreach ($doctors as $d) { $schema[] = $seo->physicianSchema($d); }
require __DIR__ . '/../layout.php';
