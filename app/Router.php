<?php
declare(strict_types=1);

/**
 * مسیریاب — حساس‌ترین بخش پروژه از نظر سئو.
 *
 * قاعده‌ی طلایی: هر یک از ۸۲ آدرس ایندکس‌شده باید کد ۲۰۰ برگرداند.
 * هیچ مسیری بدون ریدایرکت ۳۰۱ تغییر نمی‌کند.
 *
 * ترتیب تصمیم‌گیری:
 *   ۱. اسلش انتهایی را اجبار کن (مثل رفتار فعلی وردپرس)
 *   ۲. تطبیق دقیق روی ستون path
 *   ۳. جدول redirects
 *   ۴. تطبیق بخشنده روی path_norm  →  ۳۰۱ به path اصلی
 *   ۵. ۴۰۴ با ثبت در not_found_log
 */
final class Router
{
    public function __construct(private Database $db) {}

    /** مسیر خام درخواست، decode شده و بدون query string */
    public static function requestPath(): string
    {
        $uri  = $_SERVER['REQUEST_URI'] ?? '/';
        $path = parse_url($uri, PHP_URL_PATH) ?: '/';
        $path = rawurldecode($path);

        // اسلش‌های تکراری و ../ را پاک کن
        $path = preg_replace('#/{2,}#', '/', $path) ?? '/';
        $path = str_replace(['/../', '/./'], '/', $path);

        return $path === '' ? '/' : $path;
    }

    /**
     * یکسان‌سازی برای تطبیق بخشنده.
     * باید مو‌به‌مو با pathnorm() در db/seed/gen-pages.pl یکسان بماند.
     */
    public static function normalizePath(string $p): string
    {
        static $map = [
            "\u{0643}" => "\u{06A9}",  // ك عربی → ک فارسی
            "\u{064A}" => "\u{06CC}",  // ي عربی → ی فارسی
            "\u{0649}" => "\u{06CC}",  // ى      → ی
            "\u{200C}" => '',          // نیم‌فاصله
            // ارقام عربی
            "\u{0660}" => '0', "\u{0661}" => '1', "\u{0662}" => '2', "\u{0663}" => '3',
            "\u{0664}" => '4', "\u{0665}" => '5', "\u{0666}" => '6', "\u{0667}" => '7',
            "\u{0668}" => '8', "\u{0669}" => '9',
            // ارقام فارسی
            "\u{06F0}" => '0', "\u{06F1}" => '1', "\u{06F2}" => '2', "\u{06F3}" => '3',
            "\u{06F4}" => '4', "\u{06F5}" => '5', "\u{06F6}" => '6', "\u{06F7}" => '7',
            "\u{06F8}" => '8', "\u{06F9}" => '9',
        ];

        $p = strtr($p, $map);
        $p = preg_replace('#/{2,}#', '/', $p) ?? $p;

        // فقط حروف لاتین کوچک شوند — حروف فارسی حالت کوچک/بزرگ ندارند
        return preg_replace_callback('/[A-Z]+/', fn($m) => strtolower($m[0]), $p) ?? $p;
    }

    /**
     * مسیر را حل کن.
     *
     * @return array{action:string, page?:array, to?:string, code?:int}
     */
    public function resolve(string $path): array
    {
        // ── ۱. اسلش انتهایی اجباری، مثل وردپرس فعلی ──────────────
        if ($path !== '/' && !str_ends_with($path, '/') && !$this->looksLikeFile($path)) {
            return ['action' => 'redirect', 'to' => $path . '/', 'code' => 301];
        }

        // ── ۲. تطبیق دقیق ────────────────────────────────────────
        $page = $this->db->one(
            'SELECT * FROM pages WHERE path = ? AND status = ? LIMIT 1',
            [$path, 'published']
        );
        if ($page !== null) {
            return ['action' => 'page', 'page' => $page];
        }

        // ── ۳. ریدایرکت‌های ثبت‌شده ──────────────────────────────
        $r = $this->db->one('SELECT to_path, code FROM redirects WHERE from_path = ? LIMIT 1', [$path]);
        if ($r !== null) {
            $this->db->run('UPDATE redirects SET hits = hits + 1 WHERE from_path = ?', [$path]);
            return ['action' => 'redirect', 'to' => $r['to_path'], 'code' => (int) $r['code']];
        }

        // ── ۴. تطبیق بخشنده: املای متفاوت ک/ی یا ارقام ──────────
        $norm = self::normalizePath($path);
        if ($norm !== $path) {
            $page = $this->db->one(
                'SELECT path FROM pages WHERE path_norm = ? AND status = ? LIMIT 1',
                [$norm, 'published']
            );
            if ($page !== null) {
                return ['action' => 'redirect', 'to' => $page['path'], 'code' => 301];
            }
        }

        // ── ۵. ۴۰۴ ───────────────────────────────────────────────
        $this->logNotFound($path);
        return ['action' => 'notfound'];
    }

    private function looksLikeFile(string $path): bool
    {
        return (bool) preg_match('/\.[a-z0-9]{2,5}$/i', $path);
    }

    private function logNotFound(string $path): void
    {
        try {
            $this->db->run(
                'INSERT INTO not_found_log (path, referer) VALUES (?, ?)
                 ON DUPLICATE KEY UPDATE hits = hits + 1, last_seen = CURRENT_TIMESTAMP',
                [mb_substr($path, 0, 255), mb_substr((string) ($_SERVER['HTTP_REFERER'] ?? ''), 0, 500) ?: null]
            );
        } catch (\Throwable) {
            // ثبت ۴۰۴ هرگز نباید خودش صفحه را بشکند
        }
    }
}
