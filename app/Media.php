<?php
declare(strict_types=1);

/**
 * کتابخانه‌ی رسانه — عکس و ویدیو.
 *
 * دو مسئولیت دارد: گرفتن فایل از پنل و اعتبارسنجی‌اش، و خواندن
 * رسانه‌ی هر موجودیت برای نمایش در سایت.
 *
 * درباره‌ی امنیت بارگذاری: پسوند فایل هیچ تضمینی نیست. یک فایل
 * PHP با نام ‎.jpg اگر در ریشه‌ی وب بنشیند و سرور اجرایش کند، کل
 * سایت از دست رفته است. پس سه لایه گذاشته‌ایم:
 *   ۱. نوع واقعی فایل از محتوایش خوانده می‌شود، نه از پسوند
 *   ۲. نام فایل از نو ساخته می‌شود و هرگز از ورودی کاربر نمی‌آید
 *   ۳. پوشه‌ی uploads با ‎.htaccess اجرای اسکریپت را می‌بندد
 */
final class Media
{
    /** بیشترین حجم مجاز */
    public const MAX_IMAGE = 12 * 1024 * 1024;
    public const MAX_VIDEO = 128 * 1024 * 1024;

    /** نوع‌هایی که می‌پذیریم؛ هرچه بیرون این فهرست است رد می‌شود */
    private const IMAGE_TYPES = [
        IMAGETYPE_JPEG => ['jpg',  'image/jpeg'],
        IMAGETYPE_PNG  => ['png',  'image/png'],
        IMAGETYPE_WEBP => ['webp', 'image/webp'],
    ];
    private const VIDEO_TYPES = [
        'video/mp4'       => 'mp4',
        'video/webm'      => 'webm',
        'video/quicktime' => 'mov',
    ];

    public function __construct(
        private Database $db,
        private string $uploadDir,              // مسیر مطلق روی دیسک
        private string $uploadUrl = '/assets/uploads',
        private ?Images $images = null          // برای پردازش هنگام بارگذاری
    ) {}

    // ---------------------------------------------------------------
    //  خواندن
    // ---------------------------------------------------------------

    /**
     * رسانه‌ی یک موجودیت در یک نقش.
     *
     * @param string $type doctor | clinic | page | site
     * @param string $role profile | gallery
     * @param string $kind image | video | all
     */
    public function forEntity(
        string $type,
        int $id,
        string $role = 'gallery',
        string $kind = 'image',
        int $limit = 60
    ): array {
        $sql = 'SELECT m.*, t.sort AS tag_sort
                  FROM media m
                  JOIN media_tag t ON t.media_id = m.id
                 WHERE t.entity_type = ? AND t.entity_id = ? AND t.role = ?
                   AND m.is_active = 1';
        $args = [$type, $id, $role];

        if ($kind !== 'all') {
            $sql .= ' AND m.kind = ?';
            $args[] = $kind;
        }
        $sql .= ' ORDER BY t.sort ASC, m.sort ASC, m.id ASC LIMIT ' . (int) $limit;

        return $this->db->all($sql, $args);
    }

    /**
     * عکس‌های پروفایل یک موجودیت — ممکن است بیش از یکی باشد و در
     * فهرست‌ها نوبتی عوض شوند.
     */
    public function profiles(string $type, int $id, int $limit = 6): array
    {
        return $this->forEntity($type, $id, 'profile', 'image', $limit);
    }

    /**
     * عکس پروفایل یک دسته موجودیت، با یک کوئری.
     *
     * بدون این، صفحه‌ی فهرست پزشکان برای هر کارت یک کوئری می‌زند و
     * می‌شود N+1 — روی ۱۶ پزشک یعنی ۱۶ رفت‌وبرگشت اضافه.
     *
     * @return array<int, array<int, array>> کلید = entity_id
     */
    public function profilesFor(string $type, array $ids): array
    {
        $ids = array_values(array_unique(array_map('intval', $ids)));
        if ($ids === []) {
            return [];
        }
        $in   = implode(', ', array_fill(0, count($ids), '?'));
        $rows = $this->db->all(
            "SELECT t.entity_id, m.*
               FROM media m
               JOIN media_tag t ON t.media_id = m.id
              WHERE t.entity_type = ? AND t.role = 'profile'
                AND m.kind = 'image' AND m.is_active = 1
                AND t.entity_id IN ($in)
              ORDER BY t.entity_id ASC, t.sort ASC, m.id ASC",
            array_merge([$type], $ids)
        );

        $out = [];
        foreach ($rows as $r) {
            $out[(int) $r['entity_id']][] = $r;
        }
        return $out;
    }

    /** گالری عمومی کل کلینیک، با امکان فیلتر روی یک موجودیت */
    public function siteGallery(
        string $kind = 'all',
        ?string $filterType = null,
        ?int $filterId = null,
        int $limit = 200
    ): array {
        if ($filterType !== null && $filterId !== null) {
            // هر فایلی که به این موجودیت تگ خورده، در هر نقشی
            $sql = 'SELECT DISTINCT m.*
                      FROM media m
                      JOIN media_tag t ON t.media_id = m.id
                     WHERE t.entity_type = ? AND t.entity_id = ?
                       AND m.is_active = 1';
            $args = [$filterType, $filterId];
        } else {
            $sql = "SELECT DISTINCT m.*
                      FROM media m
                      JOIN media_tag t ON t.media_id = m.id
                     WHERE t.entity_type = 'site' AND t.role = 'gallery'
                       AND m.is_active = 1";
            $args = [];
        }
        if ($kind !== 'all') {
            $sql .= ' AND m.kind = ?';
            $args[] = $kind;
        }
        $sql .= ' ORDER BY m.sort ASC, m.created_at DESC, m.id DESC LIMIT ' . (int) $limit;

        return $this->db->all($sql, $args);
    }

    /**
     * موجودیت‌هایی که در گالری عمومی تگ خورده‌اند — دکمه‌های فیلتر
     * فقط برای همین‌ها ساخته می‌شود تا فیلترِ بی‌نتیجه نداشته باشیم.
     */
    public function galleryFacets(): array
    {
        $rows = $this->db->all(
            "SELECT t.entity_type, t.entity_id, COUNT(DISTINCT m.id) AS n
               FROM media_tag t
               JOIN media m ON m.id = t.media_id
              WHERE m.is_active = 1 AND t.entity_type <> 'site'
              GROUP BY t.entity_type, t.entity_id
              HAVING n > 0
              ORDER BY n DESC"
        );

        $names = ['doctor' => [], 'clinic' => [], 'page' => []];
        foreach ([['doctor', 'doctors'], ['clinic', 'clinics'], ['page', 'pages']] as [$type, $table]) {
            $col = $table === 'pages' ? 'title' : 'name';
            foreach ($this->db->all("SELECT id, $col AS label FROM $table") as $r) {
                $names[$type][(int) $r['id']] = $r['label'];
            }
        }

        $out = [];
        foreach ($rows as $r) {
            $label = $names[$r['entity_type']][(int) $r['entity_id']] ?? null;
            if ($label === null) {
                continue;               // موجودیت حذف شده
            }
            $out[] = [
                'type'  => $r['entity_type'],
                'id'    => (int) $r['entity_id'],
                'label' => $label,
                'n'     => (int) $r['n'],
            ];
        }
        return $out;
    }

    /** تگ‌های یک فایل، برای فرم ویرایش */
    public function tags(int $mediaId): array
    {
        return $this->db->all(
            'SELECT * FROM media_tag WHERE media_id = ? ORDER BY entity_type, sort',
            [$mediaId]
        );
    }

    public function find(int $id): ?array
    {
        return $this->db->one('SELECT * FROM media WHERE id = ?', [$id]);
    }

    /** فهرست کتابخانه برای پنل */
    public function browse(array $f = [], int $limit = 60, int $offset = 0): array
    {
        [$where, $args] = $this->browseWhere($f);
        return $this->db->all(
            "SELECT * FROM media WHERE $where
              ORDER BY created_at DESC, id DESC
              LIMIT " . (int) $limit . ' OFFSET ' . (int) $offset,
            $args
        );
    }

    public function countAll(array $f = []): int
    {
        [$where, $args] = $this->browseWhere($f);
        return (int) $this->db->value("SELECT COUNT(*) FROM media WHERE $where", $args);
    }

    private function browseWhere(array $f): array
    {
        $where = '1 = 1';
        $args  = [];

        if (!empty($f['kind'])) {
            $where .= ' AND kind = ?';
            $args[] = $f['kind'];
        }
        if (!empty($f['q'])) {
            $where .= ' AND (title LIKE ? OR alt LIKE ? OR description LIKE ?)';
            $like   = '%' . $f['q'] . '%';
            array_push($args, $like, $like, $like);
        }
        if (!empty($f['untagged'])) {
            $where .= ' AND id NOT IN (SELECT media_id FROM media_tag)';
        }
        if (!empty($f['entity_type'])) {
            $where .= ' AND id IN (SELECT media_id FROM media_tag
                                    WHERE entity_type = ? AND entity_id = ?)';
            $args[] = $f['entity_type'];
            $args[] = (int) ($f['entity_id'] ?? 0);
        }
        return [$where, $args];
    }

    // ---------------------------------------------------------------
    //  نوشتن
    // ---------------------------------------------------------------

    /**
     * ذخیره‌ی یک فایل بارگذاری‌شده.
     *
     * @param array $file یک عضو از $_FILES
     * @throws RuntimeException با پیام فارسیِ قابل نمایش به کاربر
     */
    public function store(array $file, array $meta = [], ?int $adminId = null): array
    {
        $this->assertUploadOk($file);

        $ext     = strtolower(pathinfo((string) $file['name'], PATHINFO_EXTENSION));
        $isVideo = str_starts_with((string) ($file['type'] ?? ''), 'video/')
                || in_array($ext, ['mp4', 'webm', 'mov'], true);

        return $isVideo
            ? $this->storeVideo($file, $meta, $adminId)
            : $this->storeImage($file, $meta, $adminId);
    }

    private function storeImage(array $file, array $meta, ?int $adminId): array
    {
        if ($file['size'] > self::MAX_IMAGE) {
            throw new RuntimeException('حجم عکس بیش از ۱۲ مگابایت است.');
        }

        // نوع واقعی از محتوای فایل خوانده می‌شود، نه از پسوند
        $info = @getimagesize($file['tmp_name']);
        if ($info === false || !isset(self::IMAGE_TYPES[$info[2]])) {
            throw new RuntimeException('این فایل عکس معتبر نیست. فقط JPG و PNG و WebP پذیرفته می‌شود.');
        }

        $sub = 'gallery/' . date('Y/m');

        // عکس خام ذخیره نمی‌شود: اول چرخانده، کوچک و بازفشرده
        // می‌شود. پسوند نهایی را خود پردازش تعیین می‌کند، چون
        // ممکن است PNGِ بدون شفافیت به JPEG تبدیل شود.
        if ($this->images !== null) {
            // نام موقت با نقطه شروع می‌شود تا اگر کار نیمه‌کاره ماند،
            // ‎.htaccess اصلی جلوی سرو شدنش را بگیرد
            $stage = $this->uploadDir . '/' . $sub . '/.ingest-' . bin2hex(random_bytes(6));
            $out   = $this->images->ingest($file['tmp_name'], $stage);

            if ($out !== null) {
                // پسوند نهایی را پردازش تعیین کرده، پس نام یکتا
                // بعد از آن انتخاب می‌شود
                $name = $this->uniqueName($sub, $meta['slug'] ?? 'img', $out['ext']);
                if (@rename($stage, $this->uploadDir . '/' . $sub . '/' . $name)) {
                    return $this->record([
                        'kind'     => 'image',
                        'filename' => $sub . '/' . $name,
                        'mime'     => $out['mime'],
                        'width'    => $out['width'],
                        'height'   => $out['height'],
                        'bytes'    => $out['bytes'],
                    ], $meta, $adminId);
                }
            }
            @unlink($stage);
        }

        // GD نبود یا پردازش شکست خورد — فایل اصلی ذخیره می‌شود تا
        // بارگذاری بی‌صدا از دست نرود. نسخه‌های کوچک همچنان در
        // لحظه ساخته می‌شوند.
        [$ext, $mime] = self::IMAGE_TYPES[$info[2]];
        $name = $this->uniqueName($sub, $meta['slug'] ?? 'img', $ext);
        $this->moveInto($file['tmp_name'], $sub . '/' . $name);

        return $this->record([
            'kind'     => 'image',
            'filename' => $sub . '/' . $name,
            'mime'     => $mime,
            'width'    => $info[0],
            'height'   => $info[1],
            'bytes'    => (int) $file['size'],
        ], $meta, $adminId);
    }

    private function storeVideo(array $file, array $meta, ?int $adminId): array
    {
        if ($file['size'] > self::MAX_VIDEO) {
            throw new RuntimeException(
                'حجم ویدیو بیش از ۱۲۸ مگابایت است. برای ویدیوی بلندتر آن را در آپارات بگذارید و نشانی‌اش را وارد کنید.'
            );
        }

        $mime = $this->sniffMime($file['tmp_name']);
        if (!isset(self::VIDEO_TYPES[$mime])) {
            throw new RuntimeException('این فایل ویدیو معتبر نیست. فقط MP4 و WebM پذیرفته می‌شود.');
        }
        $ext  = self::VIDEO_TYPES[$mime];
        $sub  = 'video/' . date('Y/m');
        $name = $this->uniqueName($sub, $meta['slug'] ?? 'vid', $ext);
        $this->moveInto($file['tmp_name'], $sub . '/' . $name);

        return $this->record([
            'kind'     => 'video',
            'filename' => $sub . '/' . $name,
            'mime'     => $mime,
            'bytes'    => (int) $file['size'],
        ], $meta, $adminId);
    }

    /** ویدیوی آپارات یا یوتیوب — فایلی ذخیره نمی‌شود */
    public function storeEmbed(string $url, array $meta = [], ?int $adminId = null): array
    {
        $url = trim($url);
        if (!filter_var($url, FILTER_VALIDATE_URL) || !preg_match('~^https://~i', $url)) {
            throw new RuntimeException('نشانی ویدیو باید یک آدرس کامل با https باشد.');
        }
        $host = strtolower((string) parse_url($url, PHP_URL_HOST));
        $ok   = ['aparat.com', 'www.aparat.com', 'youtube.com', 'www.youtube.com', 'youtu.be'];
        if (!in_array($host, $ok, true)) {
            throw new RuntimeException('فقط ویدیوی آپارات و یوتیوب پذیرفته می‌شود.');
        }
        return $this->record(['kind' => 'video', 'embed_url' => $url], $meta, $adminId);
    }

    /** درج ردیف در جدول */
    private function record(array $core, array $meta, ?int $adminId): array
    {
        $row = $core + [
            'filename'    => null,
            'embed_url'   => null,
            'poster'      => null,
            'mime'        => null,
            'width'       => null,
            'height'      => null,
            'bytes'       => null,
            'alt'         => $this->clip($meta['alt']   ?? null, 255),
            'title'       => $this->clip($meta['title'] ?? null, 200),
            'description' => $this->blankToNull($meta['description'] ?? null),
            'taken_on'    => $this->blankToNull($meta['taken_on']    ?? null),
            'sort'        => (int) ($meta['sort'] ?? 0),
            'is_active'   => 1,
            'uploaded_by' => $adminId,
        ];

        $cols = array_keys($row);
        $this->db->run(
            'INSERT INTO media (' . implode(', ', $cols) . ') VALUES ('
            . implode(', ', array_fill(0, count($cols), '?')) . ')',
            array_values($row)
        );
        $row['id'] = (int) $this->db->lastId();
        return $row;
    }

    public function update(int $id, array $meta): void
    {
        $this->db->run(
            'UPDATE media
                SET title = ?, alt = ?, description = ?, taken_on = ?,
                    sort = ?, is_active = ?
              WHERE id = ?',
            [
                $this->clip($meta['title'] ?? null, 200),
                $this->clip($meta['alt']   ?? null, 255),
                $this->blankToNull($meta['description'] ?? null),
                $this->blankToNull($meta['taken_on']    ?? null),
                (int) ($meta['sort'] ?? 0),
                empty($meta['is_active']) ? 0 : 1,
                $id,
            ]
        );
    }

    /**
     * جایگزینی کامل تگ‌های یک فایل.
     *
     * @param array $tags ردیف‌هایی به شکل ['type' => , 'id' => , 'role' => ]
     */
    public function retag(int $mediaId, array $tags, string $kind = 'image'): void
    {
        $this->db->run('DELETE FROM media_tag WHERE media_id = ?', [$mediaId]);

        $seen = [];
        $i    = 0;
        foreach ($tags as $t) {
            $type = (string) ($t['type'] ?? '');
            if (!in_array($type, ['doctor', 'clinic', 'page', 'site'], true)) {
                continue;
            }
            $eid = $type === 'site' ? 0 : (int) ($t['id'] ?? 0);
            if ($type !== 'site' && $eid <= 0) {
                continue;
            }
            // ویدیو عکس پروفایل نمی‌شود
            $role = ($t['role'] ?? 'gallery') === 'profile' && $kind === 'image'
                ? 'profile'
                : 'gallery';

            $key = "$type:$eid:$role";
            if (isset($seen[$key])) {
                continue;
            }
            $seen[$key] = true;

            $this->db->run(
                'INSERT INTO media_tag (media_id, entity_type, entity_id, role, sort)
                 VALUES (?, ?, ?, ?, ?)',
                [$mediaId, $type, $eid, $role, $i++]
            );
        }
    }

    /** حذف ردیف و فایلش از دیسک */
    public function forget(int $id): void
    {
        $m = $this->find($id);
        if ($m === null) {
            return;
        }
        foreach ([$m['filename'] ?? null, $m['poster'] ?? null] as $rel) {
            if ($rel) {
                $abs = $this->safePath((string) $rel);
                if ($abs !== null && is_file($abs)) {
                    @unlink($abs);
                }
            }
        }
        // media_tag با ON DELETE CASCADE خودش پاک می‌شود
        $this->db->run('DELETE FROM media WHERE id = ?', [$id]);
    }

    /**
     * پاک‌سازی تگ‌های یتیم.
     *
     * entity_id چندریختی است و کلید خارجی ندارد، پس وقتی پزشکی یا
     * بخشی حذف می‌شود ردیف تگش جا می‌ماند.
     */
    public function pruneOrphanTags(): int
    {
        $n = 0;
        foreach ([['doctor', 'doctors'], ['clinic', 'clinics'], ['page', 'pages']] as [$type, $table]) {
            $n += $this->db->run(
                "DELETE FROM media_tag
                  WHERE entity_type = ?
                    AND entity_id NOT IN (SELECT id FROM $table)",
                [$type]
            );
        }
        return $n;
    }

    // ---------------------------------------------------------------
    //  کمکی
    // ---------------------------------------------------------------

    /** نشانی وب فایل */
    public function url(array $m): string
    {
        if (!empty($m['embed_url'])) {
            return (string) $m['embed_url'];
        }
        return $this->uploadUrl . '/' . ltrim((string) ($m['filename'] ?? ''), '/');
    }

    /**
     * مسیر نسبی برای Images::url.
     *
     * Images ریشه‌اش assets/img است و uploads کنارش می‌نشیند، پس با
     * ‎../ از آن بیرون می‌آییم. Images خودش مسیر را نرمال می‌کند.
     */
    public function imagePath(array $m): string
    {
        return '../uploads/' . ltrim((string) ($m['filename'] ?? ''), '/');
    }

    private function assertUploadOk(array $file): void
    {
        $err = $file['error'] ?? UPLOAD_ERR_NO_FILE;
        if ($err !== UPLOAD_ERR_OK) {
            throw new RuntimeException(match ($err) {
                UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE =>
                    'فایل از حد مجاز سرور بزرگ‌تر است.',
                UPLOAD_ERR_PARTIAL =>
                    'بارگذاری نیمه‌کاره ماند؛ دوباره تلاش کنید.',
                UPLOAD_ERR_NO_FILE =>
                    'فایلی انتخاب نشده است.',
                UPLOAD_ERR_NO_TMP_DIR, UPLOAD_ERR_CANT_WRITE =>
                    'سرور نتوانست فایل را بنویسد. دسترسی پوشه‌ی uploads را بررسی کنید.',
                default =>
                    'بارگذاری ناموفق بود.',
            });
        }
        if (!is_uploaded_file($file['tmp_name'])) {
            throw new RuntimeException('فایل معتبر نیست.');
        }
    }

    private function sniffMime(string $path): string
    {
        if (function_exists('finfo_open')) {
            $fi = finfo_open(FILEINFO_MIME_TYPE);
            if ($fi !== false) {
                $m = finfo_file($fi, $path);
                finfo_close($fi);
                if (is_string($m)) {
                    return strtolower($m);
                }
            }
        }
        return 'application/octet-stream';
    }

    /**
     * نام فایل از نو ساخته می‌شود.
     *
     * نام ورودی کاربر هرگز وارد مسیر نمی‌شود؛ فقط به‌عنوان پیشوندی
     * خوانا از آن استفاده می‌کنیم و آن هم فیلتر می‌شود.
     */
    private function uniqueName(string $sub, string $hint, string $ext): string
    {
        $hint = preg_replace('~[^a-z0-9\-]+~i', '-', (string) $hint) ?? '';
        $hint = strtolower(trim($hint, '-'));
        $hint = $hint === '' ? 'file' : substr($hint, 0, 40);

        do {
            $name = $hint . '-' . bin2hex(random_bytes(4)) . '.' . $ext;
        } while (is_file($this->uploadDir . '/' . $sub . '/' . $name));

        return $name;
    }

    private function moveInto(string $tmp, string $rel): void
    {
        $abs = $this->uploadDir . '/' . $rel;
        $dir = dirname($abs);
        if (!is_dir($dir) && !@mkdir($dir, 0775, true) && !is_dir($dir)) {
            throw new RuntimeException('پوشه‌ی مقصد ساخته نشد: ' . $dir);
        }
        if (!move_uploaded_file($tmp, $abs)) {
            throw new RuntimeException('فایل ذخیره نشد. دسترسی نوشتن پوشه‌ی uploads را بررسی کنید.');
        }
        @chmod($abs, 0644);
    }

    /**
     * مسیر مطلق یک فایل، فقط اگر واقعاً داخل پوشه‌ی uploads باشد.
     *
     * filename از دیتابیس می‌آید و دیتابیس را پنل پر می‌کند، ولی
     * حذف فایل عملیاتی است که اشتباهش برگشت ندارد؛ پس پیش از
     * unlink مسیر را می‌سنجیم تا ‎../ نتواند بیرون ببردمان.
     */
    private function safePath(string $rel): ?string
    {
        $base = realpath($this->uploadDir);
        $abs  = realpath($this->uploadDir . '/' . $rel);
        if ($base === false || $abs === false) {
            return null;
        }
        return str_starts_with($abs, $base . DIRECTORY_SEPARATOR) ? $abs : null;
    }

    private function clip(?string $s, int $len): ?string
    {
        $s = trim((string) $s);
        return $s === '' ? null : mb_substr($s, 0, $len);
    }

    private function blankToNull(?string $s): ?string
    {
        $s = trim((string) $s);
        return $s === '' ? null : $s;
    }
}
