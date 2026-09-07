<?php
declare(strict_types=1);

/**
 * بهینه‌سازی تصویر در لحظه.
 *
 * مسئله: عکس‌ها ۸۵٪ وزن صفحه بودند. پرتره‌ها ۷۶۸×۷۶۸ سرو می‌شدند
 * در حالی که در قابی حدود ۲۰۸ پیکسلی دیده می‌شوند.
 *
 * راه‌حل: نسخه‌ی کوچک‌شده در اولین درخواست ساخته و کش می‌شود.
 * نه مرحله‌ی build لازم دارد، نه ابزار بیرونی، و برای عکس‌هایی که
 * بعداً از پنل ادمین آپلود می‌شوند هم خودکار کار می‌کند.
 *
 * WebP فقط وقتی ساخته می‌شود که مرورگر در هدر Accept اعلامش کند،
 * پس آدرس دو نسخه فرق دارد و کش CDN قاطی نمی‌شود.
 *
 * اگر GD نبود یا تبدیل شکست خورد، آدرس اصلی برگردانده می‌شود —
 * صفحه هرگز به‌خاطر بهینه‌سازی نمی‌شکند.
 */
final class Images
{
    /** عرض‌هایی که واقعاً در قالب‌ها استفاده می‌شوند */
    public const WIDTHS = [400, 600, 900, 1600];

    public function __construct(
        private string $webRoot,
        private string $srcDir  = '/assets/img',
        private string $cacheDir = '/assets/cache/img'
    ) {}

    public static function supportsWebp(): bool
    {
        return function_exists('imagewebp')
            && str_contains((string) ($_SERVER['HTTP_ACCEPT'] ?? ''), 'image/webp');
    }

    /**
     * آدرس نسخه‌ی بهینه را برمی‌گرداند و در صورت نبود، می‌سازدش.
     *
     * @param string $rel مسیر نسبی داخل assets/img، مثل doctors/khalili.jpg
     * @param int    $w   عرض هدف بر حسب پیکسل (به نزدیک‌ترین اندازه گرد می‌شود)
     */
    public function url(string $rel, int $w): string
    {
        $rel = ltrim($rel, '/');
        $src = $this->webRoot . $this->srcDir . '/' . $rel;

        if ($rel === '' || !is_file($src)) {
            return $this->srcDir . '/' . $rel;
        }

        $w   = $this->snap($w);
        $ext = self::supportsWebp() ? 'webp' : $this->sourceExt($src);
        $out = sprintf('%s/%d/%s.%s', $this->cacheDir, $w, $this->stripExt($rel), $ext);
        $abs = $this->webRoot . $out;

        // کش معتبر است اگر بعد از فایل اصلی ساخته شده باشد
        if (is_file($abs) && filemtime($abs) >= filemtime($src)) {
            return $out;
        }

        return $this->generate($src, $abs, $w, $ext) ? $out : $this->srcDir . '/' . $rel;
    }

    private function snap(int $w): int
    {
        foreach (self::WIDTHS as $candidate) {
            if ($w <= $candidate) {
                return $candidate;
            }
        }
        return (int) end(self::WIDTHS);
    }

    private function stripExt(string $p): string
    {
        return preg_replace('/\.[a-z0-9]+$/i', '', $p) ?? $p;
    }

    private function sourceExt(string $src): string
    {
        $e = strtolower(pathinfo($src, PATHINFO_EXTENSION));
        return in_array($e, ['jpg', 'jpeg', 'png', 'webp'], true) ? ($e === 'jpeg' ? 'jpg' : $e) : 'jpg';
    }

    private function generate(string $src, string $abs, int $w, string $ext): bool
    {
        if (!function_exists('imagecreatetruecolor')) {
            return false;   // GD نصب نیست
        }

        $info = @getimagesize($src);
        if ($info === false) {
            return false;
        }
        [$sw, $sh] = $info;
        if ($sw <= 0 || $sh <= 0) {
            return false;
        }

        // عکس کوچک‌تر از هدف را بزرگ نکن
        $tw = min($w, $sw);
        $th = (int) round($sh * ($tw / $sw));

        $img = match ($info[2]) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($src),
            IMAGETYPE_PNG  => @imagecreatefrompng($src),
            IMAGETYPE_WEBP => function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($src) : false,
            default        => false,
        };
        if ($img === false) {
            return false;
        }

        $dst = imagecreatetruecolor($tw, $th);
        if ($info[2] === IMAGETYPE_PNG) {
            imagealphablending($dst, false);
            imagesavealpha($dst, true);
        }
        imagecopyresampled($dst, $img, 0, 0, 0, 0, $tw, $th, $sw, $sh);
        imagedestroy($img);

        $dir = dirname($abs);
        if (!is_dir($dir) && !@mkdir($dir, 0755, true) && !is_dir($dir)) {
            imagedestroy($dst);
            return false;
        }

        // نوشتن اتمیک تا درخواست هم‌زمان فایل نیم‌ساخته نبیند
        $tmp = $abs . '.' . bin2hex(random_bytes(4)) . '.tmp';
        $ok  = match ($ext) {
            'webp' => function_exists('imagewebp') && @imagewebp($dst, $tmp, 82),
            'png'  => @imagepng($dst, $tmp, 6),
            default=> @imagejpeg($dst, $tmp, 82),
        };
        imagedestroy($dst);

        if (!$ok) {
            @unlink($tmp);
            return false;
        }
        if (!@rename($tmp, $abs)) {
            @unlink($tmp);
            return false;
        }
        return true;
    }
}
