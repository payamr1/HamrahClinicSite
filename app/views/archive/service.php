<?php
/** آرشیو خدمات — فهرست ۹ کلینیک و خدمات هرکدام */
/** @var Repository $repo */
/** @var Seo $seo */
$clinics = $repo->clinics();
ob_start(); ?>

<header class="phead">
  <div class="pic" style="background-image:url('<?= e(asset('/assets/img/hero-reception.jpg')) ?>')" aria-hidden="true"></div>
  <div class="veil" aria-hidden="true"></div>
  <div class="in">
    <p class="kick">کلینیک‌های تخصصی</p>
    <h1><?= e($page['title']) ?></h1>
    <p class="lede"><?= e($page['meta_desc']) ?></p>
  </div>
</header>

<?php foreach ($clinics as $c):
  $svc = $repo->servicesOfClinic((int) $c['id'], 24);
  if ($svc === [] && empty($c['page_path'])) { continue; } ?>
  <section class="sec<?= empty($alt) ? '' : ' alt' ?>"><div class="in">
    <?php $alt = empty($alt); ?>
    <div class="shead">
      <?php if (!empty($c['tagline'])): ?><span class="lbl"><?= e($c['tagline']) ?></span><?php endif; ?>
      <h2><?php if (!empty($c['page_path'])): ?><a href="<?= url($c['page_path']) ?>"><?= e($c['name']) ?></a><?php else: ?><?= e($c['name']) ?><?php endif; ?></h2>
      <?php if (!empty($c['summary'])): ?><p><?= e($c['summary']) ?></p><?php endif; ?>
    </div>
    <?php if ($svc !== []): ?>
    <div class="cgrid">
      <?php foreach ($svc as $s): ?>
        <a class="card" href="<?= url($s['path']) ?>"><span class="bd">
          <h3><?= e($s['title']) ?></h3>
          <p><?= e(excerpt($s['lede'] ?: $s['meta_desc'], 100)) ?></p>
          <span class="ft"><span class="cnt"></span><span class="go">مشاهده ←</span></span>
        </span></a>
      <?php endforeach; ?>
    </div>
    <?php endif; ?>
  </div></section>
<?php endforeach; ?>

<?php
$content = ob_get_clean();
$trail   = [$page['title'] => null];
$schema  = [['@type' => 'CollectionPage', 'name' => $page['title'], 'url' => $seo->canonicalUrl($page)]];
require __DIR__ . '/../layout.php';
