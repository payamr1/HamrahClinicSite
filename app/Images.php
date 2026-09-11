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

        // مسیر باید داخل ریشه‌ی وب بماند. از وقتی رسانه‌ی پنل هم از
        // همین‌جا رد می‌شود، $rel می‌تواند از دیتابیس بیاید و
        // «..» داشته باشد — پس فرض نمی‌کنیم بی‌خطر است.
        $real = realpath($src);
        $root = realpath($this->webRoot);
        if ($real === false || $root === false || !str_starts_with($real, $root . DIRECTORY_SEPARATOR)) {
            return $this->srcDir . '/' . $rel;
        }

        $w   = $this->snap($w);
        $ext = self::supportsWebp() ? 'webp' : $this->sourceExt($src);

        // کلید کش نباید «..» داشته باشد، وگرنه فایل کش بیرون از
        // پوشه‌ی کش نوشته می‌شود. مسیرِ uploads که با ../ می‌آید
        // اینجا صاف می‌شود.
        $key = str_replace(['../', './'], ['_', ''], $rel);
        $out = sprintf('%s/%d/%s.%s', $this->cacheDir, $w, $this->stripExt($key), $ext);
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

    /**
     * آماده‌سازی فایل تازه‌ی بارگذاری‌شده، پیش از ذخیره‌ی دائمی.
     *
     * چرا لازم است: دوربین موبایل امروز عکس ۱۲ مگاپیکسلی و چهار
     * مگابایتی می‌دهد. نگه داشتن آن روی هاست هم فضا می‌برد و هم
     * هر بار ساختن نسخه‌ی کوچک از آن، حافظه‌ی زیادی می‌خواهد.
     *
     * سه کار انجام می‌شود:
     *
     *  ۱. چرخش. عکس موبایل معمولاً افقی ذخیره می‌شود و زاویه‌اش
     *     در EXIF می‌نشیند. اگر پیش از پردازش نچرخانیمش، چون
     *     بازنویسی EXIF را پاک می‌کند، عکس تا ابد کج می‌ماند.
     *
     *  ۲. کوچک کردن تا بلندترین ضلع. بزرگ‌تر از این در هیچ قاب
     *     سایت دیده نمی‌شود.
     *
     *  ۳. بازفشرده‌سازی. همین‌جا EXIF هم می‌افتد — که جدا از حجم،
     *     برای عکسی که در کلینیک گرفته شده اهمیت دارد: عکس موبایل
     *     مختصات جغرافیایی با خودش می‌آورد و آن نباید روی سایت
     *     عمومی منتشر شود.
     *
     * اگر نتیجه از فایل اصلی بزرگ‌تر شد و کوچک‌کردنی هم لازم نبود،
     * همان اصلی نگه داشته می‌شود؛ عکسی که از قبل بهینه است نباید
     * با بازفشرده‌سازی بدتر شود.
     *
     * @return array{width:int, height:int, bytes:int, mime:string, ext:string, note:string}|null
     */
    public function ingest(string $src, string $dest, int $maxEdge = 2400, int $quality = 82): ?array
    {
        if (!function_exists('imagecreatetruecolor')) {
            return null;
        }
        $info = @getimagesize($src);
        if ($info === false) {
            return null;
        }
        [$sw, $sh] = $info;
        $type = $info[2];
        if ($sw <= 0 || $sh <= 0) {
            return null;
        }
        if (!$this->canAfford($sw, $sh)) {
            return null;                       // حافظه نمی‌رسد
        }

        $img = match ($type) {
            IMAGETYPE_JPEG => @imagecreatefromjpeg($src),
            IMAGETYPE_PNG  => @imagecreatefrompng($src),
            IMAGETYPE_WEBP => function_exists('imagecreatefromwebp') ? @imagecreatefromwebp($src) : false,
            default        => false,
        };
        if ($img === false) {
            return null;
        }

        // ---- ۱. چرخش بر اساس EXIF ----
        $rotated = false;
        if ($type === IMAGETYPE_JPEG && function_exists('exif_read_data')) {
            $exif = @exif_read_data($src);
            $deg  = match ((int) ($exif['Orientation'] ?? 1)) {
                3       => 180,
                6       => -90,
                8       => 90,
                default => 0,
            };
            if ($deg !== 0) {
                $turned = @imagerotate($img, $deg, 0);
                if ($turned !== false) {
                    imagedestroy($img);
                    $img     = $turned;
                    $sw      = imagesx($img);
                    $sh      = imagesy($img);
                    $rotated = true;
                }
            }
        }

        // ---- ۲. اندازه‌ی هدف، بر پایه‌ی بلندترین ضلع ----
        $long  = max($sw, $sh);
        $scale = $long > $maxEdge ? $maxEdge / $long : 1.0;   // هرگز بزرگ نمی‌کنیم
        $tw    = max(1, (int) round($sw * $scale));
        $th    = max(1, (int) round($sh * $scale));
        $resized = $scale < 1.0;

        // ---- ۳. قالب خروجی ----
        // PNG فقط وقتی می‌ماند که واقعاً شفافیت داشته باشد؛ عکس
        // معمولیِ ذخیره‌شده در PNG چند برابر همان در JPEG وزن دارد.
        $hasAlpha = $type === IMAGETYPE_PNG && $this->hasAlpha($img, $sw, $sh);
        [$ext, $mime] = match (true) {
            $hasAlpha                                     => ['png',  'image/png'],
            $type === IMAGETYPE_WEBP && function_exists('imagewebp') => ['webp', 'image/webp'],
            default                                       => ['jpg',  'image/jpeg'],
        };

        $dst = imagecreatetruecolor($tw, $th);
        if ($hasAlpha) {
            imagealphablending($dst, false);
            imagesavealpha($dst, true);
        } else {
            // پس‌زمینه‌ی سفید، تا شفافیتِ حذف‌شده سیاه از کار درنیاید
            imagefilledrectangle($dst, 0, 0, $tw, $th, imagecolorallocate($dst, 255, 255, 255));
        }
        imagecopyresampled($dst, $img, 0, 0, 0, 0, $tw, $th, $sw, $sh);
        imagedestroy($img);

        $dir = dirname($dest);
        if (!is_dir($dir) && !@mkdir($dir, 0775, true) && !is_dir($dir)) {
            imagedestroy($dst);
            return null;
        }

        $tmp = $dest . '.' . bin2hex(random_bytes(4)) . '.tmp';
        $ok  = match ($ext) {
            'webp' => @imagewebp($dst, $tmp, $quality),
            'png'  => @imagepng($dst, $tmp, 6),
            default => @imagejpeg($dst, $tmp, $quality),
        };
        imagedestroy($dst);

        if (!$ok || !is_file($tmp)) {
            @unlink($tmp);
            return null;
        }

        $newBytes = (int) filesize($tmp);
        $oldBytes = (int) filesize($src);

        // نتیجه بدتر از اصل و تغییری هم لازم نبود → همان اصلی
        if (!$resized && !$rotated && $newBytes >= $oldBytes && $ext === $this->extOf($type)) {
            @unlink($tmp);
            if (!@copy($src, $dest)) {
                return null;
            }
            @chmod($dest, 0644);
            return [
                'width' => $sw, 'height' => $sh, 'bytes' => $oldBytes,
                'mime'  => $info['mime'] ?? $mime, 'ext' => $ext,
                'note'  => 'از قبل بهینه بود',
            ];
        }

        if (!@rename($tmp, $dest)) {
            @unlink($tmp);
            return null;
        }
        @chmod($dest, 0644);

        $saved = $oldBytes > 0 ? (int) round(100 - ($newBytes / $oldBytes * 100)) : 0;
        return [
            'width' => $tw, 'height' => $th, 'bytes' => $newBytes,
            'mime'  => $mime, 'ext' => $ext,
            'note'  => $saved > 0 ? "{$saved}٪ سبک‌تر شد" : 'بازفشرده شد',
        ];
    }

    /** پسوند متناظر یک نوع تصویر */
    private function extOf(int $type): string
    {
        return match ($type) {
            IMAGETYPE_PNG  => 'png',
            IMAGETYPE_WEBP => 'webp',
            default        => 'jpg',
        };
    }

    /**
     * آیا این PNG واقعاً پیکسل نیمه‌شفاف دارد؟
     *
     * نمونه‌برداری می‌کنیم نه پیمایش کامل: روی عکس بزرگ، خواندن
     * تک‌تک پیکسل‌ها از خود تغییر اندازه کندتر می‌شود.
     */
    private function hasAlpha(\GdImage $img, int $w, int $h): bool
    {
        $stepX = max(1, (int) ($w / 64));
        $stepY = max(1, (int) ($h / 64));

        for ($x = 0; $x < $w; $x += $stepX) {
            for ($y = 0; $y < $h; $y += $stepY) {
                if (((imagecolorat($img, $x, $y) >> 24) & 0x7F) > 0) {
                    return true;
                }
            }
        }
        return false;
    }

    /**
     * آیا حافظه‌ی باقی‌مانده برای باز کردن این عکس کافی است؟
     *
     * GD هر پیکسل را ۴ بایت در حافظه نگه می‌دارد و ما هم‌زمان مبدأ
     * و مقصد را باز داریم. بدون این بررسی، یک عکس بزرگ به‌جای
     * پیام خطا، کل درخواست را با fatal error می‌کشد.
     */
    private function canAfford(int $w, int $h): bool
    {
        $limit = $this->memoryLimitBytes();
        if ($limit <= 0) {
            return true;                       // بی‌حد
        }
        $need = (int) ($w * $h * 4 * 2.1) + 2 * 1024 * 1024;
        return ($limit - memory_get_usage(true)) > $need;
    }

    private function memoryLimitBytes(): int
    {
        $raw = trim((string) ini_get('memory_limit'));
        if ($raw === '' || $raw === '-1') {
            return 0;
        }
        $n = (int) $raw;
        return match (strtolower(substr($raw, -1))) {
            'g'     => $n * 1024 * 1024 * 1024,
            'm'     => $n * 1024 * 1024,
            'k'     => $n * 1024,
            default => $n,
        };
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
