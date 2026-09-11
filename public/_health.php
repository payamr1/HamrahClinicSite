<?php
declare(strict_types=1);

/**
 * صفحه‌ی بررسی سلامت استقرار.
 *
 * بعد از هر deploy این آدرس را باز کنید:
 *   https://new.hamrahclinic.ir/_health.php
 *
 * هفت چیز را می‌سنجد: نسخه‌ی PHP، افزونه‌های لازم، وجود config،
 * اتصال دیتابیس، ساخته شدن جدول‌ها، تعداد ۸۲ آدرس، و اینکه
 * noindex واقعاً فعال است.
 *
 * پیش از انتشار نهایی این فایل را حذف کنید.
 */

header('Content-Type: text/html; charset=utf-8');
header('X-Robots-Tag: noindex, nofollow');

$checks = [];
$add = function (string $name, bool $ok, string $detail = '', bool $warn = false) use (&$checks): void {
    $checks[] = ['name' => $name, 'ok' => $ok, 'warn' => $warn, 'detail' => $detail];
};

// ---- ۱. PHP ---------------------------------------------------
$phpOk = version_compare(PHP_VERSION, '8.0.0', '>=');
$add('نسخه‌ی PHP', $phpOk, PHP_VERSION . ($phpOk ? '' : ' — حداقل ۸.۰ لازم است'));

// ---- ۲. افزونه‌ها ----------------------------------------------
foreach (['pdo_mysql' => 'اتصال دیتابیس', 'mbstring' => 'متن فارسی', 'json' => 'اسکیما'] as $ext => $why) {
    $add("افزونه‌ی $ext", extension_loaded($ext), $why);
}

// ---- ۳. پوشه‌ی برنامه و config ----------------------------------
$appRoot = dirname(__DIR__) . '/hamrah-app';
if (!is_dir($appRoot)) {
    $appRoot = dirname(__DIR__);
}
$add('پوشه‌ی برنامه', is_dir($appRoot . '/app'), $appRoot . '/app');

$configFile = $appRoot . '/config.php';
$hasConfig  = is_file($configFile);
$add('فایل config.php', $hasConfig, $hasConfig ? $configFile : 'کپی از config.php.example و پر کردن رمز دیتابیس');

// ---- ۴. دیتابیس ------------------------------------------------
$db = null; $config = [];
if ($hasConfig) {
    $config = require $configFile;
    try {
        $dsn = sprintf('mysql:host=%s;dbname=%s;charset=%s',
            $config['db']['host'], $config['db']['name'], $config['db']['charset'] ?? 'utf8mb4');
        $db = new PDO($dsn, $config['db']['user'], $config['db']['pass'], [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]);
        $add('اتصال دیتابیس', true, $config['db']['name']);
    } catch (Throwable $e) {
        // در خطای دسترسی، دقیقاً نشان بده چه چیزی امتحان شده —
        // معمولاً یکی از این سه: پیشوند اکانت جا افتاده، کاربر به
        // دیتابیس وصل نشده، یا رمز کاراکتر خاصی دارد که رشته‌ی PHP
        // را می‌شکند.
        $u = (string) ($config['db']['user'] ?? '');
        $n = (string) ($config['db']['name'] ?? '');
        $p = (string) ($config['db']['pass'] ?? '');
        $hint = sprintf('کاربر=%s | دیتابیس=%s | طول رمز=%d', $u ?: '(خالی)', $n ?: '(خالی)', strlen($p));

        $flags = [];
        $prefix = explode('_', $u)[0] ?? '';
        if ($u !== '' && !str_contains($u, '_'))                 { $flags[] = 'نام کاربر پیشوند اکانت ندارد'; }
        if ($n !== '' && !str_contains($n, '_'))                 { $flags[] = 'نام دیتابیس پیشوند اکانت ندارد'; }
        if ($p === '')                                           { $flags[] = 'رمز خالی است'; }
        if ($p !== '' && trim($p) !== $p)                        { $flags[] = 'رمز فاصله‌ی اضافه دارد'; }
        // بدون escape نوشته شده تا خودِ همین خط قربانی همان مشکلی
        // که تشخیص می‌دهد نشود
        $risky = chr(39) . chr(34) . chr(92);   // یک‌نقل‌قول، دونقل‌قول، بک‌اسلش
        if ($p !== '' && strpbrk($p, $risky) !== false) {
            $flags[] = 'رمز کاراکتر نقل‌قول یا بک‌اسلش دارد و رشته‌ی PHP را می‌شکند';
        }
        if ($u !== '' && $n !== '' && $prefix !== '' && !str_starts_with($n, $prefix)) {
            $flags[] = 'پیشوند کاربر و دیتابیس یکی نیست';
        }

        $add('اتصال دیتابیس', false,
            $e->getMessage() . ' — ' . $hint . ($flags ? ' ⟵ ' . implode(' · ', $flags) : ''));
    }
}

// ---- ۵. جدول‌ها و داده --------------------------------------------
$pageCount = null;
if ($db instanceof PDO) {
    $want  = ['pages','clinics','doctors','doctor_clinic','page_author','faqs','redirects','not_found_log','media','media_tag','appointments','admin_users','admin_otp','audit_log','settings'];
    $have  = $db->query('SHOW TABLES')->fetchAll(PDO::FETCH_COLUMN) ?: [];
    $miss  = array_values(array_diff($want, $have));
    $add('جدول‌های دیتابیس', $miss === [],
        $miss === [] ? count($have) . ' جدول ساخته شده' : 'ساخته نشده: ' . implode(', ', $miss));

    if (in_array('pages', $have, true)) {
        $pageCount = (int) $db->query('SELECT COUNT(*) FROM pages')->fetchColumn();
        $add('آدرس‌های ثبت‌شده', $pageCount === 82,
            $pageCount . ' از ۸۲' . ($pageCount === 82 ? '' : ' — فایل db/seed/01-pages.sql را اجرا کنید'),
            $pageCount > 0 && $pageCount < 82);

        /*
         * سالم بودن UTF-8 مسیرها.
         *
         * نسخه‌ی قبلی این چک اولین ردیفی را برمی‌داشت که با الگوی
         * لاتین نمی‌خواند و به /service/ (صفحه‌ی آرشیو) می‌رسید که
         * اصلاً حرف فارسی ندارد — پس همیشه رد می‌شد در حالی که
         * داده‌ها سالم بودند.
         *
         * حالا دو مسیر مشخص را مستقیم می‌سنجد. اگر import کاراکترها
         * را خراب کرده باشد، این تطبیق‌ها شکست می‌خورند.
         */
        $st = $db->prepare('SELECT COUNT(*) FROM pages WHERE path = ?');

        $st->execute(['/service/قلب-و-عروق/']);
        $fa = (int) $st->fetchColumn();

        // این یکی با «ك» و «ي» عربی ایندکس شده، نه فارسی
        $st->execute(['/team/دكتر-فاطمه-نائيني/']);
        $ar = (int) $st->fetchColumn();

        $add('سالم بودن مسیر فارسی', $fa === 1,
            $fa === 1 ? '/service/قلب-و-عروق/ پیدا شد' : 'پیدا نشد — کاراکترها هنگام import خراب شده‌اند');

        $add('سالم بودن مسیر با حروف عربی', $ar === 1,
            $ar === 1 ? '/team/دكتر-فاطمه-نائيني/ دست‌نخورده مانده' : 'پیدا نشد — این آدرس ایندکس‌شده از دست می‌رود');
    }
}

// ---- ۵.۲ سرویس پیامک --------------------------------------------
// ورود به پنل فقط با کد پیامکی است، پس بدون این هیچ‌کس نمی‌تواند
// وارد پنل شود — و تا وقتی کسی امتحان نکند، معلوم هم نمی‌شود.
$smsCfg  = $config['sms'] ?? [];
$smsKey  = trim((string) ($smsCfg['api_key'] ?? ''));
$smsTpl  = trim((string) ($smsCfg['template'] ?? ''));
$smsFrom = trim((string) ($smsCfg['sender'] ?? ''));
$smsEmerg = !empty($smsCfg['emergency_log_code']);

$add('کلید کاوه‌نگار', $smsKey !== '',
    $smsKey !== '' ? 'ثبت شده' : 'در config.php ▸ sms ▸ api_key پر نشده');
$add('شماره‌ی خط', $smsFrom !== '' || $smsTpl !== '',
    $smsFrom !== '' ? "ارسال از خط $smsFrom"
                    : ($smsTpl !== '' ? "الگوی وریفای: $smsTpl" : 'در config.php ▸ sms ▸ sender پر نشده'));

// طول متن پیامک — فارسی هر صفحه ۷۰ نویسه، و یک نویسه بیشتر یعنی
// دو برابر هزینه در هر بار ورود
if ($smsFrom !== '' && $smsTpl === '') {
    $appDirH = $appRoot . '/app';
    if (is_file($appDirH . '/Sms.php')) {
        require_once $appDirH . '/Sms.php';
        require_once $appDirH . '/helpers.php';
        $smsObj = new Sms($smsCfg + ['site_name' => 'همراه کلینیک']);
        $prev   = $smsObj->messagePreview();
        $add('طول متن پیامک', $prev['pages'] === 1,
            sprintf('%d نویسه، %d صفحه — «%s»', $prev['length'], $prev['pages'], $prev['text']),
            $prev['pages'] > 1);
    }
}
$add('حالت اضطراری ورود', !$smsEmerg,
    $smsEmerg ? 'روشن است — کد در لاگ نوشته می‌شود، نه پیامک. خاموشش کنید.' : 'خاموش',
    $smsEmerg);
$add('cURL', function_exists('curl_init'), 'برای تماس با کاوه‌نگار', true);

// ---- ۵.۲۵ آزمون اتصال به کاوه‌نگار -------------------------------
// فقط با ?sms=1 اجرا می‌شود. account/info هیچ پیامکی نمی‌فرستد و
// اعتباری خرج نمی‌کند، ولی کل مسیر را می‌سنجد: DNS، TLS، خروجی
// سرور، و درستی خود کلید.
$smsDiag = null;
if (isset($_GET['sms']) && $smsCfg !== [] && is_file($appRoot . '/app/Sms.php')) {
    require_once $appRoot . '/app/Sms.php';
    $smsDiag = (new Sms($smsCfg))->diagnose();

    $anyJson = false;
    foreach ($smsDiag['attempts'] as $at) {
        if ($at['is_json']) { $anyJson = true; }
    }
    $add('رسیدن به API کاوه‌نگار', $anyJson,
        $anyJson ? 'پاسخ معتبر گرفته شد' : 'هیچ پاسخ JSON نیامد — جدول پایین را ببینید');
}

// ---- ۵.۳ تاریخچه‌ی ارسال کد --------------------------------------
// پیام خطای خود کاوه‌نگار در audit_log می‌نشیند. بدون نشان دادنش
// اینجا، برای دیدنش باید لاگ خطای PHP را از File Manager بیرون
// کشید — و کسی که نمی‌تواند وارد پنل شود، وقت این کار را ندارد.
$otpLog = [];
if ($db instanceof PDO) {
    try {
        $q = $db->query(
            "SELECT action, detail, created_at FROM audit_log
              WHERE action LIKE 'otp%' OR action = 'login'
              ORDER BY id DESC LIMIT 8"
        );
        $otpLog = $q ? $q->fetchAll(PDO::FETCH_ASSOC) : [];
    } catch (Throwable) {
        // جدول هنوز نیست
    }

    $lastFail = null;
    foreach ($otpLog as $row) {
        if ($row['action'] === 'otp_send_failed') { $lastFail = $row; break; }
    }
    if ($lastFail !== null) {
        $add('آخرین خطای ارسال', false,
            $lastFail['created_at'] . ' — ' . (string) $lastFail['detail']);
    }
}

// ---- ۵.۵ بهینه‌ساز تصویر ----------------------------------------
// اگر هر یک از این سه شرط برقرار نباشد، img() بی‌صدا آدرس اصلی را
// برمی‌گرداند و عکس‌ها بهینه نمی‌شوند — بدون هیچ خطایی.
$add('افزونه‌ی GD', extension_loaded('gd'), 'ساخت نسخه‌ی کوچک‌شده');
$add('پشتیبانی WebP', function_exists('imagewebp'), 'در صورت نبود، JPEG ساخته می‌شود', true);

$docRoot = rtrim((string) ($_SERVER['DOCUMENT_ROOT'] ?? ''), '/');
$sample  = $docRoot . '/assets/img/doctors/khalili.jpg';
$add('یافتن فایل اصلی تصویر', is_file($sample),
    is_file($sample) ? $sample : 'پیدا نشد: ' . ($sample ?: 'DOCUMENT_ROOT خالی است'));

$cacheDir = $docRoot . '/assets/cache/img';
$canWrite = is_dir($cacheDir)
    ? is_writable($cacheDir)
    : (@mkdir($cacheDir, 0755, true) || is_dir($cacheDir));
$add('نوشتن در پوشه‌ی کش تصویر', $canWrite,
    $canWrite ? $cacheDir : 'قابل ساخت یا نوشتن نیست: ' . $cacheDir);

// ---- ۶. noindex ------------------------------------------------
$env    = $config['env'] ?? 'staging';
$forced = !empty($config['force_noindex']);
$add('محافظت noindex', $env === 'production' ? true : $forced,
    $env === 'production' ? 'محیط production — ایندکس آزاد است'
        : ($forced ? 'فعال — نسخه‌ی آزمایشی ایندکس نمی‌شود' : 'خطر: خاموش است روی محیط آزمایشی'),
    false);

$canon = $config['canonical_host'] ?? '';
$add('دامنه‌ی canonical', $canon === 'hamrahclinic.ir', $canon ?: 'تنظیم نشده');

// ---- ۷. بازنویسی مسیر -------------------------------------------
$add('mod_rewrite', function_exists('apache_get_modules')
    ? in_array('mod_rewrite', apache_get_modules(), true)
    : true,
    function_exists('apache_get_modules') ? '' : 'قابل تشخیص نیست — با باز شدن صفحه‌ی اصلی تأیید می‌شود', true);

$deployed = @file_get_contents(__DIR__ . '/deployed.txt');

$fails = count(array_filter($checks, fn($c) => !$c['ok'] && !$c['warn']));
?><!doctype html>
<html dir="rtl" lang="fa-IR">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex,nofollow">
<title>بررسی سلامت — همراه کلینیک</title>
<style>
  :root{--navy:#24408D;--teal:#4EC3A9;--ok:#1E8570;--bad:#B4322A;--warn:#9A6B0F;
        --ink:#16203F;--ink2:#4A5673;--ink3:#7C88A3;--rule:#DCE3EC;--soft:#F2F5F8}
  *{box-sizing:border-box}
  body{margin:0;background:#fff;color:var(--ink);font:400 15px/1.8 "Segoe UI",Tahoma,sans-serif}
  .wrap{max-width:760px;margin:0 auto;padding:0 20px 60px}
  header{background:var(--navy);color:#fff;padding:30px 0;margin-bottom:26px}
  header .wrap{padding-bottom:0}
  h1{margin:0 0 6px;font-size:26px}
  h2.sub{margin:26px 0 8px;font-size:16px;font-weight:700}
  header p{margin:0;color:#C3CEE6;font-size:14px}
  .banner{border-radius:10px;padding:16px 20px;margin:0 0 24px;font-weight:600}
  .banner.ok{background:#E6F4EE;color:var(--ok);border:1px solid var(--ok)}
  .banner.bad{background:#FBEBE9;color:var(--bad);border:1px solid var(--bad)}
  table{width:100%;border-collapse:collapse;border:1px solid var(--rule);border-radius:10px;overflow:hidden}
  th,td{padding:11px 16px;text-align:right;border-bottom:1px solid var(--rule);font-size:14px;vertical-align:top}
  th{background:var(--soft);font-size:12px;color:var(--ink3);font-weight:600}
  tr:last-child td{border-bottom:none}
  .s{font-weight:700;white-space:nowrap}
  .s.ok{color:var(--ok)} .s.bad{color:var(--bad)} .s.warn{color:var(--warn)}
  td.d{color:var(--ink2);font-size:13px;direction:ltr;text-align:right;word-break:break-word}
  .meta{margin-top:22px;font-size:12.5px;color:var(--ink3);line-height:1.9}
  code{background:var(--soft);padding:2px 6px;border-radius:4px;direction:ltr;display:inline-block}
</style>
<header><div class="wrap">
  <h1>بررسی سلامت استقرار</h1>
  <p>همراه کلینیک · نسخه‌ی آزمایشی</p>
</div></header>
<div class="wrap">

<?php if ($fails === 0): ?>
  <p class="banner ok">همه‌ی بررسی‌های حیاتی قبول شد. سایت آماده‌ی کار است.</p>
<?php else: ?>
  <p class="banner bad"><?= $fails ?> بررسی رد شد. جزئیات را در جدول ببینید.</p>
<?php endif; ?>

<table>
  <tr><th>بررسی</th><th>وضعیت</th><th>جزئیات</th></tr>
  <?php foreach ($checks as $c): ?>
  <tr>
    <td><?= htmlspecialchars($c['name'], ENT_QUOTES, 'UTF-8') ?></td>
    <td class="s <?= $c['ok'] ? 'ok' : ($c['warn'] ? 'warn' : 'bad') ?>">
      <?= $c['ok'] ? 'قبول' : ($c['warn'] ? 'نامعلوم' : 'رد') ?>
    </td>
    <td class="d"><?= htmlspecialchars($c['detail'], ENT_QUOTES, 'UTF-8') ?></td>
  </tr>
  <?php endforeach; ?>
</table>

<?php if ($smsDiag !== null): ?>
<h2 class="sub">آزمون اتصال به کاوه‌نگار</h2>
<table>
  <tr><th>مورد</th><th>مقدار</th></tr>
  <tr><td>طول کلید</td><td class="d"><?= (int) $smsDiag['key_length'] ?> نویسه
    <?= $smsDiag['key_clean'] ? '' : '— ⚠ نویسه‌ی غیرمنتظره دارد' ?></td></tr>
  <tr><td>کلید</td><td class="d"><?= htmlspecialchars($smsDiag['key_preview'], ENT_QUOTES, 'UTF-8') ?></td></tr>
  <tr><td>DNS</td><td class="d">api.kavenegar.com →
    <?= htmlspecialchars($smsDiag['dns'], ENT_QUOTES, 'UTF-8') ?></td></tr>
</table>

<table style="margin-top:12px">
  <tr><th>روش</th><th>HTTP</th><th>پاسخ‌دهنده</th><th>نتیجه</th></tr>
  <?php foreach ($smsDiag['attempts'] as $at): ?>
  <tr>
    <td><?= htmlspecialchars($at['method'], ENT_QUOTES, 'UTF-8') ?></td>
    <td><?= (int) $at['http'] ?></td>
    <td class="d">
      <?= htmlspecialchars($at['server'] ?: '—', ENT_QUOTES, 'UTF-8') ?>
      <?php if ($at['ip']): ?><br><?= htmlspecialchars($at['ip'], ENT_QUOTES, 'UTF-8') ?><?php endif; ?>
    </td>
    <td class="d">
      <?php if ($at['error']): ?>
        خطای شبکه: <?= htmlspecialchars($at['error'], ENT_QUOTES, 'UTF-8') ?>
      <?php elseif ($at['is_json']): ?>
        status=<?= (int) $at['status'] ?> · <?= htmlspecialchars($at['message'], ENT_QUOTES, 'UTF-8') ?>
        <?php if ($at['credit'] !== null): ?><br>اعتبار: <?= htmlspecialchars($at['credit'], ENT_QUOTES, 'UTF-8') ?><?php endif; ?>
      <?php else: ?>
        پاسخ JSON نبود —
        «<?= htmlspecialchars($at['snippet'] ?: '(خالی)', ENT_QUOTES, 'UTF-8') ?>»
      <?php endif; ?>
    </td>
  </tr>
  <?php endforeach; ?>
</table>
<?php endif; ?>

<?php if ($otpLog !== []): ?>
<h2 class="sub">آخرین رویدادهای ورود</h2>
<table>
  <tr><th>زمان</th><th>رویداد</th><th>جزئیات</th></tr>
  <?php
    $label = [
      'otp_sent'          => 'کد فرستاده شد',
      'otp_send_failed'   => 'ارسال کد ناموفق',
      'otp_failed'        => 'کد اشتباه وارد شد',
      'otp_unknown_phone' => 'شماره‌ی ناشناس',
      'login'             => 'ورود موفق',
    ];
  ?>
  <?php foreach ($otpLog as $row): ?>
  <tr>
    <td class="d"><?= htmlspecialchars((string) $row['created_at'], ENT_QUOTES, 'UTF-8') ?></td>
    <td><?= htmlspecialchars($label[$row['action']] ?? $row['action'], ENT_QUOTES, 'UTF-8') ?></td>
    <td class="d"><?= htmlspecialchars((string) ($row['detail'] ?? '—'), ENT_QUOTES, 'UTF-8') ?></td>
  </tr>
  <?php endforeach; ?>
</table>
<?php endif; ?>

<p class="meta">

  آخرین استقرار: <code><?= $deployed ? htmlspecialchars(trim($deployed), ENT_QUOTES, 'UTF-8') : 'نامشخص' ?></code><br>
  ریشه‌ی وب: <code><?= htmlspecialchars(__DIR__, ENT_QUOTES, 'UTF-8') ?></code><br>
  پوشه‌ی برنامه: <code><?= htmlspecialchars($appRoot, ENT_QUOTES, 'UTF-8') ?></code><br>
  <?php if ($pageCount === 82): ?>
    گام بعدی: <a href="/">صفحه‌ی اصلی</a> را باز کنید.
  <?php elseif ($pageCount === 0 || $pageCount === null): ?>
    گام بعدی: در cPanel ▸ phpMyAdmin فایل‌های <code>db/schema.sql</code> و سپس <code>db/seed/01-pages.sql</code> را اجرا کنید.
  <?php endif; ?>
  <br><br>
  <strong>پیش از انتشار نهایی، این فایل را حذف کنید.</strong>
</p>

</div>
</html>
