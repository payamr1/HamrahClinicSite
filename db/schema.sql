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

  type          ENUM('home','page','service','doctor','post','archive') NOT NULL,
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
  license_no    VARCHAR(30)      NULL  COMMENT 'شماره نظام پزشکی',
  bio           TEXT             NULL,
  photo         VARCHAR(255)     NULL,
  schedule      VARCHAR(255)     NULL  COMMENT 'مثل: شنبه، دوشنبه، چهارشنبه ۹ تا ۱۴',
  is_founder    TINYINT(1)   NOT NULL DEFAULT 0,
  sort          SMALLINT     NOT NULL DEFAULT 0,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY idx_doctor_sort (sort),
  KEY idx_doctor_page (page_id),
  CONSTRAINT fk_doctor_page FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
  password_hash  VARCHAR(255) NOT NULL  COMMENT 'خروجی password_hash با الگوریتم پیش‌فرض',
  name           VARCHAR(120) NOT NULL,
  role           ENUM('owner','editor') NOT NULL DEFAULT 'editor',
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  last_login_at  DATETIME         NULL,
  failed_tries   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until   DATETIME         NULL,
  created_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_admin_username (username)
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
