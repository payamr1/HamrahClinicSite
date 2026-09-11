-- ============================================================
--  همراه کلینیک — ساختار دیتابیس
--  MySQL 5.7+ / MariaDB 10.2+   ·   utf8mb4   ·   InnoDB
--
--  اصل طراحی: جدول pages تنها مرجع آدرس‌هاست.
--  هر ۸۲ آدرس فعلی سایت یک ردیف در همین جدول دارند و ستون path
--  دقیقاً همان مسیری است که امروز در گوگل ایندکس شده است.
--  هیچ آدرسی نباید بدون ثبت ریدایرکت در جدول redirects تغییر کند.
-- ============================================================

SET NAMES utf8mb4;

-- ------------------------------------------------------------
-- کلینیک‌های تخصصی (۹ بخش)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clinics (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
  slug         VARCHAR(120)  NOT NULL,
  name         VARCHAR(160)  NOT NULL,
  tagline      VARCHAR(255)      NULL,
  summary      TEXT              NULL,
  image        VARCHAR(255)      NULL,
  page_id      INT UNSIGNED      NULL  COMMENT 'صفحه معرفی این کلینیک',
  sort         SMALLINT      NOT NULL DEFAULT 0,
  is_active    TINYINT(1)    NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_clinic_slug (slug),
  KEY idx_clinic_sort (sort)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- صفحات — مرجع یگانه همه آدرس‌ها
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pages (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,

  /*
   * path — مسیر decode شده، عیناً همان‌که در گوگل ایندکس شده.
   * دست نزنید. مثلاً صفحه‌ی دکتر فاطمه نائینی با حرف عربی ك و ي
   * ایندکس شده است؛ تبدیل آن به فارسی استاندارد یعنی آدرس جدید
   * و از دست رفتن رتبه.
   *
   * path_norm — همان مسیر با یکسان‌سازی ك→ک و ي→ی و حروف کوچک.
   * فقط برای تطبیق بخشنده استفاده می‌شود: اگر بازدیدکننده آدرس را
   * با املای دیگری وارد کند، اینجا پیدا و با ۳۰۱ به path اصلی
   * هدایت می‌شود.
   */
  path          VARCHAR(255) NOT NULL  COMMENT 'مسیر ایندکس‌شده — تغییر ممنوع',
  path_norm     VARCHAR(255) NOT NULL  COMMENT 'فرم یکسان‌شده، فقط برای تطبیق',

  type          ENUM('home','page','service','doctor','post','archive','gallery') NOT NULL,
  slug          VARCHAR(191) NOT NULL,

  title         VARCHAR(255) NOT NULL  COMMENT 'همان H1 صفحه',
  kicker        VARCHAR(160)     NULL  COMMENT 'برچسب بالای عنوان',
  lede          TEXT             NULL  COMMENT 'پاراگراف معرف زیر عنوان',
  body          MEDIUMTEXT       NULL  COMMENT 'متن اصلی، HTML محدود',
  hero_image    VARCHAR(255)     NULL,

  meta_title    VARCHAR(255) NOT NULL,
  meta_desc     VARCHAR(320) NOT NULL,
  canonical     VARCHAR(255)     NULL  COMMENT 'فقط اگر با path فرق دارد',
  noindex       TINYINT(1)   NOT NULL DEFAULT 0,
  og_image      VARCHAR(255)     NULL,

  clinic_id     INT UNSIGNED     NULL,
  parent_id     INT UNSIGNED     NULL,

  status        ENUM('published','draft') NOT NULL DEFAULT 'published',
  sort          SMALLINT     NOT NULL DEFAULT 0,
  published_at  DATE             NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  UNIQUE KEY uq_page_path (path),
  KEY idx_page_path_norm (path_norm),
  KEY idx_page_type_status (type, status),
  KEY idx_page_clinic (clinic_id),
  KEY idx_page_parent (parent_id),
  KEY idx_page_published (published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- مقدار gallery بعداً به این ENUM اضافه شد و CREATE TABLE IF NOT
-- EXISTS روی جدول موجود کاری نمی‌کند. MODIFY خودش بی‌خطرِ تکرار
-- است: اگر ستون از قبل همین تعریف را داشته باشد، عملاً کاری
-- نمی‌کند — پس نگهبان لازم ندارد.
ALTER TABLE pages MODIFY COLUMN type
  ENUM('home','page','service','doctor','post','archive','gallery') NOT NULL;

-- ------------------------------------------------------------
--  کلیدهای خارجی حلقوی
--
--  pages به clinics وابسته است و clinics به pages، پس این سه
--  کلید بعد از ساخت هر دو جدول اضافه می‌شوند.
--
--  ALTER TABLE معادل IF NOT EXISTS ندارد و اجرای دوباره‌ی فایل
--  با خطای ۱۲۱ (نام کلید تکراری) شکست می‌خورد — که MySQL آن را
--  «Can't create table» گزارش می‌کند چون ALTER داخلاً جدول موقت
--  می‌سازد. پس هر کدام قبل از افزوده شدن بررسی می‌شوند.
-- ------------------------------------------------------------

SET @fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = DATABASE()
              AND TABLE_NAME = 'pages' AND CONSTRAINT_NAME = 'fk_page_clinic');
SET @sql := IF(@fk = 0,
  'ALTER TABLE pages ADD CONSTRAINT fk_page_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE SET NULL',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = DATABASE()
              AND TABLE_NAME = 'pages' AND CONSTRAINT_NAME = 'fk_page_parent');
SET @sql := IF(@fk = 0,
  'ALTER TABLE pages ADD CONSTRAINT fk_page_parent FOREIGN KEY (parent_id) REFERENCES pages(id) ON DELETE SET NULL',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @fk := (SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
            WHERE CONSTRAINT_SCHEMA = DATABASE()
              AND TABLE_NAME = 'clinics' AND CONSTRAINT_NAME = 'fk_clinic_page');
SET @sql := IF(@fk = 0,
  'ALTER TABLE clinics ADD CONSTRAINT fk_clinic_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE SET NULL',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ------------------------------------------------------------
-- پزشکان
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctors (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  page_id       INT UNSIGNED     NULL  COMMENT 'صفحه پروفایل در جدول pages',
  name          VARCHAR(160) NOT NULL,
  specialty     VARCHAR(200) NOT NULL  COMMENT 'مثل: متخصص قلب و عروق',
  fellowship    VARCHAR(255)     NULL,
  university    VARCHAR(255)     NULL,
  license_no    VARCHAR(30)      NULL  COMMENT 'شماره پروانه؛ نوعش در license_label',
  license_label VARCHAR(60)      NULL  COMMENT 'مثل «نظام پزشکی» یا «نظام روان‌شناسی»؛ خالی یعنی نظام پزشکی',
  is_physician  TINYINT(1)   NOT NULL DEFAULT 1
                COMMENT '۰ برای مشاور و روان‌شناس — اسکیمای Physician نمی‌گیرند',
  bio           TEXT             NULL,
  photo         VARCHAR(255)     NULL,
  booking_url   VARCHAR(255)     NULL  COMMENT 'لینک نوبت‌دهی آنلاین در book.hamrahclinic.ir',
  schedule      VARCHAR(255)     NULL  COMMENT 'مثل: شنبه، دوشنبه، چهارشنبه ۹ تا ۱۴',
  is_founder    TINYINT(1)   NOT NULL DEFAULT 0,
  sort          SMALLINT     NOT NULL DEFAULT 0,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  -- بدون این کلید یکتا، ON DUPLICATE KEY UPDATE در فایل داده
  -- هیچ تکراری تشخیص نمی‌دهد و هر بار import، ۱۲ پزشک تازه
  -- اضافه می‌شود.
  UNIQUE KEY uq_doctor_name (name),
  KEY idx_doctor_sort (sort),
  KEY idx_doctor_page (page_id),
  CONSTRAINT fk_doctor_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CREATE TABLE IF NOT EXISTS روی جدول موجود کاری نمی‌کند، پس این
-- دو ستون برای دیتابیسی که قبلاً ساخته شده باید جداگانه اضافه
-- شوند. MySQL برای ADD COLUMN گزینه‌ی IF NOT EXISTS ندارد، پس
-- مثل کلیدها با information_schema نگهبانی می‌شود.
SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'doctors' AND COLUMN_NAME = 'license_label');
SET @sql := IF(@c = 0,
  'ALTER TABLE doctors ADD COLUMN license_label VARCHAR(60) NULL AFTER license_no',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'doctors' AND COLUMN_NAME = 'is_physician');
SET @sql := IF(@c = 0,
  'ALTER TABLE doctors ADD COLUMN is_physician TINYINT(1) NOT NULL DEFAULT 1 AFTER license_label',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- یک پزشک می‌تواند در چند کلینیک ویزیت داشته باشد
CREATE TABLE IF NOT EXISTS doctor_clinic (
  doctor_id  INT UNSIGNED NOT NULL,
  clinic_id  INT UNSIGNED NOT NULL,
  PRIMARY KEY (doctor_id, clinic_id),
  KEY idx_dc_clinic (clinic_id),
  CONSTRAINT fk_dc_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE CASCADE,
  CONSTRAINT fk_dc_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- نویسنده مقاله: اتصال Article به Physician برای اسکیما و E-E-A-T
CREATE TABLE IF NOT EXISTS page_author (
  page_id    INT UNSIGNED NOT NULL,
  doctor_id  INT UNSIGNED NOT NULL,
  PRIMARY KEY (page_id),
  KEY idx_pa_doctor (doctor_id),
  CONSTRAINT fk_pa_page   FOREIGN KEY (page_id)   REFERENCES pages(id)   ON DELETE CASCADE,
  CONSTRAINT fk_pa_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- لینک نوبت‌دهی روی صفحه یا کلینیک
--
-- بعضی بخش‌ها بیش از یک پزشک نوبت‌دهنده دارند و بیمار باید
-- انتخاب کند، پس جدول جداگانه لازم است نه یک ستون.
--
-- اگر label خالی باشد، دکمه بدون نام پزشک نمایش داده می‌شود —
-- برای وقتی که فقط باید بتوانند نوبت بگیرند.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_links (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  page_id    INT UNSIGNED     NULL  COMMENT 'روی یک صفحه خدمت مشخص',
  clinic_id  INT UNSIGNED     NULL  COMMENT 'یا روی کل یک کلینیک',
  label      VARCHAR(160)     NULL  COMMENT 'نام پزشک؛ خالی یعنی بدون نام',
  url        VARCHAR(255) NOT NULL,
  sort       SMALLINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_bl (page_id, clinic_id, url),
  KEY idx_bl_page (page_id, sort),
  KEY idx_bl_clinic (clinic_id, sort),
  CONSTRAINT fk_bl_page   FOREIGN KEY (page_id)   REFERENCES pages(id)   ON DELETE CASCADE,
  CONSTRAINT fk_bl_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- سؤالات متداول — منبع اسکیمای FAQPage
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS faqs (
  id        INT UNSIGNED NOT NULL AUTO_INCREMENT,
  page_id   INT UNSIGNED NOT NULL,
  question  VARCHAR(500) NOT NULL,
  answer    TEXT         NOT NULL,
  sort      SMALLINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_faq_page (page_id, sort),
  CONSTRAINT fk_faq_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- ریدایرکت‌ها — تور ایمنی سئو
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS redirects (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  from_path  VARCHAR(255) NOT NULL,
  to_path    VARCHAR(255) NOT NULL,
  code       SMALLINT     NOT NULL DEFAULT 301,
  hits       INT UNSIGNED NOT NULL DEFAULT 0,
  note       VARCHAR(255)     NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_redirect_from (from_path)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- آدرس‌هایی که ۴۰۴ خورده‌اند — برای یافتن لینک‌های شکسته بعد از مهاجرت
CREATE TABLE IF NOT EXISTS not_found_log (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  path       VARCHAR(255) NOT NULL,
  referer    VARCHAR(500)     NULL,
  hits       INT UNSIGNED NOT NULL DEFAULT 1,
  last_seen  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_404_path (path),
  KEY idx_404_hits (hits)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- رسانه
--
-- یک جدول برای عکس و ویدیو، و یک جدول اتصال که می‌گوید هر فایل
-- به چه چیزی تعلق دارد و در چه نقشی. همین دو جدول همه‌ی حالت‌ها
-- را پوشش می‌دهد:
--
--   عکس پروفایل پزشک   → media_tag(doctor, 5, profile)
--   عکس گالری با سه پزشک تگ‌شده → سه ردیف با role = gallery
--   گالری یک بخش        → media_tag(clinic, 2, gallery)
--   گالری عمومی کلینیک  → media_tag(site, 0, gallery)
--
-- یک موجودیت می‌تواند چند عکس پروفایل داشته باشد؛ در فهرست‌ها
-- نوبتی نمایش داده می‌شوند.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS media (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  filename   VARCHAR(255) NOT NULL,
  alt        VARCHAR(255)     NULL,
  mime       VARCHAR(80)      NULL,
  width      SMALLINT UNSIGNED NULL,
  height     SMALLINT UNSIGNED NULL,
  bytes      INT UNSIGNED     NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_filename (filename)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ستون‌های تازه‌ی media برای دیتابیسی که از قبل ساخته شده.
-- CREATE TABLE IF NOT EXISTS روی جدول موجود کاری نمی‌کند و MySQL
-- برای ADD COLUMN گزینه‌ی IF NOT EXISTS ندارد، پس نگهبانی لازم است.
SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'media' AND COLUMN_NAME = 'kind');
SET @sql := IF(@c = 0, "ALTER TABLE media
  ADD COLUMN kind        ENUM('image','video') NOT NULL DEFAULT 'image' AFTER id,
  ADD COLUMN title       VARCHAR(200)      NULL AFTER alt,
  ADD COLUMN description TEXT              NULL AFTER title,
  ADD COLUMN embed_url   VARCHAR(500)      NULL COMMENT 'آپارات یا یوتیوب؛ جایگزین فایل برای ویدیو' AFTER description,
  ADD COLUMN poster      VARCHAR(255)      NULL COMMENT 'تصویر پوستر ویدیو' AFTER embed_url,
  ADD COLUMN taken_on    DATE              NULL COMMENT 'تاریخ ثبت عکس، اگر با تاریخ بارگذاری فرق دارد' AFTER bytes,
  ADD COLUMN sort        SMALLINT      NOT NULL DEFAULT 0 AFTER taken_on,
  ADD COLUMN is_active   TINYINT(1)    NOT NULL DEFAULT 1 AFTER sort,
  ADD COLUMN uploaded_by INT UNSIGNED      NULL AFTER is_active",
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- filename برای ویدیوی خارجی خالی است، پس NOT NULL باید برداشته شود
SET @n := (SELECT IS_NULLABLE FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'media' AND COLUMN_NAME = 'filename');
SET @sql := IF(@n = 'NO',
  'ALTER TABLE media MODIFY COLUMN filename VARCHAR(255) NULL',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @k := (SELECT COUNT(*) FROM information_schema.STATISTICS
           WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'media' AND INDEX_NAME = 'idx_media_kind');
SET @sql := IF(@k = 0,
  'ALTER TABLE media ADD KEY idx_media_kind (kind, is_active, created_at)',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ------------------------------------------------------------
-- اتصال رسانه به موجودیت
--
-- entity_id روی کلید اصلی است و در MySQL ستون کلید اصلی NULL
-- نمی‌پذیرد، پس برای گالری عمومی کلینیک مقدار ۰ می‌گیرد.
-- entity_type چندریختی است و کلید خارجی نمی‌پذیرد؛ پاک‌سازی
-- ردیف‌های یتیم در Media::forget() انجام می‌شود.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS media_tag (
  media_id    INT UNSIGNED NOT NULL,
  entity_type ENUM('doctor','clinic','page','site') NOT NULL,
  entity_id   INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '۰ یعنی کل کلینیک، وقتی entity_type = site',
  role        ENUM('profile','gallery') NOT NULL DEFAULT 'gallery',
  sort        SMALLINT     NOT NULL DEFAULT 0,
  PRIMARY KEY (media_id, entity_type, entity_id, role),
  KEY idx_mt_lookup (entity_type, entity_id, role, sort),
  CONSTRAINT fk_mt_media FOREIGN KEY (media_id) REFERENCES media(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- درخواست نوبت
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS appointments (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(160) NOT NULL,
  phone       VARCHAR(20)  NOT NULL,
  clinic_id   INT UNSIGNED     NULL,
  doctor_id   INT UNSIGNED     NULL,
  preferred   VARCHAR(120)     NULL  COMMENT 'زمان دلخواه، متن آزاد',
  note        TEXT             NULL,
  status      ENUM('new','called','booked','cancelled') NOT NULL DEFAULT 'new',
  ip          VARBINARY(16)    NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_appt_status (status, created_at),
  CONSTRAINT fk_appt_clinic FOREIGN KEY (clinic_id) REFERENCES clinics(id) ON DELETE SET NULL,
  CONSTRAINT fk_appt_doctor FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- پنل مدیریت
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_users (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  username       VARCHAR(60)  NOT NULL,
  password_hash  VARCHAR(255)     NULL  COMMENT 'دیگر استفاده نمی‌شود؛ ورود فقط با کد پیامکی',
  phone          VARCHAR(15)      NULL  COMMENT 'شکل یکسان‌شده: 09xxxxxxxxx — همین شناسه‌ی ورود است',
  name           VARCHAR(120) NOT NULL,
  role           ENUM('owner','editor') NOT NULL DEFAULT 'editor',
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  last_login_at  DATETIME         NULL,
  failed_tries   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until   DATETIME         NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_admin_username (username),
  UNIQUE KEY uq_admin_phone (phone)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ستون phone و NULL شدن password_hash برای دیتابیسی که از قبل
-- ساخته شده — CREATE TABLE IF NOT EXISTS روی جدول موجود کاری
-- نمی‌کند و MySQL برای ADD COLUMN گزینه‌ی IF NOT EXISTS ندارد.
SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'admin_users' AND COLUMN_NAME = 'phone');
SET @sql := IF(@c = 0,
  'ALTER TABLE admin_users ADD COLUMN phone VARCHAR(15) NULL AFTER password_hash,
     ADD UNIQUE KEY uq_admin_phone (phone)',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ورود دیگر رمزی نیست، پس این ستون نباید اجباری بماند
SET @n := (SELECT IS_NULLABLE FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'admin_users' AND COLUMN_NAME = 'password_hash');
SET @sql := IF(@n = 'NO',
  'ALTER TABLE admin_users MODIFY COLUMN password_hash VARCHAR(255) NULL',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

-- ------------------------------------------------------------
-- کد یک‌بارمصرف ورود
--
-- خودِ کد ذخیره نمی‌شود، فقط هشش. اگر روزی کسی به دیتابیس دست
-- پیدا کند، نباید بتواند کد در جریان را بخواند و وارد شود.
--
-- عمر کد کوتاه است و شمار تلاش هم محدود، چون فضای جست‌وجوی یک
-- کد شش‌رقمی فقط یک میلیون حالت است — بدون سقف تلاش، حدس‌زدنش
-- کار چند دقیقه است.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS admin_otp (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id    INT UNSIGNED NOT NULL,
  code_hash   VARCHAR(255) NOT NULL  COMMENT 'هش کد، نه خود کد',
  expires_at  DATETIME     NOT NULL,
  tries       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  used_at     DATETIME         NULL,
  ip          VARBINARY(16)    NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_otp_admin (admin_id, created_at),
  KEY idx_otp_expiry (expires_at),
  CONSTRAINT fk_otp_admin FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS audit_log (
  id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  admin_id   INT UNSIGNED     NULL,
  action     VARCHAR(40)  NOT NULL  COMMENT 'create / update / delete / login',
  entity     VARCHAR(40)      NULL,
  entity_id  INT UNSIGNED     NULL,
  detail     TEXT             NULL,
  ip         VARBINARY(16)    NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_audit_created (created_at),
  CONSTRAINT fk_audit_admin FOREIGN KEY (admin_id) REFERENCES admin_users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- تنظیمات عمومی
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS settings (
  k          VARCHAR(64)  NOT NULL,
  v          TEXT             NULL,
  updated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (k)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
