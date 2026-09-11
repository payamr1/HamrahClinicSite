<?php
declare(strict_types=1);

/**
 * ورود به پنل مدیریت.
 *
 * چند قاعده که عمداً رعایت شده‌اند:
 *
 *  ۱. رمز هرگز جایی جز خروجی password_hash ذخیره نمی‌شود، و
 *     مقایسه با password_verify انجام می‌شود که زمان‌ثابت است.
 *
 *  ۲. پیام خطای ورود همیشه یکی است، چه نام کاربری اشتباه باشد چه
 *     رمز. پیام متفاوت به مهاجم می‌گوید کدام نام کاربری وجود دارد.
 *
 *  ۳. بعد از چند تلاش ناموفق حساب موقتاً قفل می‌شود. بدون این،
 *     حدس‌زدن رمز فقط یک مسئله‌ی زمان است.
 *
 *  ۴. شناسه‌ی نشست بعد از ورود عوض می‌شود تا session fixation
 *     ممکن نباشد.
 */
final class Auth
{
    private const MAX_TRIES  = 5;
    private const LOCK_MIN   = 15;
    private const IDLE_MIN   = 120;    // بی‌کاری تا خروج خودکار

    public function __construct(private Database $db) {}

    // ---------------------------------------------------------------
    //  نشست
    // ---------------------------------------------------------------

    public function startSession(bool $https): void
    {
        if (session_status() === PHP_SESSION_ACTIVE) {
            return;
        }
        session_set_cookie_params([
            'lifetime' => 0,
            'path'     => '/admin/',
            'httponly' => true,
            'secure'   => $https,
            'samesite' => 'Strict',
        ]);
        session_name('hamrah_admin');
        session_start();
    }

    public function user(): ?array
    {
        if (empty($_SESSION['admin_id'])) {
            return null;
        }
        // بی‌کاری طولانی یعنی خروج
        $last = (int) ($_SESSION['seen_at'] ?? 0);
        if ($last > 0 && time() - $last > self::IDLE_MIN * 60) {
            $this->logout();
            return null;
        }
        $_SESSION['seen_at'] = time();

        $u = $this->db->one(
            'SELECT * FROM admin_users WHERE id = ? AND is_active = 1',
            [(int) $_SESSION['admin_id']]
        );
        if ($u === null) {
            $this->logout();
        }
        return $u;
    }

    public function requireUser(): array
    {
        $u = $this->user();
        if ($u === null) {
            $to = $_SERVER['REQUEST_URI'] ?? '/admin/';
            header('Location: /admin/?r=' . rawurlencode($to));
            exit;
        }
        return $u;
    }

    // ---------------------------------------------------------------
    //  ورود و خروج
    // ---------------------------------------------------------------

    /** @return string|null پیام خطا، یا null اگر ورود موفق بود */
    public function login(string $username, string $password, ?string $ip): ?string
    {
        $generic = 'نام کاربری یا رمز عبور درست نیست.';
        $u = $this->db->one('SELECT * FROM admin_users WHERE username = ?', [trim($username)]);

        if ($u === null) {
            // کاربر ناموجود باید همان‌قدر زمان ببرد که کاربر موجود،
            // وگرنه اختلاف زمانِ پاسخ خودش لو می‌دهد چه نامی ثبت است.
            // یک هش واقعی می‌سازیم تا همان کار محاسباتی انجام شود.
            password_hash($password, PASSWORD_DEFAULT);
            return $generic;
        }

        if (!empty($u['locked_until']) && strtotime((string) $u['locked_until']) > time()) {
            $min = max(1, (int) ceil((strtotime((string) $u['locked_until']) - time()) / 60));
            return "به دلیل چند تلاش ناموفق، ورود تا {$min} دقیقه‌ی دیگر بسته است.";
        }

        if (!password_verify($password, (string) $u['password_hash'])) {
            $tries = (int) $u['failed_tries'] + 1;
            $lock  = $tries >= self::MAX_TRIES
                ? date('Y-m-d H:i:s', time() + self::LOCK_MIN * 60)
                : null;
            $this->db->run(
                'UPDATE admin_users SET failed_tries = ?, locked_until = ? WHERE id = ?',
                [$tries, $lock, $u['id']]
            );
            $this->audit(null, 'login_failed', 'admin_users', (int) $u['id'], $username, $ip);
            return $generic;
        }

        if ((int) $u['is_active'] !== 1) {
            return 'این حساب غیرفعال است.';
        }

        // رمز درست بود — اگر الگوریتم پیش‌فرض PHP عوض شده باشد،
        // هش را همین‌جا به‌روز می‌کنیم
        if (password_needs_rehash((string) $u['password_hash'], PASSWORD_DEFAULT)) {
            $this->db->run(
                'UPDATE admin_users SET password_hash = ? WHERE id = ?',
                [password_hash($password, PASSWORD_DEFAULT), $u['id']]
            );
        }

        $this->db->run(
            'UPDATE admin_users SET failed_tries = 0, locked_until = NULL, last_login_at = NOW() WHERE id = ?',
            [$u['id']]
        );

        session_regenerate_id(true);
        $_SESSION['admin_id'] = (int) $u['id'];
        $_SESSION['seen_at']  = time();
        $_SESSION['csrf']     = bin2hex(random_bytes(32));

        $this->audit((int) $u['id'], 'login', 'admin_users', (int) $u['id'], null, $ip);
        return null;
    }

    public function logout(): void
    {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $p = session_get_cookie_params();
            setcookie(session_name(), '', time() - 42000, $p['path'], $p['domain'], $p['secure'], $p['httponly']);
        }
        session_destroy();
    }

    // ---------------------------------------------------------------
    //  اولین کاربر
    // ---------------------------------------------------------------

    public function anyUser(): bool
    {
        return (int) $this->db->value('SELECT COUNT(*) FROM admin_users') > 0;
    }

    /**
     * ساخت اولین حساب.
     *
     * فقط وقتی کار می‌کند که هیچ حسابی وجود نداشته باشد، پس صفحه‌ی
     * راه‌اندازی بعد از اولین استفاده خودبه‌خود بسته می‌شود.
     */
    public function createFirst(string $username, string $password, string $name): ?string
    {
        if ($this->anyUser()) {
            return 'حساب مدیر از قبل ساخته شده است.';
        }
        $username = trim($username);
        if (!preg_match('~^[a-zA-Z0-9_.\-]{3,60}$~', $username)) {
            return 'نام کاربری باید ۳ تا ۶۰ نویسه‌ی لاتین، عدد، نقطه یا خط تیره باشد.';
        }
        if (($err = $this->passwordProblem($password)) !== null) {
            return $err;
        }

        $this->db->run(
            'INSERT INTO admin_users (username, password_hash, name, role) VALUES (?, ?, ?, ?)',
            [$username, password_hash($password, PASSWORD_DEFAULT), trim($name) ?: $username, 'owner']
        );
        return null;
    }

    public function changePassword(int $id, string $current, string $new): ?string
    {
        $u = $this->db->one('SELECT * FROM admin_users WHERE id = ?', [$id]);
        if ($u === null || !password_verify($current, (string) $u['password_hash'])) {
            return 'رمز فعلی درست نیست.';
        }
        if (($err = $this->passwordProblem($new)) !== null) {
            return $err;
        }
        $this->db->run(
            'UPDATE admin_users SET password_hash = ? WHERE id = ?',
            [password_hash($new, PASSWORD_DEFAULT), $id]
        );
        return null;
    }

    /**
     * حداقل‌های رمز.
     *
     * طول از پیچیدگی مهم‌تر است: یک عبارت بلند از یک رمز کوتاهِ
     * پر از علامت هم امن‌تر است و هم به یاد می‌ماند.
     */
    private function passwordProblem(string $p): ?string
    {
        if (mb_strlen($p) < 12) {
            return 'رمز عبور باید دست‌کم ۱۲ نویسه باشد. یک عبارت چندکلمه‌ای انتخاب کنید.';
        }
        $weak = ['password', '123456789012', 'qwertyuiop', 'hamrahclinic'];
        foreach ($weak as $w) {
            if (stripos($p, $w) !== false) {
                return 'این رمز قابل حدس است. عبارت دیگری انتخاب کنید.';
            }
        }
        return null;
    }

    // ---------------------------------------------------------------
    //  CSRF
    // ---------------------------------------------------------------

    public function csrf(): string
    {
        if (empty($_SESSION['csrf'])) {
            $_SESSION['csrf'] = bin2hex(random_bytes(32));
        }
        return $_SESSION['csrf'];
    }

    /**
     * بررسی توکن روی هر درخواست نوشتن.
     *
     * بدون این، یک صفحه‌ی دیگر می‌تواند مرورگرِ واردشده‌ی شما را
     * وادار کند فرم پنل را بفرستد بی‌آنکه خبر داشته باشید.
     */
    public function checkCsrf(?string $token): bool
    {
        return !empty($_SESSION['csrf'])
            && is_string($token)
            && hash_equals((string) $_SESSION['csrf'], $token);
    }

    // ---------------------------------------------------------------

    public function audit(?int $adminId, string $action, ?string $entity = null, ?int $entityId = null, ?string $detail = null, ?string $ip = null): void
    {
        try {
            $this->db->run(
                'INSERT INTO audit_log (admin_id, action, entity, entity_id, detail, ip)
                 VALUES (?, ?, ?, ?, ?, ?)',
                [$adminId, $action, $entity, $entityId, $detail, $ip ? @inet_pton($ip) : null]
            );
        } catch (\Throwable) {
            // ثبت رویداد نباید جلوی کار اصلی را بگیرد
        }
    }
}
