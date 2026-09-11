<?php
declare(strict_types=1);

/**
 * پنل مدیریت — مسیریاب.
 *
 * از public/admin/index.php صدا زده می‌شود. کل کد پنل بیرون از
 * ریشه‌ی وب می‌ماند؛ فقط همان یک فایل ورودی داخل ریشه است.
 *
 * پنل هرگز نباید ایندکس شود — هم هدر noindex می‌فرستد و هم
 * ‎.htaccess همان را تکرار می‌کند.
 */

/** @var array $app */
require __DIR__ . '/Auth.php';

$db   = $app['db'];
$auth = new Auth($db);
$media = $app['media'];

$https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
      || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
$auth->startSession($https);

header('X-Robots-Tag: noindex, nofollow, noarchive');
header('Content-Type: text/html; charset=utf-8');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');
header('Referrer-Policy: no-referrer');
header('Cache-Control: no-store, no-cache, must-revalidate, private');

$ip     = $_SERVER['REMOTE_ADDR'] ?? null;
$route  = trim((string) ($_GET['p'] ?? ''), '/');
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$isPost = $method === 'POST';

// ---------------------------------------------------------------
//  کمکی‌های محلی
// ---------------------------------------------------------------

/** نمایش یک نمای پنل داخل قالب */
$render = function (string $view, array $vars = []) use ($app, $auth): void {
    $vars['auth'] = $auth;
    $vars['app']  = $app;
    extract($vars, EXTR_SKIP);
    ob_start();
    require __DIR__ . '/views/' . $view . '.php';
    $content = ob_get_clean();
    require __DIR__ . '/views/layout.php';
};

$redirect = function (string $to): never {
    header('Location: ' . $to);
    exit;
};

/** پیام یک‌بارمصرف بین دو درخواست */
$flash = function (?string $msg = null, string $kind = 'ok') {
    if ($msg !== null) {
        $_SESSION['flash'] = ['msg' => $msg, 'kind' => $kind];
        return null;
    }
    $f = $_SESSION['flash'] ?? null;
    unset($_SESSION['flash']);
    return $f;
};

// هر درخواست نوشتن باید توکن معتبر داشته باشد
$guardPost = function () use ($auth, $isPost): void {
    if ($isPost && !$auth->checkCsrf($_POST['csrf'] ?? null)) {
        http_response_code(419);
        exit('<!doctype html><meta charset="utf-8"><p dir="rtl">نشست منقضی شده است. صفحه را تازه کنید و دوباره تلاش کنید.</p>');
    }
};

// ---------------------------------------------------------------
//  راه‌اندازی — فقط وقتی هیچ حسابی نیست
// ---------------------------------------------------------------
if (!$auth->anyUser()) {
    $error = null;
    if ($isPost) {
        $guardPost();
        $error = $auth->createFirst(
            (string) ($_POST['username'] ?? ''),
            (string) ($_POST['password'] ?? ''),
            (string) ($_POST['name'] ?? '')
        );
        if ($error === null) {
            $auth->audit(null, 'setup', 'admin_users', null, 'اولین حساب ساخته شد', $ip);
            $flash('حساب ساخته شد. حالا وارد شوید.');
            $redirect('/admin/');
        }
    }
    $render('setup', ['error' => $error, 'title' => 'راه‌اندازی پنل']);
    exit;
}

// ---------------------------------------------------------------
//  ورود و خروج
// ---------------------------------------------------------------
if ($route === 'logout') {
    $guardPost();
    $auth->logout();
    $redirect('/admin/');
}

$user = $auth->user();

if ($user === null) {
    $error = null;
    if ($isPost) {
        $guardPost();
        $error = $auth->login(
            (string) ($_POST['username'] ?? ''),
            (string) ($_POST['password'] ?? ''),
            $ip
        );
        if ($error === null) {
            $to = (string) ($_POST['r'] ?? '/admin/');
            // فقط مسیر داخلی پنل، تا به سایت دیگری هدایت نشویم
            $redirect(preg_match('~^/admin/~', $to) ? $to : '/admin/');
        }
    }
    $render('login', [
        'error' => $error,
        'r'     => (string) ($_GET['r'] ?? '/admin/'),
        'title' => 'ورود',
        'flash' => $flash(),
    ]);
    exit;
}

// ---------------------------------------------------------------
//  از اینجا به بعد کاربر وارد شده است
// ---------------------------------------------------------------
$repo = $app['repo'];

switch ($route) {

    // ---- میزکار ------------------------------------------------
    case '':
    case 'home':
        $render('dashboard', [
            'title' => 'میزکار',
            'user'  => $user,
            'flash' => $flash(),
            'stats' => [
                'media'    => $media->countAll(),
                'images'   => $media->countAll(['kind' => 'image']),
                'videos'   => $media->countAll(['kind' => 'video']),
                'untagged' => $media->countAll(['untagged' => true]),
                'doctors'  => (int) $db->value('SELECT COUNT(*) FROM doctors WHERE is_active = 1'),
                'clinics'  => (int) $db->value('SELECT COUNT(*) FROM clinics'),
                'pages'    => (int) $db->value("SELECT COUNT(*) FROM pages WHERE status = 'published'"),
            ],
            'recent' => $media->browse([], 12),
        ]);
        break;

    // ---- کتابخانه‌ی رسانه --------------------------------------
    case 'media':
        $f = [
            'kind'     => in_array($_GET['kind'] ?? '', ['image', 'video'], true) ? $_GET['kind'] : null,
            'q'        => trim((string) ($_GET['q'] ?? '')) ?: null,
            'untagged' => !empty($_GET['untagged']),
        ];
        $per   = 48;
        $page_ = max(1, (int) ($_GET['page'] ?? 1));
        $total = $media->countAll($f);

        $render('media/index', [
            'title'  => 'کتابخانه‌ی رسانه',
            'user'   => $user,
            'flash'  => $flash(),
            'items'  => $media->browse($f, $per, ($page_ - 1) * $per),
            'filter' => $f,
            'total'  => $total,
            'page'   => $page_,
            'pages'  => max(1, (int) ceil($total / $per)),
        ]);
        break;

    // ---- بارگذاری ----------------------------------------------
    case 'media/upload':
        $error = null;
        $done  = [];

        if ($isPost) {
            $guardPost();
            $tags = adminParseTags($_POST);

            try {
                // نشانی ویدیوی بیرونی
                $embed = trim((string) ($_POST['embed_url'] ?? ''));
                if ($embed !== '') {
                    $m = $media->storeEmbed($embed, $_POST, (int) $user['id']);
                    $media->retag((int) $m['id'], $tags, 'video');
                    $done[] = $m;
                }

                // فایل‌ها — چندتایی
                $files = adminNormalizeFiles($_FILES['files'] ?? []);
                foreach ($files as $file) {
                    if (($file['error'] ?? UPLOAD_ERR_NO_FILE) === UPLOAD_ERR_NO_FILE) {
                        continue;
                    }
                    $m = $media->store($file, $_POST, (int) $user['id']);
                    $media->retag((int) $m['id'], $tags, (string) $m['kind']);
                    $done[] = $m;
                }

                if ($done === []) {
                    $error = 'فایلی انتخاب نشده بود.';
                } else {
                    $auth->audit((int) $user['id'], 'upload', 'media', null, count($done) . ' فایل', $ip);
                    $flash(count($done) . ' فایل بارگذاری شد.');
                    $redirect('/admin/?p=media');
                }
            } catch (\RuntimeException $e) {
                $error = $e->getMessage();
            }
        }

        $render('media/upload', [
            'title'   => 'بارگذاری رسانه',
            'user'    => $user,
            'error'   => $error,
            'targets' => adminTargets($db),
        ]);
        break;

    // ---- ویرایش یک فایل ----------------------------------------
    case 'media/edit':
        $id = (int) ($_GET['id'] ?? 0);
        $m  = $media->find($id);
        if ($m === null) {
            http_response_code(404);
            $render('notfound', ['title' => 'پیدا نشد', 'user' => $user]);
            break;
        }
        $error = null;

        if ($isPost) {
            $guardPost();
            if (!empty($_POST['delete'])) {
                $media->forget($id);
                $auth->audit((int) $user['id'], 'delete', 'media', $id, $m['filename'] ?? $m['embed_url'], $ip);
                $flash('فایل حذف شد.');
                $redirect('/admin/?p=media');
            }
            $media->update($id, $_POST);
            $media->retag($id, adminParseTags($_POST), (string) $m['kind']);
            $auth->audit((int) $user['id'], 'update', 'media', $id, null, $ip);
            $flash('تغییرات ذخیره شد.');
            $redirect('/admin/?p=media/edit&id=' . $id);
        }

        $render('media/edit', [
            'title'   => 'ویرایش رسانه',
            'user'    => $user,
            'flash'   => $flash(),
            'error'   => $error,
            'm'       => $media->find($id),
            'tags'    => $media->tags($id),
            'targets' => adminTargets($db),
        ]);
        break;

    // ---- رسانه‌ی یک موجودیت ------------------------------------
    case 'entity':
        $type = (string) ($_GET['type'] ?? 'doctor');
        $id   = (int) ($_GET['id'] ?? 0);
        if (!in_array($type, ['doctor', 'clinic', 'page'], true) || $id <= 0) {
            $redirect('/admin/?p=media');
        }
        $render('entity', [
            'title'    => 'رسانه‌ی این مورد',
            'user'     => $user,
            'flash'    => $flash(),
            'type'     => $type,
            'id'       => $id,
            'label'    => adminEntityLabel($db, $type, $id),
            'profiles' => $media->forEntity($type, $id, 'profile', 'image', 24),
            'photos'   => $media->forEntity($type, $id, 'gallery', 'image', 200),
            'videos'   => $media->forEntity($type, $id, 'gallery', 'video', 200),
        ]);
        break;

    // ---- فهرست موجودیت‌ها --------------------------------------
    case 'targets':
        $render('targets', [
            'title'   => 'پزشکان، بخش‌ها و صفحه‌ها',
            'user'    => $user,
            'targets' => adminTargets($db),
            'counts'  => adminMediaCounts($db),
        ]);
        break;

    // ---- حساب --------------------------------------------------
    case 'account':
        $error = null;
        if ($isPost) {
            $guardPost();
            $error = $auth->changePassword(
                (int) $user['id'],
                (string) ($_POST['current'] ?? ''),
                (string) ($_POST['new'] ?? '')
            );
            if ($error === null) {
                $auth->audit((int) $user['id'], 'password_change', 'admin_users', (int) $user['id'], null, $ip);
                $flash('رمز عبور عوض شد.');
                $redirect('/admin/?p=account');
            }
        }
        $render('account', [
            'title' => 'حساب من',
            'user'  => $user,
            'flash' => $flash(),
            'error' => $error,
        ]);
        break;

    default:
        http_response_code(404);
        $render('notfound', ['title' => 'پیدا نشد', 'user' => $user]);
}

// ---------------------------------------------------------------
//  توابع کمکی پنل
// ---------------------------------------------------------------

/**
 * تگ‌های فرم را به شکل قابل‌فهم برای Media::retag درمی‌آورد.
 *
 * فرم هر تگ را به شکل «doctor:5» می‌فرستد و نقشش را جداگانه، تا
 * یک فایل بتواند هم‌زمان پروفایل یک پزشک و در گالری یک بخش باشد.
 */
function adminParseTags(array $post): array
{
    $out = [];

    foreach ((array) ($post['tag'] ?? []) as $raw) {
        $raw = (string) $raw;
        if ($raw === 'site') {
            $out[] = ['type' => 'site', 'id' => 0, 'role' => 'gallery'];
            continue;
        }
        if (!str_contains($raw, ':')) {
            continue;
        }
        [$type, $id] = explode(':', $raw, 2);
        $role = ($post['role'][$raw] ?? 'gallery') === 'profile' ? 'profile' : 'gallery';
        $out[] = ['type' => $type, 'id' => (int) $id, 'role' => $role];
    }
    return $out;
}

/**
 * ‎$_FILES برای input چندتایی ساختار ستونی دارد؛ اینجا به آرایه‌ای
 * از فایل‌های منفرد تبدیل می‌شود.
 */
function adminNormalizeFiles(array $f): array
{
    if (!isset($f['name'])) {
        return [];
    }
    if (!is_array($f['name'])) {
        return [$f];
    }
    $out = [];
    foreach (array_keys($f['name']) as $i) {
        $out[] = [
            'name'     => $f['name'][$i],
            'type'     => $f['type'][$i]     ?? '',
            'tmp_name' => $f['tmp_name'][$i] ?? '',
            'error'    => $f['error'][$i]    ?? UPLOAD_ERR_NO_FILE,
            'size'     => $f['size'][$i]     ?? 0,
        ];
    }
    return $out;
}

/** همه‌ی چیزهایی که می‌شود رسانه را به آن‌ها تگ زد */
function adminTargets(Database $db): array
{
    return [
        'doctor' => $db->all('SELECT id, name AS label FROM doctors WHERE is_active = 1 ORDER BY sort, name'),
        'clinic' => $db->all('SELECT id, name AS label FROM clinics ORDER BY sort, name'),
        'page'   => $db->all(
            "SELECT id, title AS label FROM pages
              WHERE type = 'service' AND status = 'published'
              ORDER BY sort, title"
        ),
    ];
}

function adminEntityLabel(Database $db, string $type, int $id): string
{
    $t = ['doctor' => ['doctors', 'name'], 'clinic' => ['clinics', 'name'], 'page' => ['pages', 'title']][$type] ?? null;
    if ($t === null) {
        return '';
    }
    [$table, $col] = $t;
    return (string) ($db->value("SELECT $col FROM $table WHERE id = ?", [$id]) ?? '');
}

/** تعداد رسانه‌ی هر موجودیت، برای نشان‌دادن کنار نامش */
function adminMediaCounts(Database $db): array
{
    $out = [];
    $rows = $db->all(
        "SELECT entity_type, entity_id, role, COUNT(*) AS n
           FROM media_tag GROUP BY entity_type, entity_id, role"
    );
    foreach ($rows as $r) {
        $out[$r['entity_type']][(int) $r['entity_id']][$r['role']] = (int) $r['n'];
    }
    return $out;
}
