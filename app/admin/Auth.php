<?php
declare(strict_types=1);

/**
 * ورود به پنل مدیریت — فقط با کد یک‌بارمصرف پیامکی.
 *
 * رمز عبوری در کار نیست. مدیر شماره‌ی موبایلش را وارد می‌کند، یک
 * کد شش‌رقمی برایش پیامک می‌شود، و با همان کد وارد می‌شود.
 *
 * چند قاعده که عمداً رعایت شده‌اند:
 *
 *  ۱. خود کد هیچ‌جا ذخیره نمی‌شود، فقط هشش. اگر کسی به دیتابیس
 *     دسترسی پیدا کند نباید بتواند کدِ در جریان را بخواند.
 *
 *  ۲. پیام پاسخ همیشه یکی است، چه شماره در فهرست مدیران باشد چه
 *     نباشد. پیام متفاوت به هر کسی می‌گوید کدام شماره مدیر است —
 *     و علاوه بر آن، پیامک خرج دارد و نباید با شماره‌ی دلخواه
 *     کسی بتواند خرج بتراشد.
 *
 *  ۳. سقف تلاش روی هر کد، و فاصله‌ی اجباری بین دو ارسال. فضای یک
 *     کد شش‌رقمی فقط یک میلیون حالت است؛ بدون سقف، حدس‌زدنش کار
 *     چند دقیقه است.
 *
 *  ۴. شناسه‌ی نشست بعد از ورود عوض می‌شود تا session fixation
 *     ممکن نباشد.
 */
final class Auth
{
    /** سقف تلاش برای وارد کردن یک کد */
    private const MAX_TRIES = 5;

    /** قفل حساب بعد از پر شدن سقف */
    private const LOCK_MIN = 15;

    /** عمر کد */
    private const CODE_TTL_SEC = 180;

    /** کمینه‌ی فاصله‌ی دو ارسال پیاپی — نمای ورود هم همین را نشان می‌دهد */
    public const RESEND_SEC = 90;

    /** سقف ارسال در یک ساعت، برای هر حساب */
    private const MAX_SENDS_HOUR = 6;

    /** بی‌کاری تا خروج خودکار */
    private const IDLE_MIN = 120;

    public function __construct(private Database $db, private Sms $sms) {}

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
            header('Location: /admin/');
            exit;
        }
        return $u;
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
    //  مرحله‌ی یک: درخواست کد
    // ---------------------------------------------------------------

    /**
     * کد می‌سازد و پیامک می‌کند.
     *
     * پاسخ هیچ‌وقت نمی‌گوید شماره مدیر هست یا نه. تنها خطایی که
     * صریح برمی‌گردد، خطای خود سرویس پیامک است — آن هم فقط وقتی
     * شماره واقعاً مدیر بوده، وگرنه اصلاً ارسالی در کار نیست.
     *
     * @return array{ok:bool, error:?string, phone:?string}
     */
    public function requestCode(?string $rawPhone, ?string $ip): array
    {
        $phone = Sms::normalizePhone($rawPhone);
        if ($phone === null) {
            return ['ok' => false, 'error' => 'شماره‌ی موبایل درست نیست. مثل ۰۹۱۲۱۲۳۴۵۶۷ وارد کنید.', 'phone' => null];
        }

        if (!$this->sms->isConfigured()) {
            // این یکی را پنهان نمی‌کنیم: ایراد از پیکربندی است، نه
            // از کاربر، و پنهان کردنش فقط وقت مدیر را تلف می‌کند
            return ['ok' => false, 'error' => 'سرویس پیامک هنوز تنظیم نشده. ' . $this->sms->configHint(), 'phone' => $phone];
        }

        $u = $this->db->one(
            'SELECT * FROM admin_users WHERE phone = ? AND is_active = 1',
            [$phone]
        );

        // شماره‌ی ناشناس: همان پاسخ موفق، بدون ارسال چیزی
        if ($u === null) {
            $this->audit(null, 'otp_unknown_phone', 'admin_users', null, Sms::maskPhone($phone), $ip);
            return ['ok' => true, 'error' => null, 'phone' => $phone];
        }

        if (!empty($u['locked_until']) && strtotime((string) $u['locked_until']) > time()) {
            $min = max(1, (int) ceil((strtotime((string) $u['locked_until']) - time()) / 60));
            return ['ok' => false, 'error' => "به دلیل چند تلاش ناموفق، ورود تا {$min} دقیقه‌ی دیگر بسته است.", 'phone' => $phone];
        }

        // فاصله‌ی اجباری بین دو ارسال
        $lastSent = $this->db->value(
            'SELECT created_at FROM admin_otp WHERE admin_id = ? ORDER BY id DESC LIMIT 1',
            [(int) $u['id']]
        );
        if ($lastSent !== null && $lastSent !== false) {
            $wait = self::RESEND_SEC - (time() - (int) strtotime((string) $lastSent));
            if ($wait > 0) {
                return ['ok' => false, 'error' => "کد تازه فرستاده شده. {$wait} ثانیه صبر کنید.", 'phone' => $phone];
            }
        }

        // سقف ساعتی — جلوی خرج‌تراشی و آزار با پیامک را می‌گیرد
        $inHour = (int) $this->db->value(
            'SELECT COUNT(*) FROM admin_otp WHERE admin_id = ? AND created_at > (NOW() - INTERVAL 1 HOUR)',
            [(int) $u['id']]
        );
        if ($inHour >= self::MAX_SENDS_HOUR) {
            return ['ok' => false, 'error' => 'سقف ارسال کد در یک ساعت پر شده است. بعداً دوباره تلاش کنید.', 'phone' => $phone];
        }

        // کد شش‌رقمی، با منبع تصادفی امن
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $err = $this->sms->sendCode($phone, $code);
        if ($err !== null) {
            $this->audit((int) $u['id'], 'otp_send_failed', 'admin_users', (int) $u['id'], $err, $ip);
            return ['ok' => false, 'error' => $err, 'phone' => $phone];
        }

        // کدهای قبلیِ همین حساب از اعتبار می‌افتند
        $this->db->run(
            'UPDATE admin_otp SET used_at = NOW() WHERE admin_id = ? AND used_at IS NULL',
            [(int) $u['id']]
        );

        $this->db->run(
            'INSERT INTO admin_otp (admin_id, code_hash, expires_at, ip)
             VALUES (?, ?, ?, ?)',
            [
                (int) $u['id'],
                password_hash($code, PASSWORD_DEFAULT),
                date('Y-m-d H:i:s', time() + self::CODE_TTL_SEC),
                $ip ? @inet_pton($ip) : null,
            ]
        );

        $this->audit((int) $u['id'], 'otp_sent', 'admin_users', (int) $u['id'], null, $ip);
        $this->pruneOldCodes();

        return ['ok' => true, 'error' => null, 'phone' => $phone];
    }

    // ---------------------------------------------------------------
    //  مرحله‌ی دو: بررسی کد
    // ---------------------------------------------------------------

    /** @return string|null پیام خطا، یا null اگر ورود موفق بود */
    public function verifyCode(?string $rawPhone, ?string $rawCode, ?string $ip): ?string
    {
        $generic = 'کد وارد‌شده درست نیست یا منقضی شده است.';

        $phone = Sms::normalizePhone($rawPhone);
        $code  = preg_replace('~\D~', '', en((string) $rawCode)) ?? '';

        if ($phone === null || $code === '') {
            return $generic;
        }

        $u = $this->db->one(
            'SELECT * FROM admin_users WHERE phone = ? AND is_active = 1',
            [$phone]
        );
        if ($u === null) {
            // همان زمان محاسباتی را می‌سوزانیم تا اختلاف زمان پاسخ
            // لو ندهد کدام شماره مدیر است
            password_hash($code, PASSWORD_DEFAULT);
            return $generic;
        }

        if (!empty($u['locked_until']) && strtotime((string) $u['locked_until']) > time()) {
            $min = max(1, (int) ceil((strtotime((string) $u['locked_until']) - time()) / 60));
            return "به دلیل چند تلاش ناموفق، ورود تا {$min} دقیقه‌ی دیگر بسته است.";
        }

        $otp = $this->db->one(
            'SELECT * FROM admin_otp
              WHERE admin_id = ? AND used_at IS NULL AND expires_at > NOW()
              ORDER BY id DESC LIMIT 1',
            [(int) $u['id']]
        );
        if ($otp === null) {
            password_hash($code, PASSWORD_DEFAULT);
            return $generic;
        }

        if ((int) $otp['tries'] >= self::MAX_TRIES) {
            $this->burnCode((int) $otp['id']);
            $this->lock((int) $u['id']);
            return 'تعداد تلاش‌ها پر شد. کد تازه بگیرید.';
        }

        $this->db->run('UPDATE admin_otp SET tries = tries + 1 WHERE id = ?', [(int) $otp['id']]);

        if (!password_verify($code, (string) $otp['code_hash'])) {
            $left = self::MAX_TRIES - ((int) $otp['tries'] + 1);
            $this->audit((int) $u['id'], 'otp_failed', 'admin_users', (int) $u['id'], null, $ip);

            if ($left <= 0) {
                $this->burnCode((int) $otp['id']);
                $this->lock((int) $u['id']);
                return 'تعداد تلاش‌ها پر شد. پانزده دقیقه‌ی دیگر دوباره تلاش کنید.';
            }
            return $generic . " ({$left} تلاش باقی مانده)";
        }

        // ---- کد درست بود ----
        $this->burnCode((int) $otp['id']);
        $this->db->run(
            'UPDATE admin_users SET failed_tries = 0, locked_until = NULL, last_login_at = NOW() WHERE id = ?',
            [(int) $u['id']]
        );

        session_regenerate_id(true);
        $_SESSION['admin_id'] = (int) $u['id'];
        $_SESSION['seen_at']  = time();
        $_SESSION['csrf']     = bin2hex(random_bytes(32));
        unset($_SESSION['otp_phone'], $_SESSION['otp_sent_at']);

        $this->audit((int) $u['id'], 'login', 'admin_users', (int) $u['id'], null, $ip);
        return null;
    }

    private function burnCode(int $otpId): void
    {
        $this->db->run('UPDATE admin_otp SET used_at = NOW() WHERE id = ?', [$otpId]);
    }

    private function lock(int $adminId): void
    {
        $this->db->run(
            'UPDATE admin_users SET failed_tries = failed_tries + 1, locked_until = ? WHERE id = ?',
            [date('Y-m-d H:i:s', time() + self::LOCK_MIN * 60), $adminId]
        );
    }

    /** کدهای مصرف‌شده و منقضی بعد از یک روز لازم نیستند */
    private function pruneOldCodes(): void
    {
        try {
            $this->db->run('DELETE FROM admin_otp WHERE created_at < (NOW() - INTERVAL 1 DAY)');
        } catch (\Throwable) {
            // پاک‌سازی نباید جلوی ورود را بگیرد
        }
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
     *
     * شماره‌ی موبایل اینجا وارد می‌شود و در مخزن نمی‌نشیند — شماره‌ی
     * شخصی در یک مخزن عمومی جایی ندارد.
     */
    public function createFirst(?string $rawPhone, string $name): ?string
    {
        if ($this->anyUser()) {
            return 'حساب مدیر از قبل ساخته شده است.';
        }

        $phone = Sms::normalizePhone($rawPhone);
        if ($phone === null) {
            return 'شماره‌ی موبایل درست نیست. مثل ۰۹۱۲۱۲۳۴۵۶۷ وارد کنید.';
        }

        $name = trim($name);
        if (mb_strlen($name) < 2) {
            return 'نام را کامل وارد کنید.';
        }

        $this->db->run(
            'INSERT INTO admin_users (username, phone, name, role) VALUES (?, ?, ?, ?)',
            [$phone, $phone, $name, 'owner']
        );
        return null;
    }

    /** افزودن مدیر تازه از داخل پنل */
    public function addUser(?string $rawPhone, string $name, string $role = 'editor'): ?string
    {
        $phone = Sms::normalizePhone($rawPhone);
        if ($phone === null) {
            return 'شماره‌ی موبایل درست نیست.';
        }
        if ($this->db->one('SELECT id FROM admin_users WHERE phone = ?', [$phone]) !== null) {
            return 'این شماره از قبل ثبت شده است.';
        }
        $name = trim($name);
        if (mb_strlen($name) < 2) {
            return 'نام را کامل وارد کنید.';
        }

        $this->db->run(
            'INSERT INTO admin_users (username, phone, name, role) VALUES (?, ?, ?, ?)',
            [$phone, $phone, $name, $role === 'owner' ? 'owner' : 'editor']
        );
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
