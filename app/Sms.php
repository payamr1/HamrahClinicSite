<?php
declare(strict_types=1);

/**
 * ارسال پیامک از راه کاوه‌نگار.
 *
 * دو راه برای فرستادن کد ورود هست و هر دو پشتیبانی می‌شود:
 *
 *  ۱. verify/lookup — راه توصیه‌شده برای کد یک‌بارمصرف.
 *     به خط اختصاصی نیاز ندارد، از صف خدماتی رد می‌شود و معمولاً
 *     چند ثانیه‌ای می‌رسد. فقط باید یک «الگو» در پنل کاوه‌نگار
 *     ساخته و تأیید شده باشد.
 *
 *  ۲. sms/send — ارسال ساده با شماره خط خودتان. اگر الگو ندارید
 *     این کار می‌کند، ولی پیام تبلیغاتی حساب می‌شود و ممکن است
 *     دیرتر برسد یا برای خطوط ۱۰۰۰ فیلتر شود.
 *
 * اگر template در تنظیمات پر باشد، حالت یک انتخاب می‌شود.
 *
 * نکته‌ی امنیتی: خود کد هیچ‌جا log نمی‌شود. پیام خطای کاوه‌نگار
 * ثبت می‌شود ولی متن پیامک نه.
 */
final class Sms
{
    private const BASE    = 'https://api.kavenegar.com/v1';
    private const TIMEOUT = 8;

    public function __construct(private array $cfg) {}

    public function isConfigured(): bool
    {
        if (!empty($this->cfg['emergency_log_code'])) {
            return true;                 // راه اضطراری، بدون کاوه‌نگار
        }
        $key = trim((string) ($this->cfg['api_key'] ?? ''));
        if ($key === '') {
            return false;
        }
        // یکی از این دو لازم است: الگوی verify یا شماره‌ی خط
        return trim((string) ($this->cfg['template'] ?? '')) !== ''
            || trim((string) ($this->cfg['sender']   ?? '')) !== '';
    }

    /** پیام راهنما برای وقتی تنظیمات ناقص است */
    public function configHint(): string
    {
        if (trim((string) ($this->cfg['api_key'] ?? '')) === '') {
            return 'کلید وب‌سرویس کاوه‌نگار در config.php ▸ sms ▸ api_key پر نشده است.';
        }
        return 'شماره‌ی خط را در config.php ▸ sms ▸ sender بگذارید.';
    }

    /** کدام راه ارسال فعال است — برای صفحه‌ی سلامت */
    public function mode(): string
    {
        if (!empty($this->cfg['emergency_log_code'])) {
            return 'emergency';
        }
        return trim((string) ($this->cfg['template'] ?? '')) !== '' ? 'template' : 'sender';
    }

    /**
     * فرستادن کد ورود.
     *
     * @return string|null پیام خطای قابل نمایش، یا null اگر فرستاده شد
     */
    public function sendCode(string $phone, string $code): ?string
    {
        // ---- راه اضطراری ----
        // اگر کاوه‌نگار از دسترس خارج شد یا اعتبار تمام شد، بدون
        // این گزینه هیچ‌کس نمی‌تواند وارد پنل خودش شود. با روشن
        // کردنش کد به‌جای پیامک در لاگ نوشته می‌شود.
        //
        // این کار امنیت را کم می‌کند: هر کسی که به فایل‌های سرور
        // دسترسی دارد کد را می‌بیند. پیش‌فرض خاموش است و بعد از
        // ورود باید فوراً خاموش شود.
        if (!empty($this->cfg['emergency_log_code'])) {
            error_log(sprintf(
                '[hamrah][sms][EMERGENCY] کد ورود %s برای %s — این حالت را در config.php خاموش کنید',
                $code,
                self::maskPhone($phone)
            ));
            return null;
        }

        if (!$this->isConfigured()) {
            return 'سرویس پیامک پیکربندی نشده است. ' . $this->configHint();
        }

        $template = trim((string) ($this->cfg['template'] ?? ''));

        return $template !== ''
            ? $this->lookup($phone, $code, $template)
            : $this->plain($phone, $code);
    }

    /** حالت اضطراری روشن است؟ — پنل این را هشدار می‌دهد */
    public function isEmergencyMode(): bool
    {
        return !empty($this->cfg['emergency_log_code']);
    }

    // ---------------------------------------------------------------

    private function lookup(string $phone, string $code, string $template): ?string
    {
        return $this->call('verify/lookup.json', [
            'receptor' => $phone,
            'token'    => $code,
            'template' => $template,
        ]);
    }

    private function plain(string $phone, string $code): ?string
    {
        return $this->call('sms/send.json', [
            'receptor' => $phone,
            'sender'   => trim((string) $this->cfg['sender']),
            'message'  => $this->buildMessage($code),
        ]);
    }

    /**
     * متن پیامک.
     *
     * درباره‌ی طول: پیامک فارسی با UTF-16 شمرده می‌شود، یعنی هر
     * صفحه فقط ۷۰ نویسه. یک نویسه بیشتر و پیام دو صفحه می‌شود و
     * هزینه دو برابر. متن پیش‌فرض حدود ۵۰ نویسه است تا جا داشته
     * باشد، و نام سایت هم کوتاه می‌شود که اگر روزی طولانی شد از
     * یک صفحه بیرون نزند.
     */
    private function buildMessage(string $code): string
    {
        $custom = trim((string) ($this->cfg['message'] ?? ''));
        if ($custom !== '') {
            // متن دلخواه، برای وقتی محتوای خط باید با چیزی که در
            // کاوه‌نگار تأیید شده جور باشد
            return str_replace(['{code}', '{کد}'], $code, $custom);
        }

        $name = mb_substr(trim((string) ($this->cfg['site_name'] ?? 'همراه کلینیک')), 0, 20);
        return "کد ورود پنل {$name}: {$code}" . "\n" . 'تا ۳ دقیقه معتبر است.';
    }

    /**
     * طول پیام بر حسب صفحه‌ی پیامک — پنل سلامت نشانش می‌دهد.
     *
     * فارسی ۷۰ نویسه در صفحه‌ی اول و ۶۷ در صفحه‌های بعد.
     * برای نمونه یک کد شش‌رقمی فرضی گذاشته می‌شود.
     */
    public function messagePreview(): array
    {
        $text = $this->buildMessage('123456');
        $len  = mb_strlen($text);
        $pages = $len <= 70 ? 1 : (int) ceil(($len - 70) / 67) + 1;

        return ['text' => $text, 'length' => $len, 'pages' => $pages];
    }

    /**
     * فراخوانی API و ترجمه‌ی پاسخ.
     *
     * کاوه‌نگار کد وضعیت را داخل بدنه‌ی JSON می‌گذارد، نه فقط در
     * وضعیت HTTP — پس هر دو بررسی می‌شوند.
     */
    private function call(string $endpoint, array $params): ?string
    {
        // کلید عیناً در مسیر می‌نشیند و encode نمی‌شود — SDK خود
        // کاوه‌نگار هم همین کار را می‌کند. encode کردنش کلیدهایی
        // را که نویسه‌ی خاص دارند می‌شکند.
        $key = trim((string) ($this->cfg['api_key'] ?? ''));
        $url = self::BASE . "/$key/$endpoint";

        [$body, $httpCode, $netError] = $this->post($url, $params);

        if ($netError !== null) {
            error_log('[hamrah][sms] ' . $netError);
            return 'ارتباط با سرویس پیامک برقرار نشد. کمی بعد دوباره تلاش کنید.';
        }

        $json = json_decode((string) $body, true);
        $ret  = is_array($json) ? ($json['return'] ?? null) : null;
        $status = is_array($ret) ? (int) ($ret['status'] ?? 0) : 0;

        if ($status === 200) {
            return null;
        }

        $msg = is_array($ret) ? (string) ($ret['message'] ?? '') : '';
        error_log(sprintf('[hamrah][sms] http=%d status=%d msg=%s', $httpCode, $status, $msg));

        // پاسخی که اصلاً JSON نبود، یعنی چیزی پیش از API جلویش را
        // گرفته — فایروال، پراکسی، یا صفحه‌ی خطای خود هاست. بدون
        // دیدن خودش عیب‌یابی‌اش ناممکن است.
        if ($ret === null) {
            return $this->detail(
                'پاسخ کاوه‌نگار قابل خواندن نبود.',
                sprintf('http=%d، پاسخ: %s', $httpCode, mb_substr(trim((string) $body), 0, 300))
            );
        }

        $friendly = $this->friendly($status);
        return $this->detail($friendly, sprintf('کد %d از کاوه‌نگار: %s', $status, $msg));
    }

    /**
     * جزئیات خام را فقط در حالت debug به پیام می‌چسباند.
     *
     * روی production کاربر نباید پیام داخلی سرویس را ببیند، ولی
     * وقتی چیزی کار نمی‌کند بدون همین متن عیب‌یابی حدس‌زدن است.
     * در هر دو حالت، متن کامل در audit_log می‌نشیند.
     */
    private function detail(string $friendly, string $raw): string
    {
        return empty($this->cfg['debug']) ? $friendly : $friendly . ' — ' . $raw;
    }

    /**
     * ترجمه‌ی کد وضعیت کاوه‌نگار.
     *
     * کدها از مستندات خود کاوه‌نگار آمده‌اند. دو تای مهمش که زیاد
     * اشتباه گرفته می‌شوند: کلید نامعتبر ۴۰۳ است نه ۴۰۱، و
     * کمبود اعتبار ۴۱۸ است نه ۴۰۲.
     */
    private function friendly(int $status): string
    {
        return match ($status) {
            400 => 'پارامترهای درخواست ناقص بود.',
            401 => 'حساب کاوه‌نگار غیرفعال است. در پنل کاوه‌نگار وضعیت حساب را ببینید.',
            402 => 'عملیات ناموفق بود.',
            403 => 'کلید وب‌سرویس پذیرفته نشد. مقدار api_key را در config.php با پنل کاوه‌نگار بسنجید.',
            406 => 'یکی از پارامترهای اجباری خالی فرستاده شد.',
            407 => 'دسترسی به این اطلاعات برای حساب شما مجاز نیست.',
            409 => 'سرور کاوه‌نگار در دسترس نیست. کمی بعد دوباره تلاش کنید.',
            411 => 'شماره‌ی گیرنده نامعتبر است.',
            412 => 'شماره‌ی خط فرستنده نامعتبر است — یا این خط مال حساب شما نیست. مقدار sender را بررسی کنید.',
            413 => 'متن پیام خالی است یا از حد مجاز بلندتر.',
            414 => 'حجم درخواست بیش از حد مجاز بود.',
            418 => 'اعتبار حساب کاوه‌نگار کافی نیست.',
            422 => 'متن پیام نویسه‌ی نامناسب دارد.',
            424 => 'الگوی وریفای پیدا نشد. نام template را با پنل کاوه‌نگار بسنجید.',
            426 => 'این متد به سرویس پیشرفته نیاز دارد و روی حساب شما فعال نیست.',
            431, 432 => 'ساختار کد یا پارامتر الگو درست نیست.',
            default => 'ارسال پیامک ناموفق بود. پنل کاوه‌نگار را بررسی کنید.',
        };
    }

    /**
     * درخواست POST — با cURL اگر هست، وگرنه با stream.
     *
     * @return array{0:?string,1:int,2:?string} بدنه، کد HTTP، خطای شبکه
     */
    private function post(string $url, array $params): array
    {
        $payload = http_build_query($params);

        if (function_exists('curl_init')) {
            $ch = curl_init($url);
            curl_setopt_array($ch, [
                CURLOPT_POST           => true,
                CURLOPT_POSTFIELDS     => $payload,
                CURLOPT_RETURNTRANSFER => true,
                CURLOPT_TIMEOUT        => self::TIMEOUT,
                CURLOPT_CONNECTTIMEOUT => 5,
                CURLOPT_SSL_VERIFYPEER => true,
                CURLOPT_SSL_VERIFYHOST => 2,
                CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
            ]);
            $body = curl_exec($ch);
            $err  = curl_errno($ch) !== 0 ? curl_error($ch) : null;
            $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
            curl_close($ch);

            return [$body === false ? null : (string) $body, $code, $err];
        }

        $ctx = stream_context_create([
            'http' => [
                'method'        => 'POST',
                'header'        => "Content-Type: application/x-www-form-urlencoded\r\n",
                'content'       => $payload,
                'timeout'       => self::TIMEOUT,
                'ignore_errors' => true,
            ],
            'ssl' => ['verify_peer' => true, 'verify_peer_name' => true],
        ]);

        $body = @file_get_contents($url, false, $ctx);
        $code = 0;
        foreach ($http_response_header ?? [] as $h) {
            if (preg_match('~^HTTP/\S+\s+(\d{3})~', $h, $m)) {
                $code = (int) $m[1];
            }
        }
        return [$body === false ? null : $body, $code, $body === false ? 'file_get_contents failed' : null];
    }

    // ---------------------------------------------------------------

    /**
     * یکسان‌سازی شماره‌ی موبایل به شکل 09xxxxxxxxx.
     *
     * کاربر ممکن است شماره را با رقم فارسی، با ‎+98، با ۰۰۹۸، با
     * فاصله یا خط تیره وارد کند. همه به یک شکل درمی‌آیند تا هم
     * مقایسه درست کار کند و هم کاوه‌نگار شماره را بشناسد.
     *
     * @return string|null null یعنی شماره‌ی موبایل ایران نیست
     */
    public static function normalizePhone(?string $raw): ?string
    {
        $s = en((string) $raw);                       // رقم فارسی/عربی → لاتین
        $s = preg_replace('~[^0-9+]~', '', $s) ?? '';

        if (str_starts_with($s, '+98'))  { $s = '0' . substr($s, 3); }
        elseif (str_starts_with($s, '0098')) { $s = '0' . substr($s, 4); }
        elseif (str_starts_with($s, '98') && strlen($s) === 12) { $s = '0' . substr($s, 2); }
        elseif (str_starts_with($s, '9')  && strlen($s) === 10) { $s = '0' . $s; }

        return preg_match('~^09\d{9}$~', $s) === 1 ? $s : null;
    }

    /** نمایش شماره با ستاره، برای صفحه‌ی تأیید کد */
    public static function maskPhone(string $phone): string
    {
        return strlen($phone) === 11
            ? substr($phone, 0, 4) . '***' . substr($phone, -4)
            : $phone;
    }
}
