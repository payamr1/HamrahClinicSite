<?php
declare(strict_types=1);

/** escape برای خروجی HTML — همیشه استفاده شود */
function e(?string $s): string
{
    return htmlspecialchars((string) $s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/** آدرس داخلی: مسیر فارسی را برای href دوباره encode می‌کند */
function url(?string $path): string
{
    $path = $path ?: '/';
    return implode('/', array_map('rawurlencode', explode('/', $path)));
}

/**
 * بهینه‌ساز تصویر — یک نمونه برای کل درخواست.
 * bootstrap آن را یک بار ست می‌کند و قالب‌ها از img() استفاده می‌کنند.
 */
function img_init(?Images $i = null): ?Images
{
    static $inst = null;
    if ($i !== null) {
        $inst = $i;
    }
    return $inst;
}

/**
 * آدرس نسخه‌ی بهینه‌ی یک تصویر.
 *
 * @param string|null $rel مسیر نسبی داخل assets/img
 * @param int         $w   عرضی که واقعاً در قالب دیده می‌شود
 */
function img(?string $rel, int $w): string
{
    $rel = (string) $rel;
    if ($rel === '') {
        return '';
    }
    $opt = img_init();
    return $opt ? $opt->url($rel, $w) : '/assets/img/' . ltrim($rel, '/');
}

/** آدرس فایل ثابت با نسخه‌گذاری بر اساس زمان تغییر فایل */
function asset(string $rel): string
{
    $rel  = '/' . ltrim($rel, '/');
    $file = ($_SERVER['DOCUMENT_ROOT'] ?? '') . $rel;
    $v    = is_file($file) ? substr((string) filemtime($file), -6) : '1';
    return $rel . '?v=' . $v;
}

/** ارقام لاتین → فارسی، برای نمایش */
function fa(?string $s): string
{
    return strtr((string) $s, ['0'=>'۰','1'=>'۱','2'=>'۲','3'=>'۳','4'=>'۴','5'=>'۵','6'=>'۶','7'=>'۷','8'=>'۸','9'=>'۹']);
}

/** ارقام فارسی/عربی → لاتین، برای ذخیره و مقایسه */
function en(?string $s): string
{
    return strtr((string) $s, [
        '۰'=>'0','۱'=>'1','۲'=>'2','۳'=>'3','۴'=>'4','۵'=>'5','۶'=>'6','۷'=>'7','۸'=>'8','۹'=>'9',
        '٠'=>'0','١'=>'1','٢'=>'2','٣'=>'3','٤'=>'4','٥'=>'5','٦'=>'6','٧'=>'7','٨'=>'8','٩'=>'9',
    ]);
}

/** تاریخ میلادی به شمسی — بدون وابستگی بیرونی */
function jdate(?string $gregorian, bool $withMonthName = true): string
{
    if (!$gregorian) {
        return '';
    }
    $ts = strtotime($gregorian);
    if ($ts === false) {
        return '';
    }
    [$gy, $gm, $gd] = array_map('intval', explode('-', date('Y-m-d', $ts)));

    $gDaysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    $jDaysInMonth = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 29];

    $gy2 = $gy - 1600;
    $gm2 = $gm - 1;
    $gd2 = $gd - 1;

    $gDayNo = 365 * $gy2 + intdiv($gy2 + 3, 4) - intdiv($gy2 + 99, 100) + intdiv($gy2 + 399, 400);
    for ($i = 0; $i < $gm2; $i++) {
        $gDayNo += $gDaysInMonth[$i];
    }
    if ($gm2 > 1 && (($gy % 4 === 0 && $gy % 100 !== 0) || $gy % 400 === 0)) {
        $gDayNo++;
    }
    $gDayNo += $gd2;

    $jDayNo = $gDayNo - 79;
    $jNp    = intdiv($jDayNo, 12053);
    $jDayNo %= 12053;

    $jy = 979 + 33 * $jNp + 4 * intdiv($jDayNo, 1461);
    $jDayNo %= 1461;
    if ($jDayNo >= 366) {
        $jy += intdiv($jDayNo - 366, 365);
        $jDayNo = ($jDayNo - 366) % 365;
    }
    $jm = 0;
    for ($i = 0; $i < 12 && $jDayNo >= $jDaysInMonth[$i]; $i++) {
        $jDayNo -= $jDaysInMonth[$i];
        $jm = $i + 1;
    }
    $jm++;
    $jd = $jDayNo + 1;

    if (!$withMonthName) {
        return fa(sprintf('%04d/%02d/%02d', $jy, $jm, $jd));
    }
    $names = ['فروردین','اردیبهشت','خرداد','تیر','مرداد','شهریور','مهر','آبان','آذر','دی','بهمن','اسفند'];
    return fa((string) $jd) . ' ' . $names[$jm - 1] . ' ' . fa((string) $jy);
}

/** بریدن متن روی مرز واژه */
function excerpt(?string $text, int $chars = 140): string
{
    $t = trim(preg_replace('/\s+/u', ' ', strip_tags((string) $text)) ?? '');
    if ($t === '' || mb_strlen($t) <= $chars) {
        return $t;
    }
    $cut = mb_substr($t, 0, $chars);
    $sp  = mb_strrpos($cut, ' ');
    return ($sp !== false ? mb_substr($cut, 0, $sp) : $cut) . '…';
}

/** تخمین زمان مطالعه به دقیقه — فارسی حدود ۲۰۰ واژه در دقیقه */
function readingTime(?string $body): int
{
    $words = preg_split('/\s+/u', strip_tags((string) $body), -1, PREG_SPLIT_NO_EMPTY) ?: [];
    return max(1, (int) ceil(count($words) / 200));
}

/** توکن CSRF */
function csrfToken(string $key): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(16));
    }
    return hash_hmac('sha256', $_SESSION['csrf'], $key);
}

function csrfCheck(string $key, ?string $token): bool
{
    if (empty($_SESSION['csrf']) || $token === null || $token === '') {
        return false;
    }
    return hash_equals(hash_hmac('sha256', $_SESSION['csrf'], $key), $token);
}

/** رندر یک قالب با دامنه‌ی متغیر محدود */
function view(string $viewDir, string $name, array $vars = []): string
{
    $file = $viewDir . '/' . $name . '.php';
    if (!is_file($file)) {
        throw new RuntimeException("قالب پیدا نشد: $name");
    }
    extract($vars, EXTR_SKIP);
    ob_start();
    require $file;
    return (string) ob_get_clean();
}

/**
 * خط شماره‌ی پروانه، با نام درستِ مرجع صادرکننده.
 *
 * همه‌ی اعضای تیم پزشک نیستند؛ مشاور روان‌شناس شماره‌ی عضویت
 * سازمان نظام روان‌شناسی و مشاوره دارد نه نظام پزشکی. برچسب را
 * از خود ردیف می‌خوانیم تا کسی با عنوان اشتباه معرفی نشود.
 * خالی بودن ستون یعنی پیش‌فرض: نظام پزشکی.
 *
 * خروجی برای چاپ مستقیم آماده است (escape شده).
 */
function licenseLine(array $doc): string
{
    if (empty($doc['license_no'])) {
        return '';
    }
    $label = trim((string) ($doc['license_label'] ?? '')) ?: 'نظام پزشکی';
    return e($label) . ' ' . e(fa((string) $doc['license_no']));
}
