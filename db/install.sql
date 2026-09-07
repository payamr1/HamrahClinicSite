SET NAMES utf8mb4;
SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';

-- ============================================================
--  همراه کلینیک — نصب کامل دیتابیس در یک فایل
--
--  ترکیب پنج فایل به ترتیب درست:
--    db/schema.sql                  ۱۳ جدول
--    db/seed/01-pages.sql           ۸۲ آدرس با متای سئو
--    db/seed/02-clinics-doctors.sql ۱۰ کلینیک و ۱۲ پزشک
--    db/seed/03-content.sql         متن صفحات
--    db/seed/04-faqs.sql            سؤالات متداول — منبع FAQPage
--
--  در phpMyAdmin فقط همین یک فایل را Import کنید.
--  اجرای مکرر بی‌خطر است.
--  بازتولید: sh db/build-install.sh
-- ============================================================


-- ##### db/schema.sql #####

-- ============================================================
--  همراه کلینیک — ساختار دیتابیس
--  MySQL 5.7+ / MariaDB 10.2+   ·   utf8mb4   ·   InnoDB
--
--  اصل طراحی: جدول pages تنها مرجع آدرس‌هاست.
--  هر ۸۲ آدرس فعلی سایت یک ردیف در همین جدول دارند و ستون path
--  دقیقاً همان مسیری است که امروز در گوگل ایندکس شده است.
--  هیچ آدرسی نباید بدون ثبت ریدایرکت در جدول redirects تغییر کند.
-- ============================================================


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

-- ##### db/seed/01-pages.sql #####

-- ============================================================
--  همراه کلینیک — داده اولیه صفحات (۸۲ آدرس)
--  تولید خودکار: perl db/seed/gen-pages.pl
--
--  ستون path دقیقاً همان مسیری است که امروز در گوگل ایندکس شده.
--  تغییر هر مقدار path بدون ثبت ریدایرکت = از دست رفتن رتبه.
-- ============================================================

INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/', '/', 'home', 'home', 'همراه کلینیک', 'همراه کلینیک | فوق تخصصی قلب، آنکولوژی و شیمی‌درمانی تجریش', 'کلینیک فوق تخصصی همراه در تجریش تهران؛ قلب و عروق، آنکولوژی، شیمی‌درمانی، غدد، زخم و عفونی با تیم درمان چندتخصصی. رزرو نوبت: ۰۲۱۹۱۳۰۳۱۳۲')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/about-us/', '/about-us/', 'page', 'about-us', 'درباره ما', 'درباره همراه کلینیک | کلینیک فوق تخصصی تجریش تهران', 'داستان همراه کلینیک؛ مرکزی با رویکرد تیم درمان چندتخصصی در تجریش تهران که قلب، آنکولوژی، تغذیه و روان را در یک پرونده‌ی مشترک کنار هم قرار می‌دهد.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/contact-us/', '/contact-us/', 'page', 'contact-us', 'تماس با ما', 'تماس با همراه کلینیک | آدرس، تلفن و ساعات کاری', 'آدرس همراه کلینیک: تهران، خیابان شریعتی، نرسیده به میدان قدس، کوچه مهنا ۱، پلاک ۶. تلفن ۰۲۱۹۱۳۰۳۱۳۲. شنبه تا چهارشنبه ۸ تا ۲۰، پنجشنبه ۸ تا ۱۳.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/blog/', '/blog/', 'archive', 'blog', 'بلاگ سلامت همراه', 'بلاگ سلامت همراه کلینیک | مقالات پزشکی تخصصی', 'مقالات علمی و کاربردی درباره‌ی بیماری‌های قلبی، شیمی‌درمانی، تغذیه و سلامت روان، نوشته‌ی پزشکان متخصص همراه کلینیک به زبان ساده و قابل فهم.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/', '/team/', 'archive', 'team', 'پزشکان همراه کلینیک', 'پزشکان همراه کلینیک | ۱۲ متخصص با بورد تخصصی', 'معرفی پزشکان همراه کلینیک؛ متخصصان قلب و عروق، آنکولوژی، خون، تغذیه، روان‌پزشکی و طب ایرانی با بورد تخصصی و شماره‌ی نظام پزشکی قابل استعلام.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/', '/service/', 'archive', 'service', 'خدمات و کلینیک‌های تخصصی', 'خدمات همراه کلینیک | ۴۶ خدمت در ۹ کلینیک تخصصی', 'فهرست کامل خدمات همراه کلینیک تجریش؛ قلب و عروق، آنکولوژی، شیمی‌درمانی، کلینیک زخم، کلینیک غدد، کلینیک عفونی، تغذیه، روان و طب ایرانی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/گالری/', '/گالری/', 'page', 'گالری', 'گالری تصاویر', 'گالری تصاویر همراه کلینیک | محیط و تجهیزات', 'تصاویر محیط، بخش‌های درمانی و تجهیزات همراه کلینیک در تجریش تهران؛ نگاهی به فضایی که درمان شما در آن انجام می‌شود، از پذیرش تا اتاق شیمی‌درمانی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/سوالات-متداول/', '/سوالات-متداول/', 'page', 'سوالات-متداول', 'سوالات متداول', 'سوالات متداول همراه کلینیک | نوبت، هزینه و مراجعه', 'پاسخ پرتکرارترین پرسش‌های بیماران همراه کلینیک درباره‌ی نوبت‌دهی، ساعات کاری، پارکینگ، بیمه و نحوه‌ی مراجعه به بخش‌های تخصصی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-محبوبه-خلیلی/', '/team/دکتر-محبوبه-خلیلی/', 'doctor', 'دکتر-محبوبه-خلیلی', 'دکتر محبوبه خلیلی', 'دکتر محبوبه خلیلی | متخصص قلب و عروق و کاردیو آنکولوژی', 'دکتر محبوبه خلیلی، متخصص قلب و عروق با بورد تخصصی و فلوشیپ کاردیو آنکولوژی از انستیتو شهید رجایی، مؤسس همراه کلینیک تجریش. نظام پزشکی ۹۴۳۶۰.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-احمد-مافی/', '/team/دکتر-احمد-مافی/', 'doctor', 'دکتر-احمد-مافی', 'دکتر احمد مافی', 'دکتر احمد مافی | متخصص رادیوتراپی انکولوژی تهران', 'دکتر احمد مافی، متخصص رادیوتراپی انکولوژی با بورد تخصصی و دانشیار دانشگاه علوم پزشکی شهید بهشتی، در بخش آنکولوژی همراه کلینیک تجریش. نظام پزشکی ۷۹۰۱۸.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-حسین-اصغری-پور/', '/team/دکتر-حسین-اصغری-پور/', 'doctor', 'دکتر-حسین-اصغری-پور', 'دکتر حسین اصغری پور', 'دکتر حسین اصغری‌پور | فوق تخصص خون و انکولوژی', 'دکتر حسین اصغری‌پور، متخصص بیماری‌های داخلی و فوق تخصص خون و انکولوژی، عضو انجمن سرطان اروپا و آمریکا، در همراه کلینیک تجریش. نظام پزشکی ۱۰۳۸۲۴.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دكتر-فاطمه-نائيني/', '/team/دکتر-فاطمه-نائینی/', 'doctor', 'دكتر-فاطمه-نائيني', 'دكتر فاطمه نائيني', 'دکتر فاطمه نائینی | متخصص تغذیه بالینی و رژیم‌درمانی', 'دکتر فاطمه نائینی، متخصص تغذیه بالینی از دانشگاه علوم پزشکی تهران، عضو بنیاد ملی نخبگان با شاخص علمی ۲۲ و بیش از ۵۰ مقاله بین‌المللی. همراه کلینیک تجریش.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-بهناز-بهزادی/', '/team/دکتر-بهناز-بهزادی/', 'doctor', 'دکتر-بهناز-بهزادی', 'دکتر بهناز بهزادی', 'دکتر بهناز بهزادی | متخصص رادیوانکولوژی', 'دکتر بهناز بهزادی، متخصص رادیوانکولوژی با بورد تخصصی رادیوتراپی از دانشگاه شهید بهشتی و عضو انجمن رادیوتراپی و انکولوژی ایران. همراه کلینیک تجریش.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-علیرضا-تاتینا/', '/team/دکتر-علیرضا-تاتینا/', 'doctor', 'دکتر-علیرضا-تاتینا', 'دکتر علیرضا تاتینا', 'دکتر علیرضا تاتینا | متخصص قلب و کاردیو آنکولوژی', 'دکتر علیرضا تاتینا، متخصص قلب و عروق با بورد تخصصی و فلوشیپ کاردیو آنکولوژی از انستیتو قلب شهید رجایی، در همراه کلینیک تجریش. نظام پزشکی ۹۷۹۹۵.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-مهناز-عالم-زاده-بحرینی/', '/team/دکتر-مهناز-عالم-زاده-بحرینی/', 'doctor', 'دکتر-مهناز-عالم-زاده-بحرینی', 'دکتر مهناز عالم زاده بحرینی', 'دکتر مهناز عالم‌زاده | متخصص قلب و اکوکاردیوگرافی', 'دکتر مهناز عالم‌زاده بحرینی، متخصص قلب و عروق با بورد تخصصی و فلوشیپ اکوکاردیوگرافی از انستیتو شهید رجایی، در همراه کلینیک تجریش. نظام پزشکی ۱۰۳۹۵۷.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-شادی-شکرخوار/', '/team/دکتر-شادی-شکرخوار/', 'doctor', 'دکتر-شادی-شکرخوار', 'دکتر شادی شکرخوار', 'دکتر شادی شکرخوار | متخصص قلب و اکوکاردیوگرافی', 'دکتر شادی شکرخوار، متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی با فلوشیپ اکوکاردیوگرافی، در بخش قلب همراه کلینیک تجریش. نظام پزشکی ۱۰۵۴۴۹.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-حسام-دانش-آموز/', '/team/دکتر-حسام-دانش-آموز/', 'doctor', 'دکتر-حسام-دانش-آموز', 'دکتر حسام دانش آموز', 'دکتر حسام دانش‌آموز | فوق تخصص قلب کودکان', 'دکتر حسام دانش‌آموز، متخصص کودکان و فوق تخصص قلب کودکان، در کلینیک قلب کودکان همراه در تجریش تهران. تشخیص و پیگیری بیماری‌های مادرزادی قلب.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-مریم-بدیع-زادگان/', '/team/دکتر-مریم-بدیع-زادگان/', 'doctor', 'دکتر-مریم-بدیع-زادگان', 'دکتر مریم بدیع زادگان', 'دکتر مریم بدیع‌زادگان | متخصص اعصاب و روان', 'دکتر مریم بدیع‌زادگان، متخصص اعصاب و روان (روان‌پزشک) با بورد تخصصی از دانشگاه شهید بهشتی، در بخش روان‌پزشکی همراه کلینیک تجریش. نظام پزشکی ۹۰۶۶۷.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-غزاله-حیدریراد/', '/team/دکتر-غزاله-حیدریراد/', 'doctor', 'دکتر-غزاله-حیدریراد', 'دکتر غزاله حیدری‌راد', 'دکتر غزاله حیدری‌راد | پزشک طب ایرانی و سبک زندگی', 'دکتر غزاله حیدری‌راد، پزشک MD.PhD طب ایرانی و عضو هیأت علمی دانشگاه علوم پزشکی شهید بهشتی، در بخش طب ایرانی همراه کلینیک تجریش. نظام پزشکی ۱۰۵۹۹۵.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/team/دکتر-رضا-مقبولی/', '/team/دکتر-رضا-مقبولی/', 'doctor', 'دکتر-رضا-مقبولی', 'دکتر رضا مقبولی', 'دکتر رضا مقبولی | متخصص اورولوژی و جراحی کلیه', 'دکتر رضا مقبولی، متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی) در کلینیک اورولوژی همراه، تجریش تهران. نظام پزشکی ۱۸۹۲۵۱. رزرو نوبت آنلاین.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/', '/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/', 'post', 'از-کجا-بفهمیم-شیمی-درمانی-جواب-داده', 'از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص', 'از کجا بفهمیم شیمی‌درمانی جواب داده؟ علائم و روش‌های تشخیص', 'علائم پاسخ بدن به شیمی‌درمانی چیست؟ نقش آزمایش خون، سی‌تی‌اسکن، ام‌آر‌آی و تومورمارکرها در سنجش اثربخشی درمان، به زبان ساده از پزشکان همراه کلینیک.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/ایا-گرفتگی-عروق-پا-خطرناک-است/', '/ایا-گرفتگی-عروق-پا-خطرناک-است/', 'post', 'ایا-گرفتگی-عروق-پا-خطرناک-است', 'ایا گرفتگی عروق پا خطرناک است؟', 'آیا گرفتگی عروق پا خطرناک است؟ علائم و درمان', 'گرفتگی عروق پا (بیماری شریان محیطی) در صورت درمان‌نشدن به زخم مزمن و گنگرن می‌رسد. علائم هشدار، افراد در معرض خطر و روش‌های تشخیص و درمان تخصصی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/بهترین-صبحانه-قبل-از-شیمی-درمانی/', '/بهترین-صبحانه-قبل-از-شیمی-درمانی/', 'post', 'بهترین-صبحانه-قبل-از-شیمی-درمانی', 'بهترین صبحانه قبل از شیمی درمانی', 'بهترین صبحانه قبل از شیمی درمانی | چه بخوریم؟', 'صبحانه‌ی روز شیمی‌درمانی باید سبک، زودهضم و مغذی باشد. فهرست خوراکی‌های مناسب و مواردی که باید پرهیز کنید، از متخصص تغذیه‌ی بالینی همراه کلینیک.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/تشخیص-آریتمی-قلبی-در-خانه/', '/تشخیص-آریتمی-قلبی-در-خانه/', 'post', 'تشخیص-آریتمی-قلبی-در-خانه', 'تشخیص آریتمی قلبی در خانه', 'تشخیص آریتمی قلبی در خانه | روش‌ها و محدودیت‌ها', 'آیا می‌توان آریتمی قلبی را در خانه تشخیص داد؟ روش کنترل نبض، دقت ساعت هوشمند و محدودیت‌های آن، و اینکه چه زمانی حتماً باید نوار قلب گرفته شود.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/', '/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/', 'post', 'تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان', 'تقویت سیستم ایمنی بدن بعد از شیمی درمانی', 'تقویت سیستم ایمنی بدن بعد از شیمی درمانی', 'چگونه پس از شیمی‌درمانی سیستم ایمنی را بازسازی کنیم؟ تغذیه، خواب، واکسیناسیون و نکات پیشگیری از عفونت، از متخصصان همراه کلینیک در تجریش تهران.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/حمایت-روانی-از-بیماران-در-زمان-شیمید/', '/حمایت-روانی-از-بیماران-در-زمان-شیمید/', 'post', 'حمایت-روانی-از-بیماران-در-زمان-شیمید', 'حمایت روانی از بیماران در زمان شیمی‌درمانی', 'حمایت روانی از بیمار در دوران شیمی‌درمانی', 'بیمار تحت شیمی‌درمانی به همان اندازه‌ی دارو به حمایت روانی نیاز دارد. راهکارهای عملی برای بیمار و خانواده، از روان‌پزشک همراه کلینیک تجریش.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/راهنمای-جامع-تغذیه-در-شیمی-درمانی/', '/راهنمای-جامع-تغذیه-در-شیمی-درمانی/', 'post', 'راهنمای-جامع-تغذیه-در-شیمی-درمانی', 'راهنمای جامع تغذیه در دوران شیمی‌درمانی: توصیه‌ها و پرهیزات ضروری', 'تغذیه در دوران شیمی‌درمانی | توصیه‌ها و پرهیزها', 'چه بخوریم و از چه پرهیز کنیم در دوران شیمی‌درمانی؟ راهنمای کامل تغذیه برای کنترل تهوع، حفظ وزن و تقویت بدن، از متخصص تغذیه‌ی بالینی همراه کلینیک.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/روغن-سیاه-دانه-برای-واریس-پا/', '/روغن-سیاه-دانه-برای-واریس-پا/', 'post', 'روغن-سیاه-دانه-برای-واریس-پا', 'روغن سیاه دانه برای واریس پا [فواید و روش مصرف]', 'روغن سیاه‌دانه برای واریس پا | فواید و روش مصرف', 'آیا روغن سیاه‌دانه واریس پا را درمان می‌کند؟ بررسی شواهد علمی، روش صحیح مصرف، نکات ایمنی و اینکه چه زمانی باید به متخصص قلب و عروق مراجعه کنید.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/شب-قبل-از-شیمی-درمانی-چه-بخوریم/', '/شب-قبل-از-شیمی-درمانی-چه-بخوریم/', 'post', 'شب-قبل-از-شیمی-درمانی-چه-بخوریم', 'شب قبل از شیمی درمانی چه بخوریم', 'شب قبل از شیمی درمانی چه بخوریم؟', 'وعده‌ی شب پیش از شیمی‌درمانی روی حال شما در روز درمان اثر دارد. فهرست خوراکی‌های مناسب، مواردی که باید پرهیز کنید و نکات آب‌رسانی بدن.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/فشار-دیاستولیک-پایین-نشانه-چیست/', '/فشار-دیاستولیک-پایین-نشانه-چیست/', 'post', 'فشار-دیاستولیک-پایین-نشانه-چیست', 'فشار دیاستولیک پایین نشانه چیست؟', 'فشار دیاستولیک پایین نشانه چیست؟ علل و درمان', 'فشار دیاستولیک پایین می‌تواند نشانه‌ی کم‌آبی، مشکل دریچه‌ی قلب، سوءتغذیه یا عارضه‌ی دارویی باشد. علائم هشدار و زمان مراجعه به متخصص قلب و عروق.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/', '/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/', 'post', 'قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود', 'قرص نیتروگلیسیرین چه زمانی مصرف شود؟', 'قرص نیتروگلیسیرین چه زمانی مصرف شود؟', 'نیتروگلیسیرین را بلافاصله پس از شروع درد قفسه‌ی سینه یا ۵ دقیقه پیش از فعالیت سنگین مصرف کنید. روش صحیح، دوز مجاز و هشدارهای مهم دارویی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/نقش-آنتیاکسیدانها-در-پیشگیری-از-سر/', '/نقش-آنتیاکسیدانها-در-پیشگیری-از-سر/', 'post', 'نقش-آنتیاکسیدانها-در-پیشگیری-از-سر', 'نقش آنتی‌اکسیدان‌ها در پیشگیری از سرطان', 'نقش آنتی‌اکسیدان‌ها در پیشگیری از سرطان', 'آنتی‌اکسیدان‌ها چگونه از سلول‌ها محافظت می‌کنند؟ منابع غذایی، شواهد علمی درباره‌ی پیشگیری از سرطان و هشدار مهم درباره‌ی مکمل‌ها در دوره‌ی درمان.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/هر-دوره-شیمی-درمانی-چند-جلسه-است/', '/هر-دوره-شیمی-درمانی-چند-جلسه-است/', 'post', 'هر-دوره-شیمی-درمانی-چند-جلسه-است', 'تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟', 'تعداد جلسات شیمی‌درمانی و فاصله بین آن‌ها', 'هر دوره‌ی شیمی‌درمانی چند جلسه است و فاصله‌ی بین جلسات چقدر؟ عوامل تعیین‌کننده‌ی تعداد جلسات و آنچه در فاصله‌ی بین دو جلسه باید بدانید.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/چرا-مغز-ما-در-مواجهه-با-استرس-بیشفعال/', '/چرا-مغز-ما-در-مواجهه-با-استرس-بیشفعال/', 'post', 'چرا-مغز-ما-در-مواجهه-با-استرس-بیشفعال', 'چرا مغز ما در مواجهه با استرس بیش‌فعال می‌شود؟', 'چرا مغز ما در مواجهه با استرس بیش‌فعال می‌شود؟', 'واکنش مغز به استرس چگونه کار می‌کند و چرا گاهی از کنترل خارج می‌شود؟ نقش آمیگدال و کورتیزول و راهکارهای عملی آرام‌سازی، از روان‌پزشک همراه کلینیک.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/10-نشانه-پنهان-بیماری-قلبی-که-نباید-ناد/', '/10-نشانه-پنهان-بیماری-قلبی-که-نباید-ناد/', 'post', '10-نشانه-پنهان-بیماری-قلبی-که-نباید-ناد', '10 نشانه پنهان بیماری قلبی که نباید نادیده بگیرید', '۱۰ نشانه پنهان بیماری قلبی که نباید نادیده بگیرید', 'بسیاری از بیماری‌های قلبی پیش از سکته نشانه‌های خاموشی دارند؛ از خستگی غیرعادی تا تورم پا. ده علامتی که باید جدی بگیرید، از متخصص قلب همراه کلینیک.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/7-اشتباه-رایج-تغذیهای-که-مانع-کاهش-وز/', '/7-اشتباه-رایج-تغذیهای-که-مانع-کاهش-وز/', 'post', '7-اشتباه-رایج-تغذیهای-که-مانع-کاهش-وز', '7 اشتباه رایج تغذیه‌ای که مانع کاهش وزن می‌شود', '۷ اشتباه رایج تغذیه‌ای که مانع کاهش وزن می‌شود', 'چرا با وجود رژیم، وزن کم نمی‌کنید؟ هفت اشتباه رایج از حذف وعده تا مصرف پنهان قند، و راه اصلاح هرکدام، از متخصص تغذیه‌ی بالینی همراه کلینیک.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/قلب-و-عروق/', '/service/قلب-و-عروق/', 'service', 'قلب-و-عروق', 'متخصص قلب و عروق در تجریش تهران', 'متخصص قلب و عروق در تجریش تهران | همراه کلینیک', 'بخش قلب و عروق همراه کلینیک با ۵ متخصص دارای بورد و فلوشیپ کاردیو آنکولوژی؛ اکوکاردیوگرافی، نوار قلب، هولتر و پایش قلب در دوره‌ی شیمی‌درمانی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/آنکولوژی/', '/service/آنکولوژی/', 'service', 'آنکولوژی', 'خدمات مشاوره و درمان آنکولوژی در همراه کلینیک', 'کلینیک آنکولوژی تهران | تشخیص و درمان سرطان', 'بخش آنکولوژی همراه کلینیک در تجریش تهران؛ ارزیابی، تشخیص و درمان سرطان با تیم چندتخصصی (MDT) و همراهی متخصص قلب در تمام طول دوره‌ی درمان.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/شیمی-درمانی/', '/service/شیمی-درمانی/', 'service', 'شیمی-درمانی', '🏥 بخش شیمی‌درمانی همراه کلینیک', 'بخش شیمی درمانی همراه کلینیک در تجریش تهران', 'شیمی‌درمانی سرپایی در محیطی آرام با پرستار اختصاصی، پایش عملکرد قلب پیش و حین درمان، و مشاوره‌ی تغذیه و روان در همان مرکز. تلفن ۰۲۱۹۱۳۰۳۱۳۲.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/هماتولوژی/', '/service/هماتولوژی/', 'service', 'هماتولوژی', 'خدمات پزشک هماتولوژی &#8211; از تشخیص تا درمان اختلالات خونی', 'کلینیک هماتولوژی تهران | درمان بیماری‌های خون', 'تشخیص و درمان کم‌خونی، اختلالات انعقادی و بدخیمی‌های خون در بخش هماتولوژی همراه کلینیک تجریش، زیر نظر فوق تخصص خون و انکولوژی با بورد تخصصی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/روان-پزشکی/', '/service/روان-پزشکی/', 'service', 'روان-پزشکی', '🧠 بخش روان‌پزشکی همراه کلینیک', 'روان‌پزشک در تجریش تهران | همراه کلینیک', 'بخش روان‌پزشکی همراه کلینیک؛ تشخیص و درمان اضطراب، افسردگی و اختلالات خواب، با تمرکز ویژه بر حمایت روانی بیماران تحت درمان سرطان و خانواده‌هایشان.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/روان-شناسی/', '/service/روان-شناسی/', 'service', 'روان-شناسی', '🧩 بخش روان‌شناسی بالینی', 'مشاوره روان‌شناسی در تجریش تهران | همراه کلینیک', 'خدمات روان‌شناسی همراه کلینیک؛ مدیریت استرس، بهبود روابط فردی و همراهی روانی در دوره‌ی درمان، با راهکارهای علمی و عملی از متخصصان مجرب.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/تغذیه/', '/service/تغذیه/', 'service', 'تغذیه', 'بخش تخصصی تغذیه و رژیم‌درمانی بالینی همراه کلینیک', 'متخصص تغذیه و رژیم‌درمانی در تجریش تهران', 'بخش تغذیه همراه کلینیک؛ رژیم‌درمانی تخصصی، کنترل وزن و برنامه‌ی غذایی دوره‌ی شیمی‌درمانی، زیر نظر متخصص تغذیه‌ی بالینی دانشگاه علوم پزشکی تهران.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/طب-ایرانی/', '/service/طب-ایرانی/', 'service', 'طب-ایرانی', 'بخش طب ایرانی همراه کلینیک | طب سنتی مبتنی بر شواهد برای بیماران سرطانی', 'طب ایرانی و اصلاح سبک زندگی | همراه کلینیک تهران', 'بخش طب ایرانی همراه کلینیک با هدف کاهش عوارض شیمی‌درمانی و رادیوتراپی و اصلاح سبک زندگی، زیر نظر عضو هیأت علمی دانشگاه علوم پزشکی شهید بهشتی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/کلینیک-واریس/', '/service/کلینیک-واریس/', 'service', 'کلینیک-واریس', 'کلینیک واریس', 'کلینیک واریس تهران | درمان واریس پا در تجریش', 'تشخیص و درمان واریس و نارسایی وریدی اندام تحتانی در کلینیک واریس همراه، تجریش تهران. ارزیابی با سونوگرافی داپلر و درمان سرپایی زیر نظر متخصص قلب.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/کلینیک-قلب-کودکان/', '/service/کلینیک-قلب-کودکان/', 'service', 'کلینیک-قلب-کودکان', 'کلینیک قلب کودکان', 'فوق تخصص قلب کودکان در تهران | همراه کلینیک', 'کلینیک قلب کودکان همراه در تجریش تهران؛ تشخیص و پیگیری بیماری‌های مادرزادی قلب نوزادان و کودکان، با اکوکاردیوگرافی کودکان و فوق تخصص قلب اطفال.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/اکوکاردیوگرافی-قلب-جنین/', '/service/اکوکاردیوگرافی-قلب-جنین/', 'service', 'اکوکاردیوگرافی-قلب-جنین', 'اکوکاردیوگرافی قلب جنین', 'اکوکاردیوگرافی قلب جنین در تهران | همراه کلینیک', 'بررسی ساختار و عملکرد قلب جنین در دوران بارداری با اکوکاردیوگرافی؛ روشی دقیق و بی‌خطر برای تشخیص زودهنگام ناهنجاری‌های قلبی. تجریش تهران.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/لیست-خدمات-کلینیک-همراه/', '/service/لیست-خدمات-کلینیک-همراه/', 'service', 'لیست-خدمات-کلینیک-همراه', 'لیست خدمات کلینیک همراه', 'لیست کامل خدمات همراه کلینیک | ۴۶ خدمت درمانی', 'فهرست کامل خدمات درمانی همراه کلینیک تجریش در ۹ بخش تخصصی؛ از قلب و آنکولوژی تا کلینیک زخم، غدد، عفونی، تغذیه و روان. مشاهده‌ی جزئیات هر خدمت.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/adrenal/', '/service/adrenal/', 'service', 'adrenal', 'درمان اختلالات غده فوق کلیه (آدرنال)', 'درمان اختلالات غده فوق کلیه (آدرنال)', 'تشخیص و درمان اختلالات غده فوق کلیه شامل سندرم کوشینگ، آدیسون، هیپرآلدوسترونیسم و فئوکروموسیتوما در کلینیک غدد همراه تهران.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/arterial-ulcer/', '/service/arterial-ulcer/', 'service', 'arterial-ulcer', 'درمان زخم شریانی', 'درمان زخم شریانی | کلینیک زخم همراه تهران', 'زخم شریانی (Arterial Ulcer) ناشی از کاهش جریان خون شریانی به اندام‌های انتهایی است و معمولاً در انگشتان پا، پاشنه و نواحی فشاری ظاهر می‌شود. این زخم‌ها بسیار')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/brucellosis/', '/service/brucellosis/', 'service', 'brucellosis', 'درمان تب مالت (بروسلوز)', 'درمان تب مالت (بروسلوز) | کلینیک عفونی تهران', 'تب مالت (بروسلوز) یکی از شایع‌ترین عفونت‌های مشترک بین انسان و حیوان (زئونوز) در ایران است. مصرف لبنیات غیرپاستوریزه و کار با دام، اصلی‌ترین راه ابتلا است.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/burn-wound/', '/service/burn-wound/', 'service', 'burn-wound', 'درمان زخم سوختگی', 'درمان زخم سوختگی | کلینیک زخم همراه تهران', 'زخم سوختگی یکی از پیچیده‌ترین انواع زخم است که نیاز به مراقبت تخصصی برای کاهش عوارض، اسکار و عفونت دارد. کلینیک زخم همراه با پروتکل‌های مدرن، درمان سوختگی‌های')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/chronic-wound/', '/service/chronic-wound/', 'service', 'chronic-wound', 'درمان زخم مزمن غیرملتئم', 'درمان زخم مزمن غیرملتئم | کلینیک زخم همراه تهران', 'زخم مزمن (Chronic Wound) هر زخمی است که در عرض ۶ هفته با درمان‌های متداول بهبود نیافته باشد. این زخم‌ها معمولاً علامت یک بیماری زمینه‌ای هستند و نیازمند')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/diabetes/', '/service/diabetes/', 'service', 'diabetes', 'درمان دیابت', 'درمان دیابت', 'درمان تخصصی دیابت نوع ۱، نوع ۲، بارداری و پیش‌دیابت در کلینیک غدد همراه تهران با پایش HbA1c، مشاوره تغذیه و درمان‌های به‌روز.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/diabetic-foot/', '/service/diabetic-foot/', 'service', 'diabetic-foot', 'درمان زخم پای دیابتی', 'درمان زخم پای دیابتی | کلینیک زخم همراه تهران', 'زخم پای دیابتی شایع‌ترین عارضه‌ی مزمن دیابت است که در ۱۵ تا ۲۵ درصد بیماران دیابتی در طول عمرشان رخ می‌دهد. این زخم اگر به‌موقع و توسط تیم تخصصی درمان نشود،')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/endocrine-clinic/', '/service/endocrine-clinic/', 'service', 'endocrine-clinic', 'کلینیک غدد', 'کلینیک غدد و متابولیسم در تهران [نوبت دهی آنلاین✅]', 'تشخیص و درمان تخصصی دیابت، اختلالات تیروئید، چاقی، مشکلات هورمونی و متابولیک توسط پزشکان مجرب با امکان رزرو اینترنتی نوبت.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/fever-unknown-origin/', '/service/fever-unknown-origin/', 'service', 'fever-unknown-origin', 'بررسی تب با علت نامشخص (FUO)', 'بررسی تب با علت نامشخص (FUO) | کلینیک عفونی تهران', 'تب با علت نامشخص (FUO) به تب بیش از ۳۸.۳ که حداقل ۳ هفته طول کشیده و پس از بررسی‌های اولیه علت آن مشخص نشده، گفته می‌شود. کلینیک عفونی همراه با رویکرد')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/fungal-infection/', '/service/fungal-infection/', 'service', 'fungal-infection', 'درمان عفونت‌های قارچی', 'درمان عفونت‌های قارچی | کلینیک عفونی تهران', 'عفونت‌های قارچی از موارد سطحی پوست تا عفونت‌های مهاجم تهدیدکننده‌ی جان متفاوت‌اند. کلینیک عفونی همراه با هم‌کاری بخش انکولوژی و بیماری‌های مزمن، عفونت‌های')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/gi-infection/', '/service/gi-infection/', 'service', 'gi-infection', 'درمان عفونت‌های گوارشی', 'درمان عفونت‌های گوارشی | کلینیک عفونی تهران', 'عفونت‌های گوارشی از علل اصلی اسهال حاد و مزمن هستند. کلینیک عفونی همراه با تشخیص دقیق پاتوژن (باکتری، انگل، ویروس) و درمان هدفمند، از تجویز کور آنتی‌بیوتیک')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/growth-puberty/', '/service/growth-puberty/', 'service', 'growth-puberty', 'درمان اختلالات رشد و بلوغ کودکان در کلینیک غدد همراه تهران', 'درمان اختلالات رشد و بلوغ کودکان در کلینیک غدد همراه تهران', 'تشخیص و درمان اختلالات رشد و بلوغ کودکان شامل کوتاهی قد، کمبود هورمون رشد و بلوغ زودرس در کلینیک غدد همراه تهران، با بررسی سن استخوانی و پیگیری دوره‌ای.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/infected-wound/', '/service/infected-wound/', 'service', 'infected-wound', 'درمان زخم عفونی', 'درمان زخم عفونی | کلینیک زخم همراه تهران', 'زخم عفونی هر زخمی است که علائم آلودگی میکروبی نشان می‌دهد. عفونت می‌تواند هر زخمی را که در حال بهبود است متوقف کرده و در موارد شدید جان بیمار را تهدید کند.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/infectious-clinic/', '/service/infectious-clinic/', 'service', 'infectious-clinic', 'مرکز تخصصی بیماری‌های عفونی و گرمسیری', 'بهترین کلینیک تخصصی عفونی در تهران', 'کلینیک تخصصی عفونی در شهر تهران با پزشکان مجرب، تشخیص دقیق و درمان بیماری‌های عفونی، تب، هپاتیت و عفونت‌های ویروسی و باکتریایی با امکان رزرو نوبت بصورت آنلاین')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/malignant-wound/', '/service/malignant-wound/', 'service', 'malignant-wound', 'درمان زخم سرطانی و ناشی از درمان سرطان(مراقبت تخصصی)', 'درمان زخم سرطانی و ناشی از درمان سرطان', 'بخش درمان زخم سرطانی و ناشی از درمان سرطان همراه کلینیک، خدمات تخصصی ارزیابی، پانسمان و مراقبت از زخم را برای تسریع بهبود و کاهش عوارض ارائه می‌دهد.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/metabolic-syndrome/', '/service/metabolic-syndrome/', 'service', 'metabolic-syndrome', 'درمان چربی خون و سندرم متابولیک در کلینیک غدد همراه تهران', 'درمان چربی خون و سندرم متابولیک در کلینیک غدد همراه تهران', 'درمان چربی خون بالا و سندرم متابولیک با رویکرد کاهش ریسک قلبی-عروقی در کلینیک غدد همراه تجریش تهران؛ ارزیابی آزمایشگاهی، اصلاح تغذیه و دارودرمانی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/obesity/', '/service/obesity/', 'service', 'obesity', 'درمان چاقی و کنترل وزن در کلینیک غدد همراه تهران', 'درمان چاقی و کنترل وزن در کلینیک غدد همراه تهران', 'درمان چاقی و اضافه وزن با ارزیابی علل هورمونی، مشاوره تغذیه و دارودرمانی در کلینیک غدد همراه تجریش تهران؛ برنامه‌ی شخصی‌سازی‌شده و پیگیری منظم.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/osteoporosis/', '/service/osteoporosis/', 'service', 'osteoporosis', 'درمان پوکی استخوان در کلینیک غدد همراه تهران', 'درمان پوکی استخوان در کلینیک غدد همراه تهران', 'تشخیص و درمان پوکی استخوان با سنجش تراکم استخوان (DEXA) و درمان دارویی برای پیشگیری از شکستگی در کلینیک غدد همراه تهران.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/pcos/', '/service/pcos/', 'service', 'pcos', 'درمان سندرم تخمدان پلی‌کیستیک (PCOS) در کلینیک غدد همراه تهران', 'درمان سندرم تخمدان پلی‌کیستیک (PCOS) در کلینیک غدد تهران', 'درمان سندرم تخمدان پلی‌کیستیک (PCOS) با رویکرد هورمونی و متابولیک — تنظیم قاعدگی، پرمویی و ناباروری در کلینیک غدد همراه تهران.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/pituitary/', '/service/pituitary/', 'service', 'pituitary', 'درمان اختلالات غده هیپوفیز در کلینیک غدد همراه تهران', 'درمان اختلالات غده هیپوفیز در کلینیک غدد همراه تهران', 'تشخیص و درمان اختلالات غده هیپوفیز شامل پرولاکتینوما، آکرومگالی و کم‌کاری هیپوفیز در کلینیک غدد همراه تجریش تهران، با آزمایش‌های هورمونی تخصصی.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/pressure-ulcer/', '/service/pressure-ulcer/', 'service', 'pressure-ulcer', 'درمان زخم بستر (فشاری)', 'درمان زخم بستر (فشاری) | کلینیک زخم همراه تهران', 'زخم بستر یا زخم فشاری (Pressure Ulcer) آسیبی است که در پوست و بافت‌های زیرین آن به دلیل فشار طولانی‌مدت ایجاد می‌شود. این زخم‌ها معمولاً در بیماران سالمند،')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/respiratory-infection/', '/service/respiratory-infection/', 'service', 'respiratory-infection', 'درمان عفونت تنفسی', 'درمان عفونت تنفسی | کلینیک عفونی تهران', 'عفونت‌های تنفسی از علل اصلی مراجعه به پزشک هستند. کلینیک عفونی همراه با ارزیابی دقیق، تصویربرداری مناسب و تشخیص افتراقی بین عفونت‌های ویروسی و باکتریایی، از')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/sex-hormones/', '/service/sex-hormones/', 'service', 'sex-hormones', 'اختلالات هورمون‌های جنسی و یائسگی در کلینیک غدد همراه تهران', 'اختلالات هورمون‌های جنسی و یائسگی در کلینیک غدد همراه تهران', 'درمان اختلالات هورمون‌های جنسی، یائسگی و افت تستوسترون با هورمون‌درمانی اصولی در کلینیک غدد همراه تجریش تهران؛ ارزیابی کامل هورمونی و پیگیری دوره‌ای.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/skin-infection/', '/service/skin-infection/', 'service', 'skin-infection', 'درمان عفونت پوست و بافت نرم', 'درمان عفونت پوست و بافت نرم | کلینیک عفونی تهران', 'عفونت‌های پوست و بافت نرم (SSTI) از سلولیت ساده تا عفونت‌های تهدیدکننده‌ی جان مانند نکروتیزینگ فاسئیت متفاوت‌اند. کلینیک عفونی همراه با هم‌کاری کلینیک زخم،')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/sti/', '/service/sti/', 'service', 'sti', 'تشخیص و درمان عفونت‌های مقاربتی (STI)', 'تشخیص و درمان عفونت‌های مقاربتی (STI)', 'عفونت‌های مقاربتی (STI) قابل تشخیص و درمان هستند، اما به دلیل تابو فرهنگی، اغلب دیر تشخیص داده می‌شوند. کلینیک عفونی همراه با رعایت کامل محرمانگی و حریم')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/surgical-wound/', '/service/surgical-wound/', 'service', 'surgical-wound', 'درمان زخم بعد از جراحی', 'درمان زخم بعد از جراحی | کلینیک زخم همراه تهران', 'زخم‌های بعد از جراحی که دیر التیام می‌یابند یا دچار باز شدن (Wound Dehiscence) شده‌اند، نیازمند مراقبت تخصصی هستند. کلینیک زخم همراه با پروتکل‌های استاندارد و')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/thyroid/', '/service/thyroid/', 'service', 'thyroid', 'درمان بیماری‌های تیروئید در کلینیک غدد همراه تهران', 'درمان بیماری‌های تیروئید در کلینیک غدد همراه تهران', 'درمان کم‌کاری، پرکاری، گواتر و گره‌های تیروئید در کلینیک غدد همراه تجریش تهران، با سونوگرافی و نمونه‌برداری (FNA) در محل و پاسخ‌دهی سریع.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/traumatic-wound/', '/service/traumatic-wound/', 'service', 'traumatic-wound', 'درمان زخم ضربه‌ای (تروماتیک)', 'درمان زخم ضربه‌ای (تروماتیک) | کلینیک زخم همراه تهران', 'زخم‌های ضربه‌ای (Traumatic Wounds) ناشی از تصادف، سقوط، بریدگی شدید یا حادثه هستند که می‌توانند سطحی یا عمیق، تمیز یا آلوده باشند. کلینیک زخم همراه پیگیری پس')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/tuberculosis/', '/service/tuberculosis/', 'service', 'tuberculosis', 'تشخیص و درمان سل (TB)', 'تشخیص و درمان سل (TB) | کلینیک عفونی تهران', 'سل (Tuberculosis) یکی از کشنده‌ترین عفونت‌های جهان است که هنوز سالانه میلیون‌ها نفر را در سراسر دنیا مبتلا می‌کند. کلینیک عفونی همراه با دسترسی به Gene-Xpert')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/urinary-tract-infection/', '/service/urinary-tract-infection/', 'service', 'urinary-tract-infection', 'درمان عفونت ادراری (UTI)', 'درمان عفونت ادراری (UTI) | کلینیک عفونی تهران', 'عفونت ادراری (UTI) شایع‌ترین عفونت باکتریایی در جامعه است و حدود ۵۰٪ زنان حداقل یک‌بار در طول عمرشان به آن مبتلا می‌شوند. کلینیک عفونی همراه با تشخیص دقیق')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/urology-clinic/', '/service/urology-clinic/', 'service', 'urology-clinic', 'کلینیک اورولوژی', 'کلینیک فوق تخصصی اورولوژی در تهران', 'تشخیص و درمان تخصصی بیماری‌های کلیه، مجاری ادراری، پروستات، ناباروری مردان و مشکلات ادراری توسط پزشکان مجرب با امکان نوبت‌دهی آنلاین.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/venous-ulcer/', '/service/venous-ulcer/', 'service', 'venous-ulcer', 'درمان زخم وریدی', 'درمان زخم وریدی | کلینیک زخم همراه تهران', 'زخم وریدی شایع‌ترین نوع زخم مزمن پای انسان است و در ۸۰٪ موارد زخم‌های مزمن ساق پا را شامل می‌شود. این زخم‌ها معمولاً در نتیجه‌ی نارسایی مزمن وریدی (CVI) و')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/viral-hepatitis/', '/service/viral-hepatitis/', 'service', 'viral-hepatitis', 'درمان هپاتیت ویروسی (B و C)', 'درمان هپاتیت ویروسی (B و C) | کلینیک عفونی تهران', 'هپاتیت‌های ویروسی B و C از مهم‌ترین عفونت‌های مزمن کبد هستند که در صورت عدم درمان به سیروز، نارسایی کبد و سرطان کبد منجر می‌شوند. کلینیک عفونی همراه با دسترسی')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES
  ('/service/wound-clinic/', '/service/wound-clinic/', 'service', 'wound-clinic', 'مرکز تخصصی درمان زخم‌های مزمن و دیابتی', 'کلینیک زخم تهران | درمان زخم دیابتی، بستر و مزمن', 'درمان تخصصی زخم دیابتی، بستر، وریدی، شریانی و سوختگی در کلینیک زخم همراه، تجریش تهران. ارزیابی، پانسمان تخصصی و پیگیری دوره‌ای زیر نظر کادر مجرب.')
  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),
    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);

-- ##### db/seed/02-clinics-doctors.sql #####

-- ============================================================
--  همراه کلینیک — کلینیک‌ها، پزشکان و اتصال آن‌ها
--
--  پیش‌نیاز: 01-pages.sql اجرا شده باشد.
--  اتصال‌ها با path انجام می‌شود، نه با id، تا مستقل از ترتیب
--  درج و قابل اجرای مکرر باشد.
-- ============================================================

-- ------------------------------------------------------------
--  ۹ کلینیک تخصصی
-- ------------------------------------------------------------
INSERT INTO clinics (slug, name, tagline, summary, sort, page_id) VALUES
  ('cardiology', 'قلب و عروق',
   'با تمرکز ویژه بر کاردیو آنکولوژی',
   'اکوکاردیوگرافی، نوار قلب، هولتر و پایش عملکرد قلب در دوره‌ی شیمی‌درمانی.',
   10, (SELECT id FROM pages WHERE path = '/service/قلب-و-عروق/')),

  ('oncology', 'آنکولوژی و هماتولوژی',
   'تیم چندتخصصی درمان سرطان',
   'ارزیابی، تشخیص و درمان سرطان و بیماری‌های خون، با حضور متخصص قلب در تیم درمان.',
   20, (SELECT id FROM pages WHERE path = '/service/آنکولوژی/')),

  ('chemotherapy', 'شیمی‌درمانی',
   'سرپایی، با پرستار اختصاصی',
   'شیمی‌درمانی در محیطی آرام، با پایش قلب پیش و در طول دوره و مشاوره‌ی تغذیه در محل.',
   30, (SELECT id FROM pages WHERE path = '/service/شیمی-درمانی/')),

  ('wound', 'کلینیک زخم',
   'زخم‌های مزمن و دیرالتیام',
   'زخم دیابتی، بستر، وریدی، شریانی، سوختگی، جراحی و زخم‌های عفونی و سرطانی.',
   40, (SELECT id FROM pages WHERE path = '/service/wound-clinic/')),

  ('endocrine', 'کلینیک غدد و متابولیسم',
   'تیروئید، دیابت و هورمون‌ها',
   'تیروئید، دیابت، پوکی استخوان، تخمدان پلی‌کیستیک، چاقی، هیپوفیز و اختلالات رشد.',
   50, (SELECT id FROM pages WHERE path = '/service/endocrine-clinic/')),

  ('infectious', 'کلینیک عفونی',
   'تشخیص دقیق، درمان هدفمند',
   'هپاتیت، سل، بروسلوز، عفونت‌های پوستی، ادراری، تنفسی و تب با منشأ نامشخص.',
   60, (SELECT id FROM pages WHERE path = '/service/infectious-clinic/')),

  ('mental-health', 'روان‌پزشکی و روان‌شناسی',
   'همراهی روانی بیمار و خانواده',
   'مدیریت اضطراب، افسردگی و استرس، با تمرکز بر بیماران تحت درمان سرطان.',
   70, (SELECT id FROM pages WHERE path = '/service/روان-پزشکی/')),

  ('nutrition', 'تغذیه و رژیم‌درمانی',
   'تغذیه‌ی بالینی دوره‌ی درمان',
   'رژیم‌درمانی تخصصی، کنترل وزن و برنامه‌ی غذایی متناسب با دوره‌ی شیمی‌درمانی.',
   80, (SELECT id FROM pages WHERE path = '/service/تغذیه/')),

  ('persian-medicine', 'طب ایرانی',
   'اصلاح سبک زندگی',
   'کاهش عوارض شیمی‌درمانی و رادیوتراپی و اصلاح سبک زندگی، زیر نظر عضو هیأت علمی.',
   90, (SELECT id FROM pages WHERE path = '/service/طب-ایرانی/')),

  ('urology', 'اورولوژی',
   'کلیه و مجاری ادراری',
   'تشخیص و درمان بیماری‌های کلیه، مجاری ادراری و تناسلی.',
   100, (SELECT id FROM pages WHERE path = '/service/urology-clinic/'))
ON DUPLICATE KEY UPDATE
  name = VALUES(name), tagline = VALUES(tagline),
  summary = VALUES(summary), sort = VALUES(sort), page_id = VALUES(page_id);

-- ------------------------------------------------------------
--  ۱۲ پزشک
--  شماره‌ی نظام پزشکی از سایت فعلی برداشته شده و سیگنال
--  اصلی E-E-A-T برای محتوای سلامت است.
-- ------------------------------------------------------------
INSERT INTO doctors (page_id, name, specialty, fellowship, university, license_no, schedule, is_founder, sort) VALUES
  ((SELECT id FROM pages WHERE path = '/team/دکتر-محبوبه-خلیلی/'),
   'دکتر محبوبه خلیلی', 'متخصص قلب و عروق',
   'فلوشیپ کاردیو آنکولوژی — انستیتو قلب و عروق شهید رجایی',
   'دانشگاه علوم پزشکی شهید بهشتی', '94360',
   'شنبه، دوشنبه، چهارشنبه — ۹ تا ۱۴', 1, 10),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-احمد-مافی/'),
   'دکتر احمد مافی', 'متخصص رادیوتراپی انکولوژی',
   NULL, 'دانشیار دانشگاه علوم پزشکی شهید بهشتی', '79018',
   NULL, 0, 20),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-حسین-اصغری-پور/'),
   'دکتر حسین اصغری‌پور', 'فوق تخصص خون و انکولوژی',
   'عضو انجمن سرطان اروپا و آمریکا',
   'دارای بورد تخصصی و فوق تخصصی', '103824',
   NULL, 0, 30),

  ((SELECT id FROM pages WHERE path = '/team/دكتر-فاطمه-نائيني/'),
   'دکتر فاطمه نائینی', 'متخصص تغذیه بالینی و رژیم‌درمانی',
   'عضو بنیاد ملی نخبگان — شاخص علمی ۲۲ و بیش از ۵۰ مقاله بین‌المللی',
   'دانشگاه علوم پزشکی تهران', 'ن.ت ۸۱۶۴',
   NULL, 0, 40),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-بهناز-بهزادی/'),
   'دکتر بهناز بهزادی', 'متخصص رادیوانکولوژی',
   'عضو انجمن رادیوتراپی و انکولوژی',
   'بورد تخصصی رادیوتراپی — دانشگاه علوم پزشکی شهید بهشتی', NULL,
   NULL, 0, 50),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-علیرضا-تاتینا/'),
   'دکتر علیرضا تاتینا', 'متخصص قلب و عروق',
   'فلوشیپ کاردیو آنکولوژی — انستیتو قلب و عروق شهید رجایی',
   'دارای بورد تخصصی', '97995',
   NULL, 0, 60),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-مهناز-عالم-زاده-بحرینی/'),
   'دکتر مهناز عالم‌زاده بحرینی', 'متخصص قلب و عروق',
   'فلوشیپ اکوکاردیوگرافی — انستیتو قلب و عروق شهید رجایی',
   'دارای بورد تخصصی', '103957',
   NULL, 0, 70),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-شادی-شکرخوار/'),
   'دکتر شادی شکرخوار', 'متخصص قلب و عروق',
   'فلوشیپ اکوکاردیوگرافی',
   'دانشگاه علوم پزشکی شهید بهشتی', '105449',
   NULL, 0, 80),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-حسام-دانش-آموز/'),
   'دکتر حسام دانش‌آموز', 'فوق تخصص قلب کودکان',
   'متخصص کودکان و اطفال', NULL, NULL,
   NULL, 0, 90),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-مریم-بدیع-زادگان/'),
   'دکتر مریم بدیع‌زادگان', 'متخصص اعصاب و روان',
   NULL, 'بورد تخصصی از دانشگاه علوم پزشکی شهید بهشتی', '90667',
   NULL, 0, 100),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-غزاله-حیدریراد/'),
   'دکتر غزاله حیدری‌راد', 'پزشک طب ایرانی (MD.PhD)',
   'عضو هیأت علمی دانشگاه علوم پزشکی شهید بهشتی', NULL, '105995',
   NULL, 0, 110),

  ((SELECT id FROM pages WHERE path = '/team/دکتر-رضا-مقبولی/'),
   'دکتر رضا مقبولی', 'متخصص اورولوژی',
   'جراحی کلیه، مجاری ادراری و تناسلی', NULL, '189251',
   NULL, 0, 120)
ON DUPLICATE KEY UPDATE
  specialty = VALUES(specialty), fellowship = VALUES(fellowship),
  university = VALUES(university), license_no = VALUES(license_no),
  schedule = VALUES(schedule), sort = VALUES(sort);

-- ------------------------------------------------------------
--  اتصال پزشک به کلینیک
-- ------------------------------------------------------------
INSERT INTO doctor_clinic (doctor_id, clinic_id)
SELECT d.id, c.id FROM doctors d, clinics c WHERE
     (d.name = 'دکتر محبوبه خلیلی'           AND c.slug IN ('cardiology','chemotherapy'))
  OR (d.name = 'دکتر علیرضا تاتینا'          AND c.slug IN ('cardiology','chemotherapy'))
  OR (d.name = 'دکتر مهناز عالم‌زاده بحرینی' AND c.slug = 'cardiology')
  OR (d.name = 'دکتر شادی شکرخوار'           AND c.slug = 'cardiology')
  OR (d.name = 'دکتر حسام دانش‌آموز'         AND c.slug = 'cardiology')
  OR (d.name = 'دکتر احمد مافی'              AND c.slug IN ('oncology','chemotherapy'))
  OR (d.name = 'دکتر حسین اصغری‌پور'         AND c.slug IN ('oncology','chemotherapy'))
  OR (d.name = 'دکتر بهناز بهزادی'           AND c.slug = 'oncology')
  OR (d.name = 'دکتر فاطمه نائینی'           AND c.slug = 'nutrition')
  OR (d.name = 'دکتر مریم بدیع‌زادگان'       AND c.slug = 'mental-health')
  OR (d.name = 'دکتر غزاله حیدری‌راد'        AND c.slug = 'persian-medicine')
  OR (d.name = 'دکتر رضا مقبولی'             AND c.slug = 'urology')
ON DUPLICATE KEY UPDATE doctor_id = VALUES(doctor_id);

-- ------------------------------------------------------------
--  اتصال هر صفحه‌ی خدمت به کلینیک مربوطه
--  (بر اساس الگوی slug، چون خدمات زخم/غدد/عفونی اسلاگ انگلیسی دارند)
-- ------------------------------------------------------------
UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'wound')
  WHERE p.type = 'service' AND (p.slug LIKE '%wound%' OR p.slug LIKE '%ulcer%' OR p.slug = 'diabetic-foot');

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'endocrine')
  WHERE p.type = 'service' AND p.slug IN
  ('endocrine-clinic','adrenal','diabetes','growth-puberty','metabolic-syndrome',
   'obesity','osteoporosis','pcos','pituitary','sex-hormones','thyroid');

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'infectious')
  WHERE p.type = 'service' AND p.slug IN
  ('infectious-clinic','viral-hepatitis','sti','tuberculosis','gi-infection','brucellosis',
   'respiratory-infection','fungal-infection','skin-infection','urinary-tract-infection',
   'fever-unknown-origin');

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'cardiology')
  WHERE p.path IN ('/service/قلب-و-عروق/','/service/کلینیک-واریس/',
                   '/service/کلینیک-قلب-کودکان/','/service/اکوکاردیوگرافی-قلب-جنین/');

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'oncology')
  WHERE p.path IN ('/service/آنکولوژی/','/service/هماتولوژی/');

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'chemotherapy')
  WHERE p.path = '/service/شیمی-درمانی/';

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'mental-health')
  WHERE p.path IN ('/service/روان-پزشکی/','/service/روان-شناسی/');

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'nutrition')
  WHERE p.path = '/service/تغذیه/';

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'persian-medicine')
  WHERE p.path = '/service/طب-ایرانی/';

UPDATE pages p SET clinic_id = (SELECT id FROM clinics WHERE slug = 'urology')
  WHERE p.slug = 'urology-clinic';

-- ------------------------------------------------------------
--  تنظیمات عمومی
-- ------------------------------------------------------------
INSERT INTO settings (k, v) VALUES
  ('site_name',      'همراه کلینیک'),
  ('phone',          '۰۲۱۹۱۳۰۳۱۳۲'),
  ('phone_raw',      '02191303132'),
  ('address',        'تهران، خیابان شریعتی، نرسیده به میدان قدس، کوچه مهنا ۱، پلاک ۶'),
  ('hours',          'شنبه تا چهارشنبه ۸ تا ۲۰ · پنجشنبه ۸ تا ۱۳'),
  ('canonical_host', 'hamrahclinic.ir')
ON DUPLICATE KEY UPDATE v = VALUES(v);

-- ------------------------------------------------------------
--  تصاویر
--  فایل‌ها در public/assets/img/ هستند و همراه مخزن استقرار
--  می‌شوند. عکس‌های باکیفیت‌تر بعداً از پنل جایگزین می‌شوند.
-- ------------------------------------------------------------
UPDATE clinics SET image = 'clinics/cardiology.jpg'  WHERE slug IN ('cardiology','chemotherapy');
UPDATE clinics SET image = 'clinics/oncology.webp'   WHERE slug = 'oncology';
UPDATE clinics SET image = 'clinics/wound.jpg'       WHERE slug = 'wound';
UPDATE clinics SET image = 'clinics/endocrine.jpg'   WHERE slug IN ('endocrine','nutrition');
UPDATE clinics SET image = 'clinics/infectious.jpg'  WHERE slug IN ('infectious','urology','mental-health','persian-medicine');

UPDATE pages SET hero_image = 'hero-reception.jpg' WHERE path = '/';

-- ------------------------------------------------------------
--  عکس پزشکان
--
--  نگاشت از تگ og:image صفحه‌ی هر پزشک در سایت فعلی گرفته
--  شده، نه حدس. نسخه‌ی قبلی حدسی بود و همه‌ی ۱۲ نفر عکس
--  اشتباه گرفته بودند.
-- ------------------------------------------------------------
UPDATE doctors SET photo = 'doctors/khalili.jpg' WHERE name = 'دکتر محبوبه خلیلی';
UPDATE doctors SET photo = 'doctors/mafi.jpg' WHERE name = 'دکتر احمد مافی';
UPDATE doctors SET photo = 'doctors/asghari-pour.jpg' WHERE name = 'دکتر حسین اصغری‌پور';
UPDATE doctors SET photo = 'doctors/naeini.jpg' WHERE name = 'دکتر فاطمه نائینی';
UPDATE doctors SET photo = 'doctors/behzadi.jpg' WHERE name = 'دکتر بهناز بهزادی';
UPDATE doctors SET photo = 'doctors/tatina.jpg' WHERE name = 'دکتر علیرضا تاتینا';
UPDATE doctors SET photo = 'doctors/alamzadeh.jpg' WHERE name = 'دکتر مهناز عالم‌زاده بحرینی';
UPDATE doctors SET photo = 'doctors/shekarkhar.jpg' WHERE name = 'دکتر شادی شکرخوار';
UPDATE doctors SET photo = 'doctors/danesh-amooz.jpg' WHERE name = 'دکتر حسام دانش‌آموز';
UPDATE doctors SET photo = 'doctors/badiezadegan.jpg' WHERE name = 'دکتر مریم بدیع‌زادگان';
UPDATE doctors SET photo = 'doctors/heydari-rad.jpg' WHERE name = 'دکتر غزاله حیدری‌راد';
UPDATE doctors SET photo = 'doctors/moghbouli.jpg' WHERE name = 'دکتر رضا مقبولی';

-- ##### db/seed/03-content.sql #####

-- ============================================================
--  همراه کلینیک — متن صفحات
--  تولید خودکار: perl db/seed/gen-content.pl
--
--  متن از آرشیو سایت فعلی استخراج و به HTML معنایی تبدیل شده:
--  فقط h2/h3/h4، p، ul/ol/li، strong، a و table باقی مانده‌اند.
--  همه‌ی div و span و class المنتور حذف شده چون قالب جدید
--  استایل خودش را دارد.
--
--  پیش‌نیاز: 01-pages.sql اجرا شده باشد.
-- ============================================================

UPDATE pages SET body = '<p>همراه کلینیک<br></p>
<p>با شما برای سلامتی</p>
</rs-layer>
<a href="/team/">تیم ما را مشاهده کنید
</a>
</rs-group>
<a href="/blog/">بلاگ
</a>
</rs-slide>
<p>همراه سلامت،<br></p>
<p>همراه زندگی؛ درمانی با علم و همدلی</p>
</rs-layer>
<a href="/contact-us/">تماس با همراه کلینیک
</a>خدمات جامع سرطان ، از پیشگیری تا درمان.
</rs-layer>
</rs-group>
</rs-slide>
</rs-slides>
</rs-module>
</rs-module-wrap>
<h2>همراه کلینیک</h2>
<p>تنها چند کلیک تا شروع مسیر بهبود</p>
<h4>وقت مشاوره و درمان خود را رزرو کنید</h4>
<p>با سیستم رزرو آنلاین کلینیک همراه، میتوانید به راحتی زمان ملاقات با پزشک یا مشاور مورد نظر خود را انتخاب کنید. بدون معطلی و تنها در چند دقیقه، نوبت خود را ثبت کنید و مطمئن باشید که در زمان مقرر، آماده دریافت خدمات خواهید بود.</p>
<p>سال ها تجربه در خدمت سلامتی</p>
<h4>داستان ما، داستان بیماران است</h4>
<p>کلینیک همراه با رسالت ارائه‌ی خدمات جامع درمانی و مشاوره‌ای تأسیس شد. ما باور داریم که درمان تنها یک فرایند پزشکی نیست، بلکه مسیری همراه با همدلی، تخصص و امید است. از شیمی‌درمانی گرفته تا مراقبت‌های قلبی، روانشناسی و تغذیه سالم، همواره تلاش کرده‌ایم بیماران را نه‌فقط درمان کنیم، بلکه در مسیر زندگی سالم‌تر همراهشان باشیم.</p>
<ul>
<li>تخصصی و چندرشته‌ای</li>
<li>تجهیزات مدرن</li>
</ul>
<ul>
<li>توجه به تجربه بیمار</li>
<li>دسترسی آسان</li>
</ul>
<a href="/wp-content/uploads/2025/12/Firefly_Gemini-Flash_ابجکت-صورتی-رنک-در-سمت-راست-کادر-در-قفسه-حذف-شود-440401.jpg">
</a>
<a href="/wp-content/uploads/2025/12/MAL7293.jpg">
</a>
<h3>دکتر محبوبه خلیلی</h3>
<p>(مدیر و موسس کلینیک)</p>
<p>چرا کلینیک همراه؟</p>
<h4>جایی که علم و همدلی در کنار هم قرار میگیرند</h4>
<p>انتخاب کلینیک همراه به معنای انتخاب اطمینان و آرامش است.</p>
<h3>همراهی در مسیر آرامش ذهن</h3>
<p>خدمات روانشناسی همراه کلینیک با هدف افزایش آرامش، بهبود روابط فردی و اجتماعی، و مدیریت استرس ارائه می‌شود. متخصصان ما همراه شما هستند تا راهکارهای علمی و عملی برای ارتقای سلامت روان ارائه دهند.</p>
<h3>تغذیه سالم برای زندگی سالم</h3>
<p>بخش تغذیه همراه کلینیک با ارائه رژیم‌های غذایی تخصصی، کنترل وزن، و برنامه‌های شخصی‌سازی‌شده به شما کمک می‌کند سبک زندگی سالم و متعادلی داشته باشید.</p>
<h3>همراهی در مسیر درمان</h3>
<p>واحد شیمی‌درمانی همراه کلینیک با تکیه بر دانش روز و استانداردهای جهانی، خدمات درمانی ایمن و تخصصی ارائه می‌دهد تا بیماران مسیر درمان خود را با اطمینان و آرامش طی کنند.</p>
<h3>مراقبت ویژه از سلامت قلب</h3>
<p>با بهره‌گیری از تجهیزات پیشرفته و پزشکان متخصص قلب، همراه کلینیک خدمات جامع تشخیصی و درمانی ارائه می‌دهد تا سلامت قلب و عروق شما تضمین شود.</p>
<p>از درمان تا تخصصی تا مشاوره روان و تغذیه</p>
<h4>خدمات جامع پزشکی و مشاوره ای</h4>
<p>در کلینیک همراه طیف گسترده‌ای از خدمات درمانی و مشاوره‌ای ارائه می‌شود.</p>
<p>ما باور داریم درمان مؤثر زمانی حاصل می‌شود که سلامت جسم، روان و تغذیه در کنار هم قرار گیرند.</p>
<a href="/service/هماتولوژی/">
</a>
<h3>
<a href="/service/هماتولوژی/">هماتولوژی</a>
</h3>
<a href="/service/هماتولوژی/">+</a>
<a href="/service/آنکولوژی/">
</a>
<h3>
<a href="/service/آنکولوژی/">آنکولوژی</a>
</h3>
<a href="/service/آنکولوژی/">+</a>
<a href="/service/شیمی-درمانی/">
</a>
<h3>
<a href="/service/شیمی-درمانی/">شیمی درمانی</a>
</h3>
<a href="/service/شیمی-درمانی/">+</a>
<a href="/service/قلب-و-عروق/">
</a>
<h3>
<a href="/service/قلب-و-عروق/">قلب و عروق</a>
</h3>
<a href="/service/قلب-و-عروق/">+</a>
<a href="/service/روان-پزشکی/">
</a>
<h3>
<a href="/service/روان-پزشکی/">روان پزشکی</a>
</h3>
<a href="/service/روان-پزشکی/">+</a>
<a href="/service/روان-شناسی/">
</a>
<h3>
<a href="/service/روان-شناسی/">روان شناسی</a>
</h3>
<a href="/service/روان-شناسی/">+</a>
<a href="/service/تغذیه/">
</a>
<h3>
<a href="/service/تغذیه/">تغذیه</a>
</h3>
<a href="/service/تغذیه/">+</a>
<a href="/service/طب-ایرانی/">
</a>
<h3>
<a href="/service/طب-ایرانی/">طب ایرانی (سبک زندگی)</a>
</h3>
<a href="/service/طب-ایرانی/">+</a>
<h3>
<a href="/service/لیست-خدمات-کلینیک-همراه/">لیست خدمات کلینیک همراه</a>
</h3>
<a href="/service/لیست-خدمات-کلینیک-همراه/">+</a>
<h3>
<a href="/service/کلینیک-واریس/">کلینیک واریس</a>
</h3>
<a href="/service/کلینیک-واریس/">+</a>
<p>تیمی از متخصصان برجسته</p>
<h4>تجربه، دانش و تعهد به سلامتی شما</h4>
<p>پزشکان و مشاوران کلینیک همراه از میان متخصصان شناخته‌شده انتخاب شده‌اند. هر یک با تجربه‌ای ارزشمند در رشته‌ی تخصصی خود، متعهد هستند تا بهترین خدمات را به بیماران ارائه دهند. ما باور داریم ترکیب تجربه، دانش روز و تعهد انسانی، بهترین تضمین برای بهبود بیماران است.</p>
<p>دکتر احمد مافی</p>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>‌</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<p>دکتر محبوبه خلیلی</p>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>‌</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<p>دکتر حسین اصغری پور</p>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<p>۱۰۳۸۲۴</p>
<p>دکتر بهناز بهزادی</p>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<p>‌</p>
<p>دکتر رضا مقبولی</p>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>‌</p>
<p>‌</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<p>نظام پزشکی 189251</p>
<p>دکتر حسام دانش آموز</p>
<p>‌</p>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>
<p>‌</p>
<p>دکتر مریم بدیع زادگان</p>
<p>متخصص اعصاب و روان (روانپزشک)
</p>
<p>دارای بورد تخصصی از دانشگاه شهید بهشتی</p>
<p>‌</p>
<a href="/team/دکتر-مریم-بدیع-زادگان/">
مشاهده جزئیات
</a>
<p>نظام پزشکی: ۹۰۶۶۷</p>
<p>دکتر مهناز عالم زاده بحرینی</p>
<p>متخصص قلب و عروق | دارای بورد تخصصی</p>
<p>فلوشیپ اکوکاردیوگرافی از انستیتو قلب و عروق شهید رجایی</p>
<p>‌</p>
<a href="/team/دکتر-مهناز-عالم-زاده-بحرینی/">
مشاهده جزئیات
</a>
<p>نظام پزشکی: ۱۰۳۹۵۷</p>
<p>دکتر شادی شکرخوار</p>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>فلوشیپ اکوکاردیوگرافی از انستیتو قلب و عروق شهید بهشتی</p>
<p>‌</p>
<a href="/team/دکتر-شادی-شکرخوار/">
مشاهده جزئیات
</a>
<p>نظام پزشکی: ۱۰۵۴۴۹</p>
<p>دکتر علیرضا تاتینا</p>
<p>متخصص قلب و عروق | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>‌</p>
<a href="/team/دکتر-علیرضا-تاتینا/">
مشاهده جزئیات
</a>
<p>نظام پزشکی: 97995</p>
<p>دکتر غزاله حیدری‌راد</p>
<p>پزشک (MD.PhD) طب ایرانی</p>
<p>عضو هیأت علمی دانشگاه علوم پزشکی شهید بهشتی </p>
<p>‌</p>
<a href="/team/دکتر-غزاله-حیدریراد/">
مشاهده جزئیات
</a>
<p>نظام پزشکی: ١٠٥٩٩٥</p>
<p>دكتر فاطمه نائيني</p>
<p>متخصص تغذيه بالینی و رژيم درماني</p>
<p>دانشگاه علوم پزشكي تهران | عضو ملی بنیاد ملی نخبگان </p>
<p>شاخص علمی 22H | بیش از 50 مقاله علمی در مجلات معتبر بین المللی</p>
<a href="/team/دكتر-فاطمه-نائيني/">
مشاهده جزئیات
</a>
<p>نظام پزشكي: ن.ت: ٨١٦٤</p>
<a> همین حالا تماس بگیرید</a>
<p>۰۲۱۹۱۳۰۳۱۳۲</p>
<a href="/contact-us/">
امروز مشورت کنید
</a>
<p>روایت بیماران از مسیر درمان در کلینیک همراه</p>
<h4>تجربه های شما، سرمایه ماست</h4>
<p>«وقتی برای اولین بار به کلینیک همراه آمدم، از استرس و نگرانی آینده پر بودم. اما تیم حرفه‌ای و صبور کلینیک در هر مرحله کنارم بودند. شیمی‌درمانی برایم سخت بود، اما این‌که حس می‌کردم تنها نیستم، همه‌چیز را آسان‌تر کرد. امروز با امید و آرامش بیشتری به زندگی نگاه می‌کنم.»</p>
<h3>لیلا جوادی</h3>
<p>«مشکل قلبی‌ام باعث شده بود زندگی روزمره‌ام به شدت تحت تأثیر قرار بگیرد. در کلینیک همراه، علاوه بر درمان تخصصی، سبک زندگی و تغذیه مناسب برایم طراحی شد. نتیجه فراتر از انتظارم بود؛ نه‌تنها وضعیت قلبم بهتر شد، بلکه انرژی و نشاطم هم بازگشت.»</p>
<h3>مجید حیدری</h3>
<p>مشتری</p>
<p>«مدتی طولانی با اضطراب و اضافه‌وزن دست‌وپنجه نرم می‌کردم. ترکیب مشاوره روانشناسی و برنامه تغذیه‌ای که در کلینیک همراه دریافت کردم، کمک کرد تا هم آرامش روحی پیدا کنم و هم وزنم را کاهش دهم. امروز احساس می‌کنم دوباره کنترل زندگی‌ام را به دست آورده‌ام.»</p>
<h3>علی علیاری</h3>
<p>مشتری</p>
<p>بلاگ سلامت همراه</p>
<h4>مقالات علمی و کاربردی برای زندگی سالم</h4>
<p>در بلاگ کلینیک همراه، به جدیدترین موضوعات حوزه‌ی شیمی‌درمانی، بیماری‌های قلبی، روانشناسی و تغذیه پرداخته می‌شود. مقالات ما توسط پزشکان و مشاوران متخصص نوشته شده‌اند تا بیماران و خانواده‌ها با زبان ساده و کاربردی، اطلاعات علمی و معتبر دریافت کنند. از نکات پیشگیری و سبک زندگی سالم گرفته تا معرفی روش‌های نوین درمانی، همه در اینجا جمع‌آوری شده است تا شما بتوانید آگاهانه‌تر تصمیم بگیرید و زندگی سالم‌تری داشته باشید.</p>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<p>08 شهریور 1405</p>
<a href="/category/قلب-و-عروق/">قلب و عروق</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">ایا گرفتگی عروق پا خطرناک است؟</a>
</h3>
<a href="/category/قلب-و-عروق/">قلب و عروق</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">روغن سیاه دانه برای واریس پا [فواید و روش مصرف]</a>
</h3>
<a href="/category/heart-diseases/">بیماری‌های قلبی</a>
<a href="/category/قلب-و-عروق/">قلب و عروق</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">فشار دیاستولیک پایین نشانه چیست؟</a>
</h3>
<a href="/category/قلب-و-عروق/">قلب و عروق</a>
<a href="/category/heart-diseases/">بیماری‌های قلبی</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">قرص نیتروگلیسیرین چه زمانی مصرف شود؟</a>
</h3>
<a href="/category/heart-diseases/">بیماری‌های قلبی</a>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">تشخیص آریتمی قلبی در خانه</a>
</h3>
<a href="/category/شیمی-درمانی/">شیمی درمانی</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">بهترین صبحانه قبل از شیمی درمانی</a>
</h3>
<h4>مراجعه حضوری</h4>
<p>شنبه تا چهارشنبه :‌ ۸ تا ۲۰ | پنجشنبه‌: ۸ تا ۱۳</p>
<a>
</a>
<h4>تماس تلفنی</h4>
<p>هر گاه خواستید میتوانید با تماس تلغنی سوال خود را بپرسید</p>
<a href="/contact-us/">
</a>
<a>
</a>
<p>پشتیبانی ۲۴ ساعته هفت روز هفته در خدمت شما</p>' WHERE path = '/';

UPDATE pages SET body = '<h3>معرفی کلینیک فوق تخصصی همراه</h3>
<p>کلینیک فوق تخصصی همراه به عنوان یک کلینیک فوق تخصصی در سال ۱۴۰۴ فعالیت خود را در قلب منطقه تجریش تهران در محیطی سرشار از آرامش و بدور از هیاهو، آغاز به کار کرد.</p>
<p>کلینیک همراه شامل بخشهای فوق تخصصی با محوریت قلب و عروق و آنکولوژی و با هدف ایجاد کلینیک چند تخصصی با رویکرد MDT جهت درمان بیماری‌ها، خصوصا بیماران سرطانی می‌باشد. بدیهیست ارزیابی بیماران بطور همزمان توسط اساتید رشته های مختلف می‌تواند به بهترین گزینه های درمانی برای بیماران ختم شود.</p>
<p>برای پرسیدن هر سوالی تماس بگیرید</p>
<p>۰۲۱۹۱۳۰۳۱۳۲</p>
<h3>دکتر محبوبه خلیلی</h3>
<p>(مدیر و موسس کلینیک)</p>
<h3>24 سال سابقه کار</h3>
<p>هیئت مدیره</p>
<h3>تیم مدیریتی کلینیک همراه</h3>' WHERE path = '/about-us/';

UPDATE pages SET body = '<h3>
برای هر نوع کمک و اطلاعات با ما در تماس باشید</h3>
<h3>آدرس دفتر مرکزی ما</h3>
تهران، خیابان شریعتی، نرسیده به میدان قدس، کوچه مهنا ۱، پلاک ۶
<h3>برای کمک تماس بگیرید</h3>
۰۲۱۹۱۳۰۳۱۳۲
<h3>برای اطلاعات به ما ایمیل کنید</h3>
info@hamrahclinic.ir
<h3>اینستاگرام <br>
همراه کلینیک رو دنبال کنید</h3>
<a>
دنبال کردن
</a>
<h3>در واتساپ<br>
با ما در ارتباط باشید</h3>
<a>
ارسال پیام
</a>
<h2>مسیر یابی با اپلیکیشن</h2>
<a>
</a>
<a>
</a>
<a>
</a>' WHERE path = '/contact-us/';

UPDATE pages SET body = '<h2>
بهترین پزشکان در همراه کلینیک در کنار شما</h2>
<p>در همراه کلینیک می‌توانید از بین ده‌ها پزشک حرفه‌ای، باتجربه و معتبر، مناسب‌ترین متخصص را برای نیاز خود پیدا کنید. هر پروفایل شامل اطلاعات دقیق، نوبت‌دهی آنلاین و نظرات بیماران است تا راحت‌تر و مطمئن‌تر تصمیم بگیرید.</p>' WHERE path = '/team/';

UPDATE pages SET body = '<h2>اکوکاردیوگرافی قلب جنین (Fetal Echocardiography)</h2>
<p>اکوکاردیوگرافی قلب جنین، یک روش تصویربرداری تخصصی، غیرتهاجمی و کاملاً ایمن است که با استفاده از امواج صوتی، ساختار، عملکرد و ریتم قلب جنین را در دوران بارداری بررسی می‌کند. این خدمت در همراه کلینیک با پیشرفته‌ترین تجهیزات و توسط متخصصین مجرب انجام می‌شود تا با تشخیص زودهنگام ناهنجاری‌های قلبی، زمینه‌ساز مراقبت‌های به‌موقع و برنامه‌ریزی درمانی مناسب پس از تولد باشد.</p>
<h2>اکوکاردیوگرافی جنینی چیست و چرا اهمیت دارد؟</h2>
<p>اکوکاردیوگرافی قلب جنین نوعی سونوگرافی تخصصی است که به‌طور خاص بر ارزیابی قلب در حال رشد جنین تمرکز دارد. این روش به پزشکان اجازه می‌دهد تا موقعیت، اندازه، ساختار آناتومیک، عملکرد دریچه‌ها، جریان خون و ریتم قلب جنین را با دقت بالا بررسی کنند.</p>
<p>اهمیت این خدمت در این است که بسیاری از ناهنجاری‌های مادرزادی قلب را می‌توان قبل از تولد تشخیص داد. این تشخیص زودهنگام به تیم پزشکی امکان می‌دهد تا برنامه‌ریزی دقیقی برای مراقبت‌های دوران بارداری، زمان و مکان زایمان، و اقدامات درمانی فوری پس از تولد انجام دهند.</p>
<h2>بهترین زمان انجام اکوکاردیوگرافی جنین</h2>
<p>بهترین زمان برای انجام اکوکاردیوگرافی قلب جنین، سه‌ماهه دوم بارداری و به‌طور خاص بین هفته‌های ۱۸ تا ۲۴ بارداری است. در این بازه زمانی، قلب جنین به اندازه کافی رشد کرده و ساختارهای آناتومیک آن به‌وضوح قابل مشاهده هستند.</p>
<p>با این حال، بسته به شرایط خاص و نظر پزشک معالج، این آزمایش می‌تواند از هفته ۱۴ بارداری تا انتهای دوران حاملگی نیز انجام شود. در مواردی که نیاز به تصمیم‌گیری‌های مهم پزشکی وجود دارد، انجام آزمایش قبل از هفته ۲۲ توصیه می‌شود.</p>
<h3>زمان‌بندی طلایی</h3>
<p>هفته ۱۸ تا ۲۲ بارداری، دوره طلایی برای اکوکاردیوگرافی جنین است. در این زمان، آناتومی قلب به‌طور کامل شکل گرفته و هنوز فضای کافی برای تصویربرداری واضح وجود دارد.</p>
<h2>چه کسانی باید اکوکاردیوگرافی جنین انجام دهند؟</h2>
<p>اگرچه این آزمایش برای تمام زنان باردار مفید است، اما برای گروه‌های زیر انجام آن <strong>ضروری</strong> توصیه می‌شود:</p>
<h3>عوامل مربوط به سابقه خانوادگی</h3>
<ul>
<li>سابقه بیماری‌های مادرزادی قلبی در والدین، خواهر و برادرها یا فرزندان قبلی.</li>
<li>وجود سندرم‌های ژنتیکی در خانواده (مانند سندرم داون)</li>
<li>سابقه مرگ ناگهانی قلبی در خویشاوندان درجه یک</li>
</ul>
<h3>عوامل مربوط به سلامت مادر</h3>
<ul>
<li>دیابت نوع ۱ یا ۲ (به‌ویژه اگر کنترل‌نشده باشد)</li>
<li>بیماری‌های خودایمنی (لوپوس، سندرم آنتی‌فسفولیپید)</li>
<li>فنیل‌کتونوری (PKU)</li>
<li>مصرف داروهای خاص در بارداری (داروهای ضدتشنج، لیتیوم، رتینوئیدها)</li>
<li>عفونت‌های دوران بارداری (سرخجه، CMV، توکسوپلاسموز)</li>
</ul>
<h3>یافته‌های غیرطبیعی در سونوگرافی‌های روتین</h3>
<ul>
<li>مشکوک بودن به ناهنجاری قلبی در سونوگرافی آنومالی</li>
<li>آریتمی جنینی (ضربان نامنظم قلب)</li>
<li>افزایش یا کاهش مایع آمنیوتیک</li>
<li>هیدروپس جنینی (تجمع مایع در بافت‌های جنین)</li>
<li>وجود ناهنجاری‌های دیگر در اندام‌های جنین</li>
</ul>
<h3>سایر موارد</h3>
<ul>
<li>بارداری‌های چندقلو (به‌ویژه دوقلوهای هم‌جفت)</li>
<li>بارداری با روش‌های کمک‌باروری (IVF/ICSI)</li>
<li>سن مادر بالای ۳۵ سال</li>
</ul>
<h2>تفاوت اکوکاردیوگرافی جنین با سونوگرافی معمولی</h2>
<h3>سونوگرافی آنومالی معمولی</h3>
<ul>
<li>بررسی کلی تمام اندام‌ها</li>
<li>نگاه کلی به چهار حفره قلب</li>
<li>زمان: ۳۰-۴۵ دقیقه</li>
<li>توسط متخصص رادیولوژی یا سونوگرافیست</li>
<li>غربالگری عمومی</li>
</ul>
<h3>اکوکاردیوگرافی تخصصی</h3>
<ul>
<li>تمرکز انحصاری بر قلب و عروق بزرگ</li>
<li>بررسی دقیق تمام ساختارهای قلبی</li>
<li>زمان: ۴۵-۹۰ دقیقه</li>
<li>توسط فلوشیپ قلب کودکان یا رادیولوژیست متخصص</li>
<li>تشخیص تخصصی و دقیق</li>
</ul>
<h2>روش انجام اکوکاردیوگرافی جنین</h2>
<p>این آزمایش یک روش <strong>کاملاً غیرتهاجمی، بدون درد و بدون اشعه</strong> است که از فناوری اولتراسوند (امواج صوتی) استفاده می‌کند، فرآیند انجام آن به شرح زیر است:</p>
<p>۱</p>
<h4>آمادگی قبل از آزمایش</h4>
<p>نیاز به آمادگی خاصی نیست. بهتر است ۳۰ دقیقه تا ۲ ساعت زمان در نظر بگیرید.</p>
<p>۲</p>
<h4>وضعیت قرارگیری</h4>
<p>مادر به پشت دراز می‌کشد و شکم در معرض دید قرار می‌گیرد.</p>
<p>۳</p>
<h4>استفاده از ژل و پروب</h4>
<p>ژل مخصوص روی شکم مالیده شده و پروب اولتراسوند حرکت داده می‌شود.</p>
<p>۴</p>
<h4>تصویربرداری تخصصی</h4>
<p>تصاویر دقیق از تمام بخش‌های قلب ثبت و تحلیل می‌شود.</p>
<p>در موارد خاص (مانند چاقی مادر یا وضعیت نامناسب جنین)، ممکن است از روش <strong>واژینال</strong> نیز استفاده شود که در هفته‌های نخستین بارداری دقت بالاتری دارد.</p>
<h2>مزایای اکوکاردیوگرافی جنین در همراه کلینیک</h2>
<p>🛡️</p>
<h3>کاملاً ایمن</h3>
<p>بدون اشعه و بدون خطر برای مادر و جنین</p>
<p>🎯</p>
<h3>تشخیص زودهنگام</h3>
<p>شناسایی ناهنجاری‌ها قبل از تولد برای برنامه‌ریزی بهتر</p>
<p>👨‍⚕️</p>
<h3>تیم متخصص</h3>
<p>انجام توسط فلوشیپ‌های فوق تخصصی قلب کودکان</p>
<p>📊</p>
<h3>تجهیزات پیشرفته</h3>
<p>دستگاه‌های اکوکاردیوگرافی با رزولوشن بالا</p>
<h3>توصیه تخصصی</h3>
<p>حتی اگر در گروه پرخطر قرار ندارید، در صورت داشتن هرگونه نگرانی درباره سلامت قلب جنین یا مشاهده علائم غیرعادی در سونوگرافی‌های روتین، با پزشک خود درباره انجام اکوکاردیوگرافی مشورت کنید. تشخیص زودهنگام می‌تواند تفاوت بزرگی در نتیجه درمان ایجاد کند.</p>
<h3>نکته مهم</h3>
<p>اکوکاردیوگرافی جنین یک روش <strong>غربالگری و تشخیصی</strong> است، نه درمانی. در صورت تشخیص ناهنجاری، این به معنای پایان راه نیست. بسیاری از ناهنجاری‌های قلبی با درمان مناسب پس از تولد، قابل اصلاح هستند و کودک می‌تواند زندگی طبیعی داشته باشد.</p>
<h2>سوالات متداول درباره اکوکاردیوگرافی جنین</h2>
<h4>۱. آیا اکوکاردیوگرافی برای جنین خطرناک است؟</h4>
<p>خیر، این روش کاملاً ایمن است و از امواج صوتی (نه اشعه) استفاده می‌کند. تاکنون هیچ عارضه‌ای برای مادر یا جنین گزارش نشده است.</p>
<h4>۲. آیا می‌توانم همراه جنین در حین آزمایش حرکت کنم یا صحبت کنم؟</h4>
<p>بله، اما برای دریافت تصاویر باکیفیت، بهتر است در حین تصویربرداری آرام باشید و از حرکات ناگهانی خودداری کنید. گاهی ممکن است از شما خواسته شود برای چند دقیقه در وضعیت خاصی بمانید.</p>
<h4>۳. اگر جنین در وضعیت نامناسبی باشد چه می‌شود؟</h4>
<p>در این موارد، ممکن است از شما خواسته شود کمی راه بروید، چیزی بخورید یا تغییر وضعیت دهید. گاهی نیاز است آزمایش در روز دیگری تکرار شود تا جنین در وضعیت بهتری قرار گیرد.</p>
<h4>۴. آیا می‌توانم همراهم (همسر یا مادر) در اتاق باشد؟</h4>
<p>بله، در اکثر موارد حضور یک همراه مجاز است و حتی می‌توانند تصاویر قلب جنین را مشاهده کنند. این تجربه می‌تواند برای خانواده آرامش‌بخش باشد.</p>
<h4>۵. چه مدت طول می‌کشد تا جواب آزمایش آماده شود؟</h4>
<p>نتایج اولیه بلافاصله پس از اتمام آزمایش به شما داده می‌شود. گزارش کامل و مکتوب معمولاً در همان روز یا حداکثر تا ۲۴-۴۸ ساعت بعد آماده می‌شود.</p>
<h4>۶. اگر ناهنجاری تشخیص داده شود، چه اقداماتی انجام می‌شود؟</h4>
<p>در این صورت، شما به تیم متخصصین شامل فلوشیپ قلب کودکان، متخصص زنان و زایمان، و در صورت نیاز جراح قلب کودکان ارجاع داده می‌شوید. برنامه‌ریزی دقیقی برای مراقبت‌های دوران بارداری، زمان و مکان زایمان، و درمان پس از تولد انجام خواهد شد.</p>
<h2>جمع‌بندی نهایی</h2>
<p>اکوکاردیوگرافی قلب جنین، پنجره‌ای به سوی اطمینان از سلامت قلب کوچک‌ترین عضو خانواده شماست. این روش ایمن و دقیق، به شما و تیم پزشکی‌تان این امکان را می‌دهد که با آگاهی کامل، بهترین مراقبت‌ها را برای جنین برنامه‌ریزی کنید.</p>
<p>در همراه کلینیک ما با بهره‌گیری از پیشرفته‌ترین تجهیزات تصویربرداری و تیم متخصصین مجرب، متعهد هستیم که با دقت و همدلی، سلامت قلب جنین شما را ارزیابی کنیم. به‌یاد داشته باشید که تشخیص به‌موقع، کلید مدیریت موفق هرگونه ناهنجاری قلبی است.</p>
<h3>برای اطمینان از سلامت قلب جنین، همین حالا اقدام کنید و با <a href="/service/کلینیک-قلب-کودکان/">کلینیک قلب کودکان</a> تماس حاصل فرمایید</h3>
<p>
<a>📞 ۰۲۱۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر محبوبه خلیلی
</p>
<ul>
<li>
متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی
</li>
<li>
فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر محبوبه خلیلی سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر محبوبه خلیلی یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-محبوبه-خلیلی/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر احمد مافی
</p>
<ul>
<li>
متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی
</li>
<li>
دانشیار دانشگاه علوم پزشکی شهید بهشتی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر احمد مافی سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر احمد مافی یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>رزومه پزشک</h3>
<h3>تحصیلات پزشکی</h3>
<p>
<strong>بورد تخصصی رادیوتراپی انکولوژی:</strong> دانشگاه علوم پزشکی شهید بهشتی، شهریور 1391<br>
<strong>پزشکی عمومی:</strong> دانشگاه علوم پزشکی ایران 1378</p>
<h3>بورد تخصصی</h3>
<p>رتبه سوم امتحان کشوری بورد تخصصی، شهریور 1391</p>
<h3>دستیار تخصصی برتر</h3>
<p>دستیار تخصصی برتر دانشگاه علوم پزشکی شهید بهشتی، 1390</p>
<h3>سایر مدارک تحصیلی</h3>
<p>MSc بیولوژی سلولی ملکولی: دانشگاه لندن، انگلستان، سال 2004</p>
<h3>طبابت در کشور انگلستان</h3>
<p>1382 لغایت 1386</p>
<h3>طبابت به عنوان متخصص رادیوتراپی انکولوژی</h3>
<p>
<strong>از 1392 تاکنون:</strong> دانشگاه علوم پزشکی شهید بهشتی، بیمارستان امام حسین (ع).<br>
<strong>آبان 1391 لغایت مهر:</strong> 1392 بیمارستان امام خمینی کهگیلویه</p>
<h3>ثبت اختراع</h3>
<p>فرموالسیون یک چسب مخاطی جدید حاوی ویتامین E به منظور التیام درد و سوزش موکوزیت ناشی از رادیوتراپی و شیمی درمانی، فروردین 1391</p>
<h3>تألیف کتابهای پزشکی به زبان انگلیسی</h3>
<p>
<strong>1. Advances in Experimental Medicine and Biology</strong>
<br>
The Potential Role of Intestinal Stem Cells and Microbiota for the Treatment of Colorectal<br>
Cancer. 30 May 2024<br>
<strong>2. Advances in Experimental Medicine and Biology</strong>
<br>
Chapter: DNA Damage Responses, the Trump Card of Stem Cells in the Survival Game.<br>
2023<br>
<strong>3. Methods in Molecular Biology</strong>
<br>
Chapter: Neuromuscular Junction-on-a-Chip for Amyotrophic Lateral Sclerosis Modeling.<br>
<strong>4. Methods in Molecular Biology</strong>
<br>
Chapter: Standard Operating Procedure for Production of Mouse Brown Adipose TissueDerived Mesenchymal Stem Cells. 2023<br>
<strong>5. Cell Biology and Translational Medicine. Volume 18</strong>
<br>
Chapter: Application of Biocompatible Scaffolds in Stem-Cell-Based Dental Tissue<br>
Engineering. Springer, 2023.<br>
<strong>6. Oxford Handbook of Clinical Medicine</strong>
<br>
8th edition, Oxford University Press, UK, 2010<br>
<strong>7. Oxford Handbook of Clinical Specialties</strong>
<br>
8th edition, Oxford University Press, UK, 2009</p>
<p>اولین غیر انگلیسی که به عنوان نویسنده اصلی در تألیف دو کتاب رفرانس معتبر پزشکی به زبان انگلیسی با دانشگاه آکسفورد انگلستان همکاری داشته است.</p>
<h3>ویراستاری علمی کتاب پزشکی به زبان انگلیسی</h3>
<p>
<strong>1. Oxford Handbook of Clinical Medicine</strong>
<br>
9th edition, Oxford University Press, UK, 2014<br>
<strong>2. Oxford Handbook of Clinical Specialties</strong>
<br>
9th edition, Oxford University Press, UK, 2013<br>
<strong>3. Oxford Handbook of Clinical Medicine</strong>
<br>
7th edition, Oxford University Press, UK, 2007<br>
<strong>4. Oxford Handbook of Clinical Specialties</strong>
<br>
7th edition, Oxford University Press, UK, 2005<br>
<strong>5. Oxford Handbook of Clinical Medicine</strong>
<br>
6th edition, Oxford University Press, UK, 2004</p>
<h3>عضویت ها</h3>
<ol>
<li>عضو کمیته مشورتی تشخیص و درمان سرطان وزارت بهداشت، درمان و آموزش پزشکی — اردیبهشت 1404 تاکنون</li>
<li>عضو کمیته پاتولوژی بیماری‌های توراکس انجمن علمی آسیب‌شناسی ایران — اسفند 1403 تاکنون</li>
<li>عضو اتاق فکر رشته تخصصی رادیوانکولوژی در سازمان نظام پزشکی تهران بزرگ — دی 1400 تاکنون</li>
<li>عضو کارگروه کشوری QUATRO برای بهبود کیفیت خدمات رادیوتراپی در کشور — مهر 1400 تاکنون</li>
<li>Quality Assurance Team for Radiation Oncology</li>
<li>هیات مدیره انجمن رادیوتراپی انکولوژی ایران — تیرماه 1400 تا بهمن 1403</li>
<li>عضو واحد توسعه پژوهش‌های بالینی بیمارستان امام حسین(ع) — 1399 تاکنون</li>
<li>نظام پزشکی جمهوری اسلامی ایران — 1378 تاکنون</li>
<li>نظام پزشکی انگلستان (GMC) — 2004 تاکنون</li>
<li>کارگروه استانداردسازی کشوری درمان‌های انکولوژی: وزارت بهداشت، درمان و آموزش پزشکی — 1396 تاکنون</li>
<li>جامعه اروپایی مدیکال انکولوژی (ESMO) — 2015 تاکنون</li>
<li>کمیته برنامه‌ریزی درسی و بین‌رشته‌ای و EDO دانشگاه علوم پزشکی شهید بهشتی — 1393 تا 1402</li>
<li>عضو پیوسته انجمن سرطان ایران — 1388 تاکنون</li>
<li>عضو پیوسته انجمن رادیوتراپی انکولوژی ایران — 1388 تاکنون</li>
</ol>
<h3>مسئولیت ها</h3>
<ol>
<li>منتور دستیاران رادیوانکولوژی بیمارستان امام حسین — شهریور 1401 تاکنون</li>
<li>مسئول اتاق فکر رشته تخصصی رادیوانکولوژی در سازمان نظام پزشکی تهران بزرگ — دی 1400 تاکنون</li>
<li>مسئول کمیته استاندارد و کیفیت انجمن رادیوتراپی انکولوژی ایران — آبان 1400 تاکنون</li>
<li>عضو کمیته ارزیابی درونی دانشکده پزشکی — تیر 1400 تاکنون</li>
<li>عضو هیأت مدیره انجمن رادیوتراپی انکولوژی ایران — خرداد 1400 تا بهمن 1403</li>
<li>مسئول امور بین‌الملل گروه رادیوانکولوژی — آذر 1397 تاکنون</li>
<li>مسئول کمیته برنامه‌ریزی درسی و بین‌رشته‌ای دانشگاه علوم پزشکی شهید بهشتی — تیر 1397 تا تیر 1401</li>
<li>مسئول آموزش دستیاری گروه رادیوانکولوژی — تیر 1396 تاکنون</li>
<li>مجری طرح استانداردسازی شرایط تجویز داروهای گران‌قیمت ضدسرطان — موسسه عالی پژوهش تأمین اجتماعی و وزارت بهداشت — 1395</li>
<li>عضو هیأت ممتحنه و طراح سؤالات بانک آزمون صلاحیت بالینی — شورای آموزش پزشکی عمومی — اردیبهشت 1397</li>
<li>معاون آموزشی بخش رادیوتراپی انکولوژی بیمارستان امام حسین — مرداد 1397 تاکنون</li>
<li>مسئول فنی بخش رادیوتراپی انکولوژی بیمارستان امام حسین — تیر 1397 تاکنون</li>
<li>نماینده دبیرخانه شورای آموزش پزشکی عمومی وزارت بهداشت برای نظارت بر هفتمین دوره آزمون ارزیابی صلاحیت بالینی — دانشگاه علوم پزشکی بابل — مرداد 1396</li>
<li>نماینده دبیرخانه شورای آموزش پزشکی عمومی وزارت بهداشت برای نظارت بر پنجمین دوره آزمون ارزیابی صلاحیت بالینی — دانشگاه علوم پزشکی یزد — بهمن 1395</li>
<li>مسئول الگ‌بوک گروه آموزشی رادیوتراپی انکولوژی دانشگاه علوم پزشکی شهید بهشتی — دی 1396 تا اسفند 1399</li>
<li>عضو کمیته بومی‌سازی گایدلاین سرطان معده انجمن رادیوتراپی انکولوژی ایران — آبان 1393 تا دی 1395</li>
<li>عضو کمیته روابط بین‌الملل انجمن رادیوتراپی انکولوژی ایران — آبان 1393 تاکنون</li>
<li>مسئول سابق برنامه‌ریزی آموزشی کمیته پژوهش و برنامه‌ریزی شورای بیماری‌های خاص صدا و سیما</li>
<li>دبیر سابق هیأت تحریریه فصلنامه دانستنی‌های سرطان</li>
</ol>
<h3>تألیف و ترجمه کتاب</h3>
<ol>
<li>سرطان به زبان ساده؛ جلد اول: سرطان سر و گردن — انتشارات ارجمند — اسفند 1403</li>
<li>شیوه‌نامه تدوین راهنمای مطالعه (Guide Study) — انتشارات دانشگاه علوم پزشکی شهید بهشتی — 1398</li>
<li>Beauty of Land, Iran — کتاب انگلیسی شامل تاریخچه مختصر انکولوژی در ایران و زیبایی‌های ایران — انجمن رادیوتراپی انکولوژی ایران — خرداد 1396</li>
<li>اصول هیپرترمی در درمان سرطان — دانشگاه علوم پزشکی شهید بهشتی — 1394</li>
<li>دانستنی‌های ضروری دربارهٔ سرطان مثانه — نشر پژوهشگران — 1393</li>
<li>شیمی‌درمانی در شرایط بالینی خاص — انتشارات ارجمند — 1393</li>
<li>ترومبوآمبولی و سرطان — انتشارات ارجمند — 1393</li>
<li>پرستاری برونر و سودارث: درد، الکترولیت، شوک، سرطان و مراقبت‌های پایان عمر — نشر حیدری — 1393</li>
<li>شیمی‌درمانی؛ جلد اول از مجموعهٔ «سرطان به زبان ساده» — انتشارات ارجمند — 1389</li>
</ol>
<h3>پایان نامه ها و طرح های تحقیقاتی</h3>
<ol>
<li>بررسی میزان تأثیر رادیوتراپی گردن بر بروز آترواسکلروز شریان کاروتید</li>
<li>بررسی موارد مؤثر بر بروز نوروپاتی در بیماران دچار سرطان پستان که با رژیم هفتگی Paclitaxel درمان می‌شوند</li>
<li>بررسی فراوانی سارکوپنی و ارتباط آن با بقای عاری از عود دوساله بیماران مبتلا به کانسر رکتوم پیشرفته درمان‌شده در بخش رادیوانکولوژی بیمارستان امام حسین(ع)</li>
<li>بررسی نقش پروگنوستیک نسبت نوتروفیل به لنفوسیت در بیماران دچار سرطان معده غیرمتاستاتیک</li>
<li>مقایسه میزان پاسخ پاتولوژیک به شیوه جدید درمان نئوادجوانت (Total Neoadjuvant Therapy) در بیماران مبتلا به کانسر رکتوم و مقایسه با داده‌های قبلی مرکز — در حال انجام</li>
<li>خصوصیات پاتوفیزیولوژیک، بالینی و بقای بیماران مبتلا به تومورهای مغزی–نخاعی درمان‌شده در بخش رادیوتراپی انکولوژی بیمارستان امام حسین(ع) از 1387 تا 1397 — بررسی 890 پرونده (در حال انجام)</li>
<li>خصوصیات پاتوفیزیولوژیک، بالینی و بقای بیماران مبتلا به آدنوکارسینوم کولون درمان‌شده در بخش رادیوتراپی انکولوژی بیمارستان امام حسین(ع) از 1387 تا 1397 — بررسی 940 پرونده (در حال انجام)</li>
<li>خصوصیات پاتوفیزیولوژیک، بالینی و بقای بیماران مبتلا به آدنوکارسینوم رکتوم درمان‌شده در بخش رادیوتراپی انکولوژی بیمارستان امام حسین(ع) از 1387 تا 1397 — بررسی 730 پرونده (در حال انجام)</li>
<li>بررسی اثرات سارکوپنی بر بقای عاری از عود دو و سه‌ساله بیماران مبتلا به سرطان سرویکس که با کمورادیوتراپی درمان شده‌اند</li>
<li>بررسی اثرات سارکوپنی بر بقای عاری از عود بیماران مبتلا به سرطان پروستات تحت درمان رادیوتراپی</li>
<li>بررسی میزان دوز دریافتی و ریسک بروز سرطان ثانویه در ارگان‌های تحت تابش پرتو به دنبال رادیوتراپی در بیماران مبتلا به سرطان پستان مراجعه‌کننده به بیمارستان امام حسین(ع) — سال 1399</li>
<li>بررسی میزان دوز دریافتی و ریسک بروز سرطان ثانویه در ارگان‌های تحت تابش پرتو به دنبال رادیوتراپی در بیماران مبتلا به سرطان پستان</li>
<li>مقایسه تأثیر کرم درمولین هانا با کرم XRT Strata بر بهبود درماتیت ناشی از رادیوتراپی در بیماران مبتلا به سرطان پستان</li>
<li>بررسی شدت ابتلا به بیماری COVID-19 در بیماران مبتلا به کانسر پستان غیرمتاستاتیک تحت درمان در بیمارستان امام حسین(ع)</li>
<li>بررسی مطالعات حوزه تشخیص، مدیریت و درمان بیماران مبتلا به سرطان پروستات در دوران پاندمی کووید-19</li>
<li>ارزیابی وقوع اختلال تحت‌بالینی عملکرد میوکارد بطن راست با اکوکاردیوگرافی دوبعدی پس از شیمی‌درمانی با 5-فلورواوراسیل</li>
<li>بررسی ارتباط miRNA، سطح خونی تروپونین و یافته‌های اکوکاردیوگرافیک به عنوان فاکتورهای پروگنوستیک کاردیوتوکسیسیته ناشی از کموتراپی در بیماران مبتلا به کانسر پستان</li>
</ol>
<h3>تدوین گایدالین های کشوری</h3>
<p>
<strong>گایدلاین رادیوتراپی (ابالغ شده توسط وزارت بهداشت، درمان و آموزش پزشکی)</strong>
</p>
<ol>
<li>دستورالعمل کشوری انجام رادیوتراپی در شرایط اپیدمی بیماری -19Covid</li>
</ol>
<p>
<strong>گایدلاین دارویی (ابالغ شده توسط وزارت بهداشت، درمان و آموزش پزشکی)</strong>
</p>
<ol>
<li>دستورالعمل کشوری تجویز داروی ستوکسیماب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی ارلوتینیب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی تراستوزوماب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی بواسیزوماب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی سانیتینیب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی دوکسوروبیسین لیپوزومال در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی تموزوالمید در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی ریتوکسیماب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی پمترکسد در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی ایماتینیب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی اورولیموس در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی بورتزومیب در بیماران سرطانی</li>
<li>دستورالعمل کشوری تجویز داروی سورافنیب در بیماران سرطانی</li>
</ol>
<p>
<strong>گایدالین دارویی (ابالغ شده توسط سازمان تامین اجتماعی)</strong>
</p>
<ol>
<li>راهنمای تجویز داروی ستوکسیماب در سرطانها</li>
</ol>
<p>
<strong>راهنما های بالینی کشوری (ابالغ شده توسط وزارت بهداشت، درمان و آموزش پزشکی) </strong>
</p>
<ol>
<li>راهنمای بالینی کشوری درمان سرطان پستان</li>
<li>راهنمای بالینی کشوری درمان سرطان پروستات</li>
<li>راهنمای بالینی کشوری درمان سرطان معده</li>
<li>راهنمای بالینی کشوری درمان سرطان ریه</li>
<li>راهنمای بالینی کشوری درمان سرطان کولورکتال</li>
</ol>
<h3>مقالات</h3>
<p>1. Analysis of Radiation Dose and Estimation of Secondary Cancer Incidence in Organs<br>
Exposed to Radiotherapy in Breast Cancer. Int J Cancer Manag. 2025;18(1):e161806.<br>
2. ERCPMP: an endoscopic image and video dataset for colorectal polyps morphology<br>
and pathology. BMC Res Notes 17, 393 (2024)<br>
3. Effects of Neck Radiation Therapy on Carotid Arteries in Patients with Head and<br>
Neck Carcinoma. GMJ.2024;13:e3363<br>
4. Safety evaluation of the trastuzumab biosimilar in Iranian women with HER2-<br>
positive breast cancer undergoing adjuvant chemotherapy: a post-marketing<br>
surveillance. Expert Opinion on Drug Safety, 2024; 1–6.<br>
5. The Potential Role of Intestinal Stem Cells and Microbiota for the Treatment of<br>
Colorectal Cancer. Adv Exp Med Biol. 2024 May 30.<br>
6. Extracellular vesicles and cancer stem cells: a deadly duo in tumor progression.<br>
Oncology Reviews. 2024, 18:1411736.<br>
7. The investigation of the frequency of COVID-19 in patients with a history of stroke.<br>
Journal of Family Medicine and Primary Care 13(5):p 2078-2084, May 2024.<br>
8. Neuromuscular Junction-on-a-Chip for Amyotrophic Lateral Sclerosis Modeling.<br>
Methods Mol Biol. 2024:2736:139-150.<br>
9. Standard Operating Procedure for Production of Mouse Brown Adipose TissueDerived Mesenchymal Stem Cells. Methods Mol Biol. 2024:2736:115-125.<br>
10. Temporal patterns of cancer burden in Asia, 1990-2019: a systematic examination<br>
for the Global Burden of Disease 2019 study. The Lancet Regional Health &#8211; Southeast<br>
Asia 2024;21: 100333.<br>
11. DNA Damage Responses, the Trump Card of Stem Cells in the Survival Game. Adv<br>
Exp Med Biol. 2023 Nov 4.<br>
12. The Global, Regional, and National Burden of Adult Lip, Oral, and Pharyngeal Cancer<br>
in 204 Countries and Territories: A Systematic Analysis for the Global Burden of<br>
Disease Study 2019. JAMA Oncol. 2023 Oct; 9(10): 1401–1416.<br>
13. Burden of breast cancer and attributable risk factors in the North Africa and Middle<br>
East region, 1990-2019: a systematic analysis for the Global Burden of Disease Study<br>
2019. Front Oncol. 2023 Aug 1;13:1132816<br>
14. Burden of tracheal, bronchus, and lung cancer in North Africa and Middle East<br>
countries, 1990 to 2019: Results from the GBD study 2019. Front. Oncol. 2023 Feb<br>
10;12:1098218.<br>
15. Systematic Evaluation of Studies in the Fields of Diagnosis and Management of<br>
Prostate Cancer in Coronavirus Disease 2019 Era. Int J Cancer Manag. Jan 2023.<br>
16. Critical roles of cytokine storm and bacterial infection in patients with COVID‑19:<br>
therapeutic potential of mesenchymal stem cells. Inflammopharmacology. Jan 2023<br>
17. The Impact of COVID-19 on Breast Cancer Recurrence: A Brief Review. Iranian<br>
Journal of Breast Diseases 2023; 15(4): 129-140. (In Persian)<br>
18. Evaluation of lymph node adequacy in patients with colorectal cancer: Results from<br>
a referral center in Iran. Forum of Clinical Oncology. 25 Dec 2022.<br>
19. Standard Operating Procedure for Production of Mouse Brown Adipose TissueDerived Mesenchymal Stem Cells. Methods in Molecular Biology. 2022 Dec 15<br>
20. Anatomical Distribution of Colon Cancer: A Retrospective 10-year Study to Evaluate<br>
Rightward Shift in Two Referral Hospitals in Iran. Int J Cancer Manag. 14 Dec 2022<br>
21. Brown adipose tissue and Alzheimer’s disease. Metabolic Brain Disease. 2022.<br>
22. The burden of prostate cancer in North Africa and Middle East, 1990–2019: Findings<br>
from the global burden of disease study. Front. Oncol. 2022; 12:961086.<br>
23. The Impact of COVID-19 on Cancer Recurrence: A Narrative Review. Arch Iran Med.<br>
July 2022;25(7):450-455<br>
24. Radiation Therapy for Breast Cancer During the COVID-19 Pandemic in Low Resource<br>
Countries: Consensus Statement from the Iranian Society of Radiation Oncology. Int<br>
J Cancer Manag. 2022;15(1):e116209.<br>
25. Refractive error and visual acuity changes following systemic chemotherapy. Current<br>
Research in Medical Sciences. 2022; Vol. (5.3): pages. 7-15<br>
26. Application of Biocompatible Scaffolds in Stem-Cell-Based Dental Tissue Engineering.<br>
Adv Exp Med Biol. 2022 Aug 25.<br>
27. The global burden of cancer attributable to risk factors, 2010–19: a systematic<br>
analysis for the Global Burden of Disease Study 2019. Lancet. 2022 Aug<br>
20;400(10352):563-591.<br>
28. Routine COVID-19 testing may not be necessary for most cancer patients.<br>
Sci Rep 11, 23294 (2021).<br>
29. Primary Extraosseous Ewing Sarcoma of the Upper Limb: Report of a Rare Case. Int J<br>
Cancer Manag. 2021 September; 14(9):e113387.<br>
30. Triplet Aprepitant/ Dexamethasone/Ondansetron versus Doublet Dexamethasone/<br>
Ondansetron for Prevention of Moderately Emetogenic Chemotherapy: A PlaceboControlled, Double-Blind, Randomized Clinical Trial of Efficacy. Eur J Clin Pharm.<br>
Volume 23 &#8211; Issue 2, April-June 2021<br>
31. Evaluation of Given Dose Accuracy in Radiation Therapy of Patients with Breast<br>
Cancer Using Diode In-vivo Dosimetry. Int J Cancer Manag. 2021 June;<br>
14(6):e109634.<br>
32. Evaluation of Clinical and Pathological Characteristics and Routine Treatment of<br>
Patients with Prostate Cancer in Six Referral Centers in Iran: A Pilot Noninterventional, Multicenter Study. Rep Radiother Oncol (2021).7(1):e113053.<br>
33. Huge Cutaneous Metastases from Gastric Adenocarcinoma: Report of a Rare Case.<br>
Rep Radiother Oncol. 2020 ; 7(1):e102273. doi: 10.5812/rro.102273.<br>
34. Estrogen Receptor Expression in Glial Tumors of Iranian Patients: A Single Center<br>
Experience. Iran J Pathol. 2020; 15(1): 08-12.<br>
35. The Incidence of Deep Vein Thrombosis in Breast Cancer Patients Receiving<br>
Outpatient Cancer Therapy in Iran. Tanaffos 2019; 18(3): 244-253.<br>
36. Lymphovascular and Perineural Invasions are Independently Associated with<br>
Advanced Colorectal Carcinoma. Int J Cancer Manag. 2019; Vol.12, issue 11; e95540.<br>
37. The Accuracy of Sentinel Lymph Node Biopsy Following Neoadjuvant Chemotherapy<br>
in Clinically Node Positive Breast Cancer Patients: A Single Institution Experience. Int<br>
J Cancer Manag. 2018 ; 11(12):e83946.<br>
38. Use of Dietary Supplements in Cancer: A Single-Institution Study. Rep Radiother<br>
Oncol. 2018 ; 5(1):e79566.<br>
39. Opium Consumption: A potential risk factor of for Lung Cancer and Pulmonary<br>
Tuberculosis. Indian J Cancer. 2016 Oct-Dec;53(4):587-589.<br>
40. Effect of Processed Honey and Royal Jelly on Cancer-Related Fatigue: A Double-Blind<br>
Randomized Clinical Trial. Electron Physician. 2016 Jun 25;8(6):2475-82.<br>
41. Efficacy of Topical and Systemic Vitamin E in Preventing Chemotherapy-Induced Oral<br>
Mucositis. Reports of Radiotherapy and Oncology: 1 2015, 2(1)<br>
42. Predictors of Biochemical Failure Following Radical Prostatectomy with Positive<br>
Surgical Margins. Reports of Radiotherapy and Oncology: June 2015, 2(2); e1410.<br>
Published Online: June 12, 2015<br>
43. Complete Radiologic Response in Metastatic Castration-Resistant Prostate Cancer<br>
Treated with Cabazitaxel. Iran J Med Sci. May 2015; Vol 40 No 3<br>
44. Efficacy of benzydamine oral rinse in prevention and management of radiationinduced oral mucositis: A double-blind placebo-controlled randomized clinical trial.<br>
Asia Pac J Clin Oncol. 2015;11(1):22-7.<br>
45. The Validation study of Adjuvant Online using Iranian breast cancer data<br>
Reports of Radiotherapy and Oncology, 2013; vol 1, No 3, 97-102.<br>
46. Attitude of Cancer Patients toward Diagnosis Disclosure and their Preference for<br>
Clinical Decision-making: A National Survey. Arch Iran Med, 2014; 17(4): 232 – 240<br>
47. Formulation of a new phenytoin-containing mucoadhesive and evaluation of its<br>
healing effects on oral biopsy ulcers. Open Journal of Stomatology, 2014, 4, 5-9<br>
48. Advanced Primary Lymphoma of Oral Cavity: Report of a Case.<br>
Open Journal of Stomatology, 2014, 4, 109-114<br>
49. Oral ulcerations as the first manifestations of acute leukemia: A case report.<br>
Open Journal of Stomatology, 2014, 3, 507-509<br>
50. Risk Factors of Developing a Second Malignancy Following Treatment of a First<br>
Primary Breast Cancer. IJCP. Vol 6, Suppl., winter 2013<br>
51. Quality of life among veterans with war-related unilateral lower extremity<br>
amputation: a long-term survey in a prosthesis center in Iran.<br>
J Orthop Trauma. 2009 Aug;23(7):525-30.<br>
52. A very rare case of single coronary artery anomaly, with LAD and LCx arteries<br>
originating separately from proximal RCA. J Card Surg; 2008 Jan-Feb; 23(1):67-9<br>
53. Propensity score analysis of early and late outcome after redo off-pump and on- pump<br>
coronary artery bypass grafting. Eur J Cardiothorac Surg; 2008; 33(2):209-14</p>
<h3>همکاری با مجالت تخصصی به عنوان داور و reviewer</h3>
<p>1. McMaster Online Rating of Evidence (MORE). Canada. 2008 to date<br>
2. Reports in Radiotherapy &amp; Oncology. Iran.<br>
3. International Journal of medical and Pharmaceutical Case Reports<br>
4. Iranian Journal of Cancer Prevention<br>
5. Journal of Laser in Medical Sciences.</p>
<h3>سخنرانی در کنفرانسهای بین المللی (به زبان انگلیسی)</h3>
<p>1. Breast Cancer Care Through the Decades. Middle East and Africa (MEA) Breast<br>
Summit. 10 Oct 2025. Dubai.<br>
2. Lung Radiotherapy. AstraZeneca Bootcamp. 19 Aug 2025. Tehran. Iran<br>
3. Overview of Bladder Cancer. Merck Connect. May 2025. Istanbul. Türkiye.<br>
4. Colorectal Cancer Screening. Merck Connect. May 2025. Istanbul. Türkiye.<br>
5. Anti EGFRs are not the same.<br>
Merck’s 2nd Oncology Standalone Meeting (Forefront). May 2023, Dubai, UAE.<br>
6. Clinical Implications of Genetic Testing in Prostate Cancer.<br>
HOPES 11th Conference. Nov 2022, Istanbul, Turkey.<br>
7. The treatment landscape of locally advanced HNSCC.<br>
Merck advisory board. 26 May 2022<br>
8. Re-irradiation in prostate cancer recurrence (webinar).<br>
8th IUA+EAU Virtual Uro-Oncology Seminar. 3 Mar 2022.<br>
9. EGFR inhibitors re-challenge in metastatic colorectal cancer.<br>
Pursue the Sound of Hope (Merck), 27 Nov 2021, Dubai, UAE.<br>
10. Renal cell carcinoma panel (webinar).<br>
7th IUA+EAU Virtual Uro-Oncology Seminar. 26 Apr 2021.<br>
11. Target therapy in advanced RCC (webinar).<br>
7th IUA+EAU Virtual Uro-Oncology Seminar. 26 Apr 2021.<br>
12. Testicular cancer panel (webinar).<br>
Joint SIU-IUA Webinar Series: Uro-oncology Highlights. 26 Nov 2020.<br>
13. Bladder cancer panel (webinar).<br>
Joint SIU-IUA Webinar Series: Uro-oncology Highlights. 19 Nov 2020.<br>
14. Anti EGFRs are not the same.<br>
MERCK 4th Near East Masterclass. 1 Nov 2019, Doha, Qatar.<br>
15. Medical management of advanced prostate cancer.<br>
HOPES 8th Conference. Sep 2019, Beirut, Lebanon.<br>
16. Optimizing treatment with anti EGFRs. mCRC panel moderator.<br>
IMPACT V seminar. 28 Sep 2018, Kiev, Ukraine.<br>
17. Radionuclide therapy in prostate cancer.<br>
HOPES 6th Conference. 29 Sep 2017, Dubai, UAE.<br>
18. Borderline resectable pancreatic cancer.<br>
1st International Clinical Oncology Congress. Nov 2016, Tehran, Iran.<br>
19. Risk factors of premature coronary artery disease in Iranian population.<br>
18th Congress of “World Society of Cardiothoracic Surgery” (WSCTS). May 2008,<br>
Kos Island, Greece.</p>
<h3>پوسترهای ارائه شده در کنفرانسهای داخلی و بین المللی</h3>
<p>1. The Impact of COVID-19 on Cancer Recurrence.<br>
16th Annual Congress of Clinical Oncology, Tehran, Iran. 17 Feb 2022.<br>
2. The accuracy of sentinel lymph node biopsy following neoadjuvant chemotherapy in clinically node positive breast cancer patients: A single institution experience.<br>
ESMO 2018, Munich, Germany.<br>
Annals of Oncology (2018) 29 (suppl_8)<br>
3. The frequency of vitamin supplement usage in patients with cancer.<br>
12th Annual Congress of Clinical Oncology, Tehran, Iran. Dec 2017<br>
4. Effectiveness of Teasdale mindfulness -Based Cognitive Therapy training (MBCT) in<br>
reducing aggression and increasing self-esteem in women with breast cancer.<br>
9th Annual Congress of Clinical Oncology, Tehran, Iran. Oct 2014<br>
5. Efficacy of topical and systemic vitamin E in preventing chemotherapy-induced oral<br>
mucositis. 9th Annual Congress of Clinical Oncology, Tehran, Iran. Oct 2014<br>
6. GIST of tongue: Report of a very rare case.<br>
9th Annual Congress of Clinical Oncology, Tehran, Iran. Oct 2014</p>
<p>7. مالحظات دندانپزشکی در بیماران انکولوژی. چهارمین کنگره سراسری دندانپزشکی دانشگاه آزاد اسالمی. 10 مهر 1393<br>
8. بررسی پایانی نتایج پیش بینی شده توسط برنامه کامپیوتری ادجوانت آنالین در مقایسه با یافته های بیماران ایرانی مبتلا به سرطان کولون. هشتمین کنگره سالیانه کلینیکال انکولوژی. اصفهان. 26 دی 1392</p>
<p>9. Risk factors of developing a second primary cancer after treatment of a first primary<br>
breast cancer. 8th Annual Congress of Clinical Oncology, Tehran, Iran. Jan 2013</p>
<h3>سخنرانی در کنگرههای انکولوژی</h3>
<ol>
<li>سرطان پستان سه‌گانه منفی – سمینار ایمونوانکولوژی – مشهد – ۶ آذر ۱۴۰۴</li>
<li>تدریس در کارگاه کانتورینگ سرطان‌های غدد بزاقی – انجمن رادیوانکولوژی ایران – ۸ آبان ۱۴۰۴</li>
<li>درمان سرطان پستان در گذر زمان – کنفرانس سرطان پستان خاورمیانه و آفریقا – دبی – ۱۸ مهر ۱۴۰۴</li>
<li>کنفرانس سرطان تیموس – انجمن علمی آسیب‌شناسی ایران – بیمارستان مسیح دانشوری – ۱۹ مهر ۱۴۰۴</li>
<li>هفتمین کنگره سالیانه یوروانکولوژی – پنل سرطان پنیس – هتل اسپیناس پالاس – ۱۹ شهریور ۱۴۰۴</li>
<li>رادیوتراپی ریه – Bootcamp AstraZeneca – وبینار – ۲۷ مرداد ۱۴۰۴</li>
<li>سمینار یوروانکولوژی – سرطان مثانه الیگومتاستاتیک – انجمن رادیوانکولوژی ایران – هتل اوین – ۱۶ مرداد ۱۴۰۴</li>
<li>اصول درمان سرطان مثانه – سمینار Connect Merck – استانبول – ترکیه – ۲۷ اردیبهشت ۱۴۰۴</li>
<li>غربالگری سرطان کولورکتال – سمینار Connect Merck – استانبول – ترکیه – ۲۷ اردیبهشت ۱۴۰۴</li>
<li>بیست‌وهشتمین کنگره جامعه اورولوژی ایران – پنل سرطان مثانه muscle-non invasive – دانشگاه علوم پزشکی شهید بهشتی – ۲۴ اردیبهشت ۱۴۰۴</li>
<li>چهل‌وششمین کنگره سالانه جامعه جراحان ایران – پنل سرطان پستان تریپل نگاتیو – سالن همایش‌های رازی – ۱۹ اردیبهشت ۱۴۰۴</li>
<li>دهمین کنگره مشترک قلب و عروق ایران – پنل کاردیوانکولوژی: عوارض قلبی در سرطان پروستات – هتل قلب تهران – ۱۱ اردیبهشت ۱۴۰۴</li>
<li>Board Tumor Multi-Disciplinary Team – سرطان ریه – شرکت AstraZeneca – هتل پارسیان آزادی – ۲ اسفند ۱۴۰۳</li>
<li>نهمین سمینار جامع انکولوژی استان گیلان – پنل سرطان پستان – ۳۰ بهمن ۱۴۰۳</li>
<li>نهمین کنگره بین‌المللی کلینیکال انکولوژی – پنل انجمن اروپایی مدیکال انکولوژی (ESMO) – هتل المپیک – ۱۰ بهمن ۱۴۰۳</li>
<li>کارگاه علمی کانتورینگ سرطان حنجره – مدرس کارگاه – اصفهان</li>
<li>بیست‌وسومین کنگره سراسری انجمن هماتولوژی انکولوژی ایران – پنل سرطان ریه – بیمارستان قلب شهید رجایی – ۳ آبان ۱۴۰۳</li>
<li>سی‌ویکمین کنگره سالیانه انستیتو کانسر – پنل سرطان رکتوم – بیمارستان امام خمینی – ۲۶ مهر ۱۴۰۳</li>
<li>سومین سمینار سالیانه تازه‌های سرطان ریه – درمان هدفمند مولکولی در سرطان ریه – هتل استقلال – ۱۲ مرداد ۱۴۰۳</li>
<li>چهل‌وپنجمین کنگره سالانه جامعه جراحان ایران – پنل سرطان مثانه – سالن همایش‌های رازی – ۲۰ اردیبهشت ۱۴۰۳</li>
<li>نهمین کنگره مشترک قلب و عروق ایران – رادیوتراپی در سارکوم‌های قلبی – بیمارستان قلب شهید رجایی – ۵ اردیبهشت ۱۴۰۳</li>
<li>هفدهمین کنگره بین‌المللی سرطان پستان – سرطان پستان هورمون مثبت – بیمارستان شهدای تجریش – ۹ اسفند ۱۴۰۲</li>
<li>تومور بورد سرطان رکتوم – گرداننده پنل – بیمارستان امام حسین (ع) – ۷ اسفند ۱۴۰۲</li>
<li>جلسه ماهیانه جامعه ارولوژی ایران – تومور بورد سرطان‌های دستگاه ادراری – بیمارستان امام خمینی (ره) – ۳ اسفند ۱۴۰۲</li>
<li>نشست تخصصی نقش ابیراترون در درمان سرطان پروستات – شرکت داروسازی عبیدی</li>
<li>سمینار کاردیوانکولوژی – سمیت قلبی ناشی از رادیوتراپی پستان – گرند هتل شیراز – ۲۱ دی ۱۴۰۲</li>
<li>یازدهمین کنگره بین‌المللی انجمن علمی سرطان‌های زنان ایران – تازه‌های درمان سارکوم رحمی – دانشگاه شهید بهشتی – ۱۰ آبان ۱۴۰۲</li>
<li>سمینار جامعه ارولوژی ایران – پنل سرطان‌های ارولوژی – بیمارستان امام خمینی – ۴ آبان ۱۴۰۲</li>
<li>هجدهمین کنگره سالیانه جراحی سر و گردن – تازه‌های درمان سرطان اوروفارنکس HPV+ – هتل اسپیناس – ۳ آبان ۱۴۰۲</li>
<li>تشخیص و درمان سرطان‌های ژنیکولوژی – نقش PARP inhibitors در درمان سرطان تخمدان – بیمارستان جم – ۲۰ مهر ۱۴۰۲</li>
<li>هفتمین سمینار جامع انکولوژی استان گیلان – پنل سرطان رکتوم متاستاتیک – رشت – ۱۲ مهر ۱۴۰۲</li>
<li>پنجمین کنگره سالیانه سرطان‌های دستگاه ادراری – پنل سرطان پنیس – هتل اسپیناس – ۱۶ شهریور ۱۴۰۲</li>
<li>هشتمین کنگره بین‌المللی قلب و عروق – پنل کاردیوانکولوژی – بیمارستان قلب شهید رجایی – ۲۴ خرداد ۱۴۰۲</li>
<li>چهل‌وچهارمین کنگره سالانه جامعه جراحان ایران – پانل چالش‌های تشخیص و درمان سرطان ریه – ۲۵ اردیبهشت ۱۴۰۲</li>
<li>کنگره بین‌المللی سرطان – پنل سرطان معده – دانشگاه علوم پزشکی شهید بهشتی – ۱۳ اردیبهشت ۱۴۰۲</li>
<li>شانزدهمین کنگره بین‌المللی سرطان پستان – پنل بیماران هورمون‌مثبت با درگیری ۱–۳ غدد لنفاوی – ۱۰ اسفند ۱۴۰۱</li>
<li>سمینار طب فراگیر و کیفیت زندگی بیماران مبتلا به سرطان – دانشگاه علوم پزشکی تهران – ۲۴ آذر ۱۴۰۱</li>
<li>سمینار HOPE11 – تست‌های ژنتیک در سرطان پروستات – استانبول – ترکیه – ۵ آذر ۱۴۰۱</li>
<li>چهارمین کنگره سالیانه مرکز تحقیقات یوروانکولوژی – نقش جراحی cytoreductive در RCC متاستاتیک – هتل اسپیناس پالاس – ۱۵ مهر ۱۴۰۱</li>
<li>سمینار تومورهای اندوکرین – عضو پنل – مجموعه کارمان – همافارمد – ۲۴ شهریور ۱۴۰۱</li>
<li>کنفرانس علمی سرطان رکتوم – پنل سرطان رکتوم موضعی – هتل اوین – ۱۰ شهریور ۱۴۰۱</li>
<li>کنفرانس علمی سرطان رکتوم – پنل سرطان رکتوم متاستاتیک – هتل اوین – ۱۰ شهریور ۱۴۰۱</li>
<li>جشنواره سازمان نظام پزشکی – پنل سرطان معده – مرکز همایش‌های رازی – ۲۷ مرداد ۱۴۰۱</li>
<li>تازه‌های سرطان دستگاه گوارش – پنل سرطان کولورکتال – هتل اوین – ۳۰ تیر ۱۴۰۱</li>
<li>جلسه board advisory سرطان‌های سر و گردن – با حضور پروفسور پائولو بوسی – شرکت Merck – ۵ خرداد ۱۴۰۱</li>
<li>وبینار مروری بر مقالات مهم انکولوژی – ۲۳ اردیبهشت ۱۴۰۱</li>
<li>هجدهمین توموربورد ارولوژی دانشگاه شهید بهشتی – بیمارستان لبافی‌نژاد – ۱۵ اردیبهشت ۱۴۰۱</li>
<li>پیشگیری، تشخیص و درمان سرطان‌های سر و گردن – انجمن سرطان ایران – ۹ اردیبهشت ۱۴۰۱</li>
<li>ششمین سمینار جامع انکولوژی گیلان – درمان سرطان غیرسمینومی بیضه – ۳۰ فروردین ۱۴۰۱</li>
<li>هفدهمین توموربورد ارولوژی دانشگاه شهید بهشتی – بیمارستان لبافی‌نژاد – ۱۸ فروردین ۱۴۰۱</li>
<li>وبینار انجمن ارولوژی ایران و EAU – رادیوتراپی مجدد در عود سرطان پروستات – ۱۲ اسفند ۱۴۰۰</li>
<li>وبینار یوروانکولوژی – نقش بیومارکرها در سرطان کلیه – ۱۲ اسفند ۱۴۰۰</li>
<li>پانزدهمین کنگره بین‌المللی سرطان پستان – پنل درمان آگزیال بعد از کموتراپی نئوادجوانت – ۵ اسفند ۱۴۰۰</li>
<li>ششمین کنگره بین‌المللی کلینیکال انکولوژی – Recent studies from San Antonio RT breast – هتل المپیک – ۲۸ بهمن ۱۴۰۰</li>
<li>شانزدهمین توموربورد ارولوژی دانشگاه شهید بهشتی – ۲۱ بهمن ۱۴۰۰</li>
<li>پانزدهمین توموربورد ارولوژی دانشگاه شهید بهشتی – ۳۰ دی ۱۴۰۰</li>
<li>کنگره سالانه سرطان پستان معتمد – رادیوتراپی پستان در دوران کرونا – ۲۴ دی ۱۴۰۰</li>
<li>وبینار بروز همزمان بدخیمی‌های سیستم ادراری تناسلی – درمان بیماران با چند سرطان همزمان – ۲۳ دی ۱۴۰۰</li>
<li>وبینار درمان سرطان‌های سر و گردن – ملاحظات دندانی رادیوتراپی – دانشگاه آزاد – ۲ دی ۱۴۰۰</li>
<li>سمینار یک‌روزه Bratiga Standalone – شرکت عبیدی – کیش – ۲۵ آذر ۱۴۰۰</li>
<li>وبینار تازههای درمان سرطان پستان. انجمن سرطان ایران شاخه اصفهان. 18 آذر 1400</li>
<li>گراندراند یوروانکولوژی. مرکز تحقیقات سرطان یوروانکولوژی دانشگاه تهران و گروه یوروانکولوژی دانشگاه شهید بهشتی. بیمارستان بهمن. 22 مهر 1400</li>
<li>وبینار نوروانکولوژی. تومورهای نخاعی. بیمارستان پیامبران. 2 مهر 1400</li>
<li>وبینار جامع انکولوژی گیلان. مروری بر درمان سرطان معده. 13 شهریور 1400</li>
<li>وبینار نقش اورولیموس در سرطان پستان متاستاتیک. سبحان انکولوژی. 3 شهریور 1400</li>
<li>وبینار کانسرهای متاستاتیک کولورکتال. درمان‌های نوین سرطان رکتوم متاستاتیک. انجمن رادیوتراپی انکولوژی ایران و بهستان دارو. 14 مرداد 1400</li>
<li>وبینار کانسر رکتوم. رادیوتراپی ادجوانت در کانسر رکتوم. انجمن رادیوتراپی انکولوژی ایران و پویش دارو. 4 تیر 1400</li>
<li>وبینار نقش داروی تموزولامید در انکولوژی. نانو الوند، ارکیدفارمد. بیمارستان امام حسین (ع). 2 تیر 1400</li>
<li>وبینار سرطان‌های سر و گردن. ایمونوتراپی همزمان با رادیوتراپی. مرکز تحقیقات سرطان بیمارستان میلاد. 20 خرداد 1400</li>
<li>وبینار چالش‌های درمانی سرطان‌های سر و گردن در دوران پاندمی کووید. رادیوتراپی سر و گردن در دوران کووید. انجمن رادیوتراپی انکولوژی ایران. 6 خرداد 1400</li>
<li>وبینار مشترک انجمن ارولوژی ایران و انجمن جهانی ارولوژی. پنل سرطان کلیه. 27 فروردین 1400</li>
<li>وبینار مشترک انجمن ارولوژی ایران و انجمن جهانی ارولوژی. تارگت تراپی در سرطان کلیه. 27 فروردین 1400</li>
<li>نشست علمی چند تخصصی تشخیص و درمان سرطان کولورکتال. پنل سرطان رکتوم. انجمن رادیوتراپی انکولوژی ایران. 14 اسفند 1399</li>
<li>وبینار درمان نئوادجوانت کانسر رکتوم. پویش دارو. 7 اسفند 1399</li>
<li>جلسه board Advisory نحوه درمان سرطان پستان HER2 مثبت با هماهنگی شرکت Roche. 1 اسفند 1399</li>
<li>وبینار برخورد با بیمار مبتلا به کانسر زبان. 30 بهمن 1399</li>
<li>وبینار سرطان پروستات متاستاتیک. شرکت عبیدی. ملاحظات درمان با داروی ابیراترون. 15 بهمن 1399</li>
<li>وبینار پنل تخصصی برخورد با بیمار مبتلا به کانسر زبان. 30 دی 1399</li>
<li>وبینار تازه‌های درمان HCC و RCC. 24 دی 1399</li>
<li>وبینار تازه‌های سرطان ریه بر اساس ASCO و ESMO سال 2020. 11 دی 1399</li>
<li>جلسه board Advisory نحوه تجویز داروهای خوراکی شیمی‌درمانی با هماهنگی شرکت پیرفابر. 28 آذر 1399</li>
<li>وبینار تازه‌های سرطان کولورکتال. انجمن رادیوتراپی انکولوژی ایران. سرطان‌های ارثی کولورکتال. 20 آذر 1399</li>
<li>وبینار مشترک انجمن ارولوژی ایران و انجمن جهانی ارولوژی. پنل سرطان بیضه. 6 آذر 1399</li>
<li>وبینار مشترک انجمن ارولوژی ایران و انجمن جهانی ارولوژی. پنل سرطان مثانه. 29 آبان 1399</li>
<li>سرطان‌های ادراری تناسلی &#8211; سرطان پروستات پیشرفته و متاستاتیک، تشخیص تا درمان. رادیوتراپی در سرطان پروستات. 23 آبان 1399</li>
<li>جلسه board Advisory نحوه درمان سرطان ریه در ایران با هماهنگی شرکت Roche. 8 آبان 1399</li>
<li>وبینار مجازی تومورهای نورواندوکرین. مرکز تحقیقات سرطان بیمارستان میلاد. بیومارکرها در تومورهای نورواندوکرین. 27 شهریور 1399</li>
<li>وبینار مجازی تومورهای نورواندوکرین. مرکز تحقیقات سرطان بیمارستان میلاد. اپیدمیولوژی تومورهای نورواندوکرین. 30 مرداد 1399</li>
<li>وبینار مجازی اصول انجام رادیوتراپی در زمان همه‌گیری بیماری کرونا. 11 اردیبهشت 1399</li>
<li>پنجمین سمینار جامع انکولوژی گیلان. پنل سرطان پروستات. بیمارستان قائم رشت. 4 بهمن 1398</li>
<li>سمینار کاردیوانکولوژی. عوارض ترومبوتیک رادیوتراپی. بیمارستان قلب شهید رجایی. بهمن 1398</li>
<li>چهارمین کنگره بین‌المللی کلینیکال انکولوژی، انجمن رادیوتراپی انکولوژی ایران. نحوه برخورد با سرطان پروستات پیشرفته. آذر 1398</li>
<li>سمینار دو روزه تازه‌های سرطان پروستات. نحوه برخورد با PSA بالا بعد از رادیکال پروستاتکتومی. اصفهان. آذر 1398</li>
<li>کنفرانس تازه‌های سرطان تخمدان. انجمن رادیوتراپی انکولوژی ایران. سرطان تخمدان متاستاتیک. هتل المپیک. 30 آبان 1398</li>
<li>سمینار رویکرد بالینی و سیتوپاتولوژیکی به نئوپلاسم‌های غدد بزاقی. درمان سرطان‌های غدد بزاقی. 16 آبان 1398</li>
<li>سومین کنگره بین‌المللی سرطان پستان جهاد دانشگاهی. سرطان پستان HER2 مثبت متاستاتیک. 2 آبان 1398</li>
<li>سمینار دو روزه Post IMPACT. Anti EGFRs are not the same. هتل پردیسان مشهد. 18 مهر 1398</li>
<li>سمینار 8 HOPE. درمان چندتخصصی سرطان پروستات. 22 شهریور 1398 بیروت، لبنان.</li>
<li>سمینار تازه‌های سرطان پستان، جهاد دانشگاهی علوم پزشکی تهران. درمان سرطان پستان هورمون مثبت و HER2 منفی و early stage. 7 شهریور 1398</li>
<li>کنگره سرطان‌های کولورکتال، انستیتو کانسر ایران. درمان نئوادجوانت سرطان رکتوم، 16 مرداد 1398</li>
<li>همایش یک روزه ایمونوانکولوژی. اصول ایمونوتراپی. انجمن رادیوتراپی انکولوژی ایران. مرداد 1398</li>
<li>پنجمین سمینار تومورهای سر و گردن. رادیوتراپی در سرطان تیروئید. 10 مرداد 1398</li>
<li>چهل و سومین کنگره علمی جامعه جراحان ایران. پنل سرطان رکتوم، 18 خرداد 1398</li>
<li>کنفرانس سرطان غرب آسیا (WACC). انجمن سرطان ایران. پنل سرطان ریه. اسفند 1397</li>
<li>کنگره بین‌المللی سرطان‌های دستگاه گوارش و پستان. دانشگاه علوم پزشکی شهید بهشتی. پنل سرطان معده. 2 اسفند 1397</li>
<li>برنامه بین‌المللی پزشکی شخصی ایران. دانشگاه علوم پزشکی بقیه‌الله. سرطان‌های سر و گردن. 24 بهمن 1397</li>
<li>دوره ارزیابی مهارتی مراقبت‌های حمایتی و تسکینی سرطان. اورژانس‌های انکولوژی. وزارت بهداشت. 5 دی 1397</li>
<li>سومین کنگره بین‌المللی کلینیکال انکولوژی. انجمن رادیوتراپی انکولوژی ایران. گایدلاین‌های کشوری سرطان. 28 آذر 1397</li>
<li>اولین کنگره کاردیوانکولوژی. انجمن رادیوتراپی انکولوژی ایران. عوارض قلبی شیمی‌درمانی. 12 مهر 1397</li>
<li>پنل درمان با anti EGFRs در سرطان کولورکتال متاستاتیک. سمینار V IMPACT. کیف، اوکراین. 6 مهر 1397</li>
<li>تازه‌های تشخیص و درمان کانسر پستان متاستاتیک. انجمن رادیوتراپی انکولوژی ایران. 25 مرداد 1397</li>
<li>چهارمین سمینار تومورهای سر و گردن. انجمن علمی جراحان گوش و حلق و بینی ایران. ایمونوتراپی در سرطان‌های سر و گردن. 11 مرداد 1397</li>
<li>سومین سمینار تومورهای سر و گردن. سرطان اروفارنکس. بیمارستان میلاد. 16 مرداد 1396</li>
<li>کنفرانس بین‌المللی سرطان پستان. سرطان پستان تریپل نگاتیو. دانشگاه علوم پزشکی شهید بهشتی. 25 بهمن 1396</li>
<li>دومین کنگره بین‌المللی کلینیکال انکولوژی. سرطان پانکراس پیشرفته. 22 آذر 1396</li>
<li>دومین کنگره طب فراگیر در سرطان. مرکز تحقیقات سرطان پستان. 26 مهر 1396</li>
<li>سمینار 6 HOPE. درمان رادیونوکلئید در سرطان پروستات. دوبی. 7 مهر 1396</li>
<li>تشخیص و درمان سارکوم و میوم رحمی. رادیوتراپی سارکوم رحم. 2 شهریور 1396</li>
<li>چهل و یکمین کنگره علمی جامعه جراحان ایران. پنل سرطان‌های زنان. 18 اردیبهشت 1396</li>
<li>بیستمین سمینار سالیانه طب فیزیکی و الکترودیاگنوز ایران. نقش رادیوتراپی دوز پایین در اختلالات اسکلتی. 11 اسفند 1395</li>
<li>سمینار رویکرد طب سنتی و مکمل در سرطان. جایگاه طب سنتی در درمان سرطان. 28 بهمن 1395</li>
<li>اولین کنگره بین‌المللی کلینیکال انکولوژی. سرطان پانکراس پیشرفته موضعی. 20 آبان 1395</li>
<li>کنفرانس تومورهای نورواندوکرین. 24 تیر 1395</li>
<li>کنگره سالیانه ENT. سرطان اروفارنکس. تیر 1395</li>
<li>دهمین کنگره سالیانه کلینیکال انکولوژی. مدیریت تهوع و استفراغ شیمی‌درمانی. 20 آبان 1394</li>
<li>سی و نهمین کنگره علمی جامعه جراحان ایران. گایدلاین سرطان معده. 27 اردیبهشت 1394</li>
<li>تازه‌های اروا‌نکولوژی. پنل سرطان کلیه. مشهد. 3 اردیبهشت 1394</li>
<li>دهمین کنگره بین‌المللی سرطان پستان. نقش پزشک عمومی در پیگیری سرطان پستان. 7 اسفند 1393</li>
<li>کنگره سراسری سرطان پستان جهاد دانشگاهی. شیمی‌درمانی در نارسایی کلیه. 1 آبان 1393</li>
<li>کارگاه شیمی‌درمانی پیشرفته. مدیریت عوارض شیمی‌درمانی. 17 مهر 1393</li>
<li>چهارمین کنگره دندان‌پزشکی دانشگاه آزاد. ضایعات بدخیم دهان. مهر 1393</li>
<li>تومور بورد بیمارستان امام حسین (ع). مدیریت تهوع و استفراغ شیمی‌درمانی. 15 اردیبهشت 1393</li>
<li>هشتمین همایش سالیانه کلینیکال انکولوژی. ریسک سرطان ثانویه پس از سرطان پستان. 26 دی 1392</li>
<li>هشتمین همایش سالیانه کلینیکال انکولوژی. کنترل تهوع و استفراغ شیمی‌درمانی. 26 دی 1392</li>
<li>همایش دانشگاه علوم پزشکی یاسوج. غربالگری سرطان‌های شایع ایران. 12 تیر 1392</li>
<li>سمینار سرطان و بارداری. اورژانس‌های انکولوژی در بارداری. دهدشت. 29 خرداد 1392</li>
<li>کنگره ملی برنامه جامع کنترل سرطان. سرطان‌های شایع ایران. سالن صدا و سیما. 15 بهمن 1392</li>
<li>هفتمین همایش سالیانه کلینیکال انکولوژی. مدیریت تهوع و استفراغ شیمی‌درمانی. 27 دی 1391</li>
<li>سی و ششمین کنگره علمی جراحان ایران. ریسک سرطان ثانویه پس از سرطان پستان. 16 اردیبهشت 1391</li>
</ol>
<h3>دبیر علمی کنفرانسهای انکولوژی</h3>
<ol>
<li>وبینار تومورهای نورواندوکرین. انجمن رادیوتراپی انکولوژی ایران. 24 شهریور 1401</li>
<li>وبینار مروری بر ترایالهای مهم انکولوژی. انجمن رادیوتراپی انکولوژی ایران. 23 اردیبهشت 1401</li>
<li>وبینار مروری بر تازه‌های انکولوژی. انجمن رادیوتراپی انکولوژی ایران. 3 دی 1400</li>
<li>وبینار مروری بر ترایالهای مهم انکولوژی. انجمن رادیوتراپی انکولوژی ایران. 26 آذر 1400</li>
<li>وبینار کانسرهای متاستاتیک کولورکتال. انجمن رادیوتراپی انکولوژی ایران. 14 مرداد 1400</li>
<li>وبینار کانسر رکتوم. انجمن رادیوتراپی انکولوژی ایران و پویش دارو. 4 تیر 1400</li>
<li>همایش یک‌روزه بازآموزی غربالگری و درمان سرطان‌های شایع ایران. دانشگاه علوم پزشکی یاسوج. 12 تیر 1392</li>
</ol>
<h3>دبیر اجرایی کنفرانسهای انکولوژی</h3>
<ol>
<li>دومین کنگره بین‌المللی کلینیکال انکولوژی ایران — 22 الی 24 آذر 1396، تهران</li>
<li>اولین کنگره ملی برنامه جامع کنترل سرطان (شورای بیماری‌های خاص صدا و سیما) — 15 الی 17 بهمن 1392، تهران</li>
</ol>
<h3>فعالیتهای آموزشی مجازی (فایل تصویری آموزشی برای رزیدنتهای رادیوانکولوژی)</h3>
<ol>
<li>نحوه تشخیص و درمان متاستازهای استخوانی — 6 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>نحوه تشخیص و درمان متاستازهای مغزی — 4 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>نحوه تشخیص و درمان متاستازهای ریوی — 2 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>نحوه تشخیص و درمان متاستازهای کبدی — 3 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>سیستیت هموراژیک ناشی از شیمی‌درمانی — 4 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>سیستیت هموراژیک ناشی از رادیوتراپی — 4 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>نحوه تشخیص و درمان متاستازهای احشایی — 1 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>نحوه تشخیص و درمان عودهای لگنی — 1 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>داروهای آلکیله‌ کننده (Alkylating Agents) — 4 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>داروهای آنالوگ پلاتین (Platinum Analogues) — 4 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>داروهای آنتی‌متابولیت (Anti-metabolites) — 7 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>تحت فشار قرار گرفتن بدخیم نخاع — 3 فایل تصویری آموزشی<br>
<a>مشاهده لینک</a>
</li>
<li>نحوه تشخیص و درمان متاستازهای احشایی — 1 فایل تصویری آموزشی (تکراری)<br>
<a>مشاهده لینک</a>
</li>
</ol>
<h3>فعالیتهای اجرایی</h3>
<ol>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات شانزدهمین همایش سالانه کلینیکال انکولوژی — بهمن 1400، تهران، ایران</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات پانزدهمین همایش سالانه کلینیکال انکولوژی — بهمن 1399، تهران، ایران</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات چهاردهمین همایش سالانه کلینیکال انکولوژی — آذر 1398، تهران، ایران</li>
<li>عضو کمیته علمی چهارمین سمینار تومورهای سر و گردن — مرکز تحقیقات سرطان بیمارستان میلاد — 11 و 12 مرداد 1397</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات سیزدهمین همایش سالانه کلینیکال انکولوژی — آذر 1397، تهران، ایران</li>
<li>ارزیاب بیرونی هفتمین دوره آزمون صلاحیت بالینی دانشگاه علوم پزشکی بابل — 19 مرداد 1396</li>
<li>دبیر اجرایی دوازدهمین همایش سالانه کلینیکال انکولوژی — آذر 1396، تهران، ایران</li>
<li>ارزیاب بیرونی دوره آزمون صلاحیت بالینی دانشگاه علوم پزشکی یزد — 13 بهمن 1395</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات یازدهمین همایش سالانه کلینیکال انکولوژی — آبان 1395، تهران، ایران</li>
<li>عضو کمیته موربیدیتی و مورتالیتی بیمارستان شهدای تجریش — مهر 1395 لغایت مهر 1396</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات دهمین همایش سالانه کلینیکال انکولوژی — آبان 1394، شیراز، ایران</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات نهمین همایش سالانه کلینیکال انکولوژی — مهر 1393، تهران، ایران</li>
<li>عضو کمیته علمی هفتمین کنگره سراسری سرطان پستان — 30 مهر تا 2 آبان 1393 — بیمارستان امام خمینی، تهران، ایران</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات هشتمین همایش سالانه کلینیکال انکولوژی — دی 1392، اصفهان، ایران</li>
<li>عضو کمیته علمی هشتمین همایش سالانه انجمن سرطان ایران — 30 آذر تا 1 دی 1391</li>
<li>عضو کمیته‌های علمی، اجرایی و داوری مقالات همایش سالانه کلینیکال انکولوژی — دی 1391، تهران، ایران</li>
<li>عضو کمیته داوری و اجرایی مقالات سیزدهمین همایش سالانه انجمن آسیب‌شناسی ایران و هفتمین همایش سالانه انجمن سرطان ایران — مهر 1390، تهران، ایران</li>
<li>عضو کمیته اجرایی سمینار سرطان با منشأ ناشناخته — انجمن سرطان ایران — تهران — 6 مرداد 1390</li>
<li>عضو کمیته اجرایی اولین همایش ترومبوآمبولی و سرطان — انجمن سرطان ایران — 28 بهمن 1389</li>
<li>عضو کمیته داوری مقالات و کمیته اجرایی دوازدهمین همایش سالانه انجمن آسیب‌شناسی ایران و ششمین همایش سالانه انجمن سرطان ایران — آبان 1389، تهران، ایران</li>
<li>عضو کمیته داوری مقالات و کمیته اجرایی همایش سالانه کلینیکال انکولوژی — دی 1389، تهران، ایران</li>
</ol>
<h3>فعالیتهای مطبوعاتی</h3>
<ol>
<li>دبیر هیات تحریریه مجله علمی آموزشی دانستنی‌های سرطان — از شماره ۲۸ (بهار ۱۳۹۲) تا شماره ۳۱ (تابستان ۱۳۹۳)</li>
<li>ویراستار نشریه داخلی علمی‌خبری انجمن سرطان ایران — خرداد ۱۳۸۹ لغایت بهمن ۱۳۸۹ (۸ شماره)</li>
</ol>
<h3>سایر اطلاعات</h3>
<ol>
<li>آیلتس آکادمیک — نمره کلی 8.5</li>
<li>دانش‌آموخته سازمان ملی پرورش استعدادهای درخشان (سمپاد)، راهنمایی و دبیرستان علامه حلی تهران</li>
</ol>
<h3>پشتیبانی 24/7 بیماران</h3>
تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.' WHERE path = '/team/دکتر-احمد-مافی/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر حسین اصغری پور
</p>
<ul>
<li>
متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</li>
<li>
دارای بورد تخصصی و فوق تخصصی
</li>
</ul>
<ul>
<li>
عضو انجمن سرطان آمریکا
</li>
</ul>
<a>
رزرو وقت
</a>
<p>۱۰۳۸۲۴</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر حسین اصغری پور سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر حسین اصغری پور یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-حسین-اصغری-پور/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دكتر فاطمه نائيني
</p>
<ul>
<li>
متخصص تغذيه بالینی و رژيم درماني
</li>
<li>
دانشگاه علوم پزشكي تهران | عضو ملی بنیاد ملی نخبگان
</li>
</ul>
<ul>
<li>
شاخص علمی 22H | بیش از 50 مقاله علمی در مجلات معتبر بین المللی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشكي: ن.ت: ٨١٦٤</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دكتر فاطمه نائيني سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دكتر فاطمه نائيني یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دكتر-فاطمه-نائيني/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر بهناز بهزادی
</p>
<ul>
<li>
متخصص رادیوانکولوژی
</li>
<li>
بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی
</li>
</ul>
<ul>
<li>
دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>‌</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر بهناز بهزادی سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر بهناز بهزادی یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-بهناز-بهزادی/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر علیرضا تاتینا
</p>
<ul>
<li>
متخصص قلب و عروق | دارای بورد تخصصی
</li>
<li>
فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی: 97995</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر علیرضا تاتینا سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر علیرضا تاتینا یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-علیرضا-تاتینا/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر مهناز عالم زاده بحرینی
</p>
<ul>
<li>
متخصص قلب و عروق | دارای بورد تخصصی
</li>
<li>
فلوشیپ اکوکاردیوگرافی از انستیتو قلب و عروق شهید رجایی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی: ۱۰۳۹۵۷</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر مهناز عالم زاده بحرینی سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر مهناز عالم زاده بحرینی یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>رزومه پزشک</h3>
<p>متخصص قلب و عروق فلوشیپ اکوکاردیوگرافی</p>
<p>رتبه 45 کنکور</p>
<p>پزشکی عمومی از دانشگاه تهران</p>
<p>تخصص قلب و عروق دانشگاه ایران</p>
<p>فلوشیپ اکوکاردیوگرافی از دانشگاه تهران</p>
<p>سابقه کار در زمینه قلب و عروق از سال 1389 (15 سال سابقه)</p>
<h3>انجام اکوهای فوق تخصصی</h3>
<ol>
<li>اکوکاردیوگرافی تیشو داپلر</li>
<li>استرس اکوکاردیوگرافی با دارو</li>
<li>استرس اکوکاردیوگرافی با ورزش</li>
<li>اکوکاردیوگرافی از راه مری</li>
</ol>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-مهناز-عالم-زاده-بحرینی/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر شادی شکرخوار
</p>
<ul>
<li>
متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی
</li>
<li>
فلوشیپ اکوکاردیوگرافی از انستیتو قلب و عروق شهید بهشتی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی: ۱۰۵۴۴۹</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر شادی شکرخوار سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر شادی شکرخوار یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>رزومه پزشک</h3>
<h3>سوابق تحصیلی</h3>
<ul>
<li>
<ul>
<li>دوره دبیرستان: دبیرستان فرزانگان (استعدادهای درخشان)</li>
<li>دکترای حرفه‌ای پزشکی (MD): دانشگاه علوم پزشکی شهید بهشتی – قبولی با رتبه ۹۳ کنکور سراسری</li>
<li>تخصص قلب و عروق: دانشگاه علوم پزشکی شهید بهشتی – بیمارستان شهید مدرس</li>
<li>فلوشیپ اکوکاردیوگرافی: دانشگاه علوم پزشکی شهید بهشتی – بیمارستان شهید مدرس (۱۳۹۵ تا ۱۳۹۷، ۱۸ ماه)</li>
</ul>
</li>
</ul>
<h3>سوابق شغلی و حرفه‌ای</h3>
<ul>
<li>
<ul>
<li>۴ سال فعالیت به‌عنوان متخصص قلب و عروق و فلوشیپاکوکاردیوگرافی در بیمارستان شهید بهشتی، دانشگاه علوم پزشکی قم</li>
<li>از سال ۱۴۰۰ تاکنون فعالیت در تهران در بخش خصوصی به‌عنوان متخصص قلب و عروق و فلوشیپ اکوکاردیوگرافی</li>
</ul>
</li>
</ul>
<h3>عضویت های علمی</h3>
<ul>
<li>
<ul>
<li>عضو انجمن اکوکاردیوگرافی آمریکا (ASE)</li>
<li>عضو انجمن اکوکاردیوگرافی ایران</li>
</ul>
</li>
</ul>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-شادی-شکرخوار/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر حسام دانش آموز
</p>
<ul>
<li>
فوق تخصص قلب کودکان
</li>
</ul>
<ul>
<li>
متخصص کودکان و اطفال
</li>
</ul>
<a>
رزرو وقت
</a>
<p>‌</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر حسام دانش آموز سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر حسام دانش آموز یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-حسام-دانش-آموز/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر مریم بدیع زادگان
</p>
<ul>
<li>
متخصص اعصاب و روان (روانپزشک)
</li>
<li>
دارای بورد تخصصی از دانشگاه شهید بهشتی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی: ۹۰۶۶۷</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر مریم بدیع زادگان سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر مریم بدیع زادگان یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>رزومه پزشک</h3>
<p>بورد تخصصی اعصاب و روان (روان پزشکی) از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>عضو انجمن روان پزشکان ایران</p>
<p>عضو سازمان نظام پزشکی ایران (90667)</p>
<p>سابقه کار بالینی و درمانی در بیمارستان های روان پزشکی کشور</p>
<p>همکاری با مرکز علوم تحقیقات رفتاری دانشگاه علوم پزشکی شهید بهشتی</p>
<p>همکاری در داوری مقالات پژوهشگاه خانواده شهید بهشتی</p>
<p>تشخیص و درمان انواع اختلالات روان پزشکی (وسواس، اضطراب، افسردگی، دوقطبی، اختلالات رفتاری، اختلالات خوردن، اختلالات توجه و تمرکز، اختلال خواب و &#8230;)</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-مریم-بدیع-زادگان/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر غزاله حیدری‌راد
</p>
<ul>
<li>
پزشک (MD.PhD) طب ایرانی
</li>
<li>
عضو هیأت علمی دانشگاه علوم پزشکی شهید بهشتی
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی: ١٠٥٩٩٥</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر غزاله حیدری‌راد سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر غزاله حیدری‌راد یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-غزاله-حیدریراد/';

UPDATE pages SET body = '<h3>از پزشکان همراه کلینیک</h3>
<h4>دقت در درمان، آرامش در زندگی</h4>
<p>
دکتر رضا مقبولی
</p>
<ul>
<li>
متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)
</li>
</ul>
<a>
رزرو وقت
</a>
<p>نظام پزشکی 189251</p>
<a>
نوبت‌دهی آنلاین
</a>
<p>تعهد به کیفیت خدمات، دقت در بررسی وضعیت بیماران، و برخورد انسانی، باعث شده است که بیماران ایشان تجربه‌ای مطمئن و آرامش‌بخش از روند درمان داشته باشند. ما افتخار می‌کنیم که حضور پزشکانی همچون دکتر رضا مقبولی سطح خدمات درمانی کلینیک را ارتقا داده و نقش مهمی در بهبود سلامت مراجعه‌کنندگان ایفا می‌کنند</p>
<p>دکتر رضا مقبولی یکی از اعضای متخصص و باتجربه تیم درمانی ماست که سال‌ها در حوزه تشخیص و درمان بیماری‌ها فعالیت داشته و همواره تلاش می‌کند با به‌کارگیری جدیدترین استانداردهای علمی و روش‌های روز پزشکی، بهترین خدمات را به بیماران ارائه دهد. رویکرد درمانی ایشان بر پایه احترام به بیمار، تشخیص دقیق، و انتخاب مناسب‌ترین روش درمانی بنا شده است.</p>
<h3>پشتیبانی 24/7 بیماران</h3>
<p>تیم پشتیبانی ما به‌صورت شبانه‌روزی در دسترس است تا در هر مرحله از فرآیند نوبت‌گیری و مراجعه، پاسخ‌گوی سوالات و نیازهای شما باشد و تجربه‌ای مطمئن و آرامش‌بخش را برایتان فراهم کند.</p>' WHERE path = '/team/دکتر-رضا-مقبولی/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
20 خرداد 1405
</li>
<li>
8:29 ق.ظ
</li>
<li>
<a href="/category/شیمی-درمانی/">شیمی درمانی</a>
</li>
</ul>
<p>شیمی‌درمانی یکی از رایج‌ترین روش‌های درمان سرطان است، اما بسیاری از بیماران و خانواده‌ها در طول درمان با یک پرسش مهم روبه‌رو می‌شوند که آیا داروها واقعاً اثر کرده‌اند؟ و پاسخ به این سؤال همیشه ساده نیست، چون نتیجه شیمی‌درمانی فقط از روی احساس بیمار یا کاهش عوارض بیماری مشخص نمی‌شود و معمولاً به بررسی‌های تخصصی نیاز دارد.</p>
<p>برای توضیح این موضوع باید بیماران را در دو دسته بررسی کنیم:</p>
<ol>
<li>بیمارانی که توده سرطانی آنان به طور کامل جراحی شده و دیگر توده ی واضح در بدن وجود ندارد.</li>
<li>بیمارانی که به هر دلیلی دارای توده سرطانی در بدن هستند.</li>
</ol>
<p>
<strong>گروه اول:</strong>
</p>
<p>از آنجاییکه در این بیماران توده خارج شده است اثربخشی شیمی درمانی بطور مستقیم قابل بررسی نیست. ولی خبر خوب این است که اثربخشی داروها قبلاً در مطالعات پزشکی بر روی هزاران بیمار بررسی شده است و با اطمینان می توان گفت که دارو اثربخش بوده و احتمال عود را کمتر خواهد کرد.</p>
<p>
<strong>گروه دوم:</strong>
</p>
<p>در این بیماران از چند روش می توان برای بررسی اثربخشی دارو کمک گرفت:</p>
<h2>نشانه‌هایی که می‌توانند از اثربخشی شیمی‌درمانی خبر دهند</h2>
<p>در برخی بیماران نخستین نشانه‌های موفقیت درمان به شکل کاهش علائم بیماری ظاهر می‌شود. برای مثال اگر تومور باعث درد شده باشد ممکن است شدت درد کمتر شود و برخی بیماران انرژی بیشتری پیدا می‌کنند. کاهش تنگی نفس، بهبود اشتها یا کمتر شدن خونریزی‌های مرتبط با بیماری نیز می‌تواند از علائم امیدوارکننده باشد.</p>
<p>با این حال این نشانه‌ها به‌تنهایی کافی نیستند و پزشکان هرگز فقط بر اساس بهبود ظاهری بیمار درباره موفقیت درمان تصمیم نمی‌گیرند.</p>
<h2>تصویربرداری: یکی از مهم‌ترین راههای تشخیص پاسخ به درمان</h2>
<p>یکی از راههای اصلی ارزیابی اثربخشی شیمی‌درمانی انجام تصویربرداری‌های دوره‌ای است. پزشک با استفاده از سونوگرافی، سی‌تی‌اسکن، ام‌آر‌آی، پت‌اسکن و یا سایر روشها اندازه تومور و میزان گسترش بیماری را با نتایج قبلی مقایسه می‌کند.</p>
<p>در این بررسی‌ها معمولاً یکی از چند حالت زیر مشاهده می‌شود:</p>
<h3>●       کوچک شدن تومور</h3>
<p>اگر اندازه تومور نسبت به قبل کمتر شده باشد، نشان می‌دهد سرطان به داروها پاسخ داده است و این وضعیت یکی از واضح‌ترین نشانه‌های موفقیت درمان محسوب می‌شود.</p>
<h3>●       ثابت ماندن بیماری</h3>
<p>گاهی تومور کوچک نمی‌شود اما رشد هم نمی‌کند و در بسیاری از سرطان‌ها همین کنترل بیماری یک نتیجه مثبت به شمار می‌رود، زیرا هدف درمان جلوگیری از پیشرفت سرطان است.</p>
<h3>●       از بین رفتن کامل آثار قابل مشاهده سرطان</h3>
<p>در برخی موارد هیچ نشانه‌ای از تومور در تصاویر دیده نمی‌شود و این وضعیت به عنوان پاسخ کامل به درمان شناخته می‌شود، هرچند همچنان نیاز به پیگیری‌های منظم وجود دارد.</p>
<h3>●       رشد تومور یا ایجاد ضایعات جدید</h3>
<p>اگر اندازه تومور بیشتر شود یا نواحی جدیدی از بیماری دیده شود، ممکن است نشانه این باشد که بیماری به دارو مقاوم شده پزشک باید گزینه‌های دیگر درمانی را در نظر بگیرد.</p>
<h2>نقش آزمایش خون در ارزیابی شیمی‌درمانی</h2>
<p>در برخی انواع سرطان، آزمایش خون می‌تواند اطلاعات ارزشمندی درباره روند درمان ارائه دهد و برخی نشانگرهای توموری در صورت پاسخ مناسب به درمان کاهش پیدا می‌کنند. البته این آزمایش‌ها به‌تنهایی معیار قطعی نیستند و معمولاً در کنار تصویربرداری تفسیر می‌شوند و متخصصان سرطان‌شناسی از تغییرات این نشانگرها به عنوان یک ابزار کمکی برای بررسی روند بیماری استفاده می‌کنند.</p>
<h2>جمع‌بندی</h2>
<p>تشخیص موفقیت شیمی‌درمانی فقط با احساس بیمار امکان‌پذیر نیست و مهم‌ترین معیار، نتایج مجموعه ای از بررسیهای دوره‌ای است که وضعیت تومور را نشان می‌دهد. آزمایش‌های خون، نشانگرهای توموری و ارزیابی علائم بیمار نیز در کنار تصاویر پزشکی به پزشک کمک می‌کنند تا میزان پاسخ سرطان به درمان را مشخص کند و به همین دلیل بهترین راه برای قضاوت درباره نتیجه شیمی‌درمانی، پیگیری منظم و تفسیر نتایج توسط تیم درمان است. امیدواریم این مطلب از <a href="/">همراه کلینیک</a> برای شما مفید و کاربردی بوده باشد.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/#respond">لغو نظر</a>
</h3>' WHERE path = '/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
8 شهریور 1405
</li>
<li>
8:10 ق.ظ
</li>
<li>
<a href="/category/قلب-و-عروق/">قلب و عروق</a>
</li>
</ul>
<p>
<strong>📌 نکته کلیدی:</strong> گرفتگی عروق پا (بیماری شریان محیطی) یک وضعیت جدی و پیشرونده است که در صورت عدم درمان می‌تواند منجر به عوارض خطرناک مانند زخم‌های مزمن، گنگرن و حتی قطع عضو شود. تشخیص زودهنگام و مداخله به موقع، کلید پیشگیری از این عوارض است.</p>
<h2>گرفتگی عروق پا چیست و چرا اتفاق می‌افتد؟</h2>
<p>گرفتگی عروق پا که در اصطلاح پزشکی به آن <strong>بیماری شریان محیطی (Peripheral Arterial Disease &#8211; PAD)</strong> گفته می‌شود، وضعیتی است که در آن شریان‌های خون‌رسان به پاها به دلیل تجمع پلاک‌های آترواسکلروتیک تنگ یا مسدود می‌شوند. این پلاک‌ها از ترکیبی از کلسترول، چربی‌ها، کلسیم و بافت‌های فیبری تشکیل شده‌اند که به تدریج در دیواره داخلی رگ‌ها رسوب می‌کنند.</p>
<p>وقتی شریان‌های پا تنگ می‌شوند، خون کافی که حامل اکسیژن و مواد مغذی است به بافت‌های اندام‌های تحتانی نمی‌رسد. این مسئله به ویژه هنگام فعالیت بدنی مانند راه رفتن یا بالا رفتن از پله‌ها خود را نشان می‌دهد، زیرا در این شرایط عضلات پا به اکسیژن بیشتری نیاز دارند.</p>
<p>این بیماری معمولاً به آرامی و در طول سال‌ها پیشرفت می‌کند و بسیاری از افراد تا زمانی که علائم شدید ظاهر نشود، از وجود آن آگاه نیستند. به همین دلیل به آن &#8220;قاتل خاموش&#8221; نیز می‌گویند.</p>
<p>
<strong>💡 آیا می‌دانستید؟</strong> گرفتگی عروق پا فقط پاها را تحت تأثیر قرار نمی‌دهد، این بیماری نشان‌دهنده وجود آترواسکلروز در کل سیستم عروقی بدن است و خطر بیماری‌های قلبی و سکته مغزی را نیز افزایش می‌دهد.</p>
<h2>علائم هشداردهنده | بدن شما چه پیامی می‌فرستد؟</h2>
<p>شناخت علائم گرفتگی عروق پا برای تشخیص زودهنگام بسیار مهم است. این علائم ممکن است در مراحل اولیه خفیف باشند و به تدریج شدیدتر شوند:</p>
🚶‍♂️
<h3>لنگش متناوب</h3>
<p>درد، گرفتگی یا خستگی در پاها هنگام راه رفتن که با استراحت چند دقیقه‌ای برطرف می‌شود. این شایع‌ترین علامت بیماری است.</p>
❄️
<h3>سردی غیرطبیعی</h3>
<p>احساس سردی مداوم در یک یا هر دو پا، به ویژه در مقایسه با سایر نقاط بدن.</p>
🎨
<h3>تغییرات پوستی</h3>
<p>رنگ‌پریدگی، آبی شدن یا براق و نازک شدن پوست پاها. ممکن است ریزش مو در پاها نیز مشاهده شود.</p>
💅
<h3>تغییرات ناخن</h3>
<p>کاهش سرعت رشد ناخن‌های پا، ضخیم شدن یا تغییر شکل آن‌ها.</p>
⚡
<h3>ضعف و بی‌حسی</h3>
<p>احساس ضعف، بی‌حسی یا سوزن‌سوزن شدن در پاها و انگشتان.</p>
🩹
<h3>زخم‌های دیر‌درمان</h3>
<p>زخم‌ها و جراحت‌هایی که به کندی بهبود می‌یابند یا اصلاً خوب نمی‌شوند.</p>
<h2>مراحل پیشرفت بیماری | از علائم خفیف تا عوارض جدی</h2>
<p>گرفتگی عروق پا یک بیماری پیشرونده است که معمولاً در چهار مرحله طبقه‌بندی می‌شود. درک این مراحل به شما کمک می‌کند تا اهمیت درمان به موقع را بهتر درک کنید:</p>
<p>
<strong>مرحله ۱: بدون علامت (Asymptomatic)</strong>
</p>
<p>در این مرحله، گرفتگی عروق وجود دارد اما بیمار هیچ علامتی ندارد. بیماری فقط با معاینات تخصصی قابل تشخیص است.</p>
<p>
<strong>مرحله ۲: لنگش متناوب (Intermittent Claudication)</strong>
</p>
<p>درد پا هنگام راه رفتن که با استراحت برطرف می‌شود. این مرحله به دو زیرمرحله تقسیم می‌شود: ۲آ (درد بعد از بیش از ۲۰۰ متر راه رفتن) و ۲ب (درد بعد از کمتر از ۲۰۰ متر).</p>
<p>
<strong>مرحله ۳: درد استراحتی (Rest Pain)</strong>
</p>
<p>درد شدید در پاها حتی در حالت استراحت، به ویژه شب‌ها. این درد معمولاً با آویزان کردن پا از لبه تخت کاهش می‌یابد.</p>
<p>
<strong>مرحله ۴: زخم و گنگرن (Ulceration/Gangrene)</strong>
</p>
<p>ایجاد زخم‌های باز، بافت‌مردگی و خطر عفونت شدید. در این مرحله خطر قطع عضو وجود دارد و نیاز به مداخله فوری است.</p>
<h2>چرا نباید این بیماری را نادیده گرفت؟</h2>
<p>گرفتگی عروق پا اگر درمان نشود، می‌تواند منجر به عوارض جدی و حتی تهدیدکننده حیات شود:</p>
<h3>عوارض جدی و تهدیدکننده</h3>
<p>
<strong>ایسکرنی بحرانی اندام (Critical Limb Ischemia):</strong>
</p>
<p>وضعیتی که در آن جریان خون به قدری کاهش می‌یابد که بافت‌ها حتی در حالت استراحت نیز اکسیژن کافی دریافت نمی‌کنند. این وضعیت با درد شدید و زخم‌های باز همراه است.</p>
<p>
<strong>گنگرن (بافت‌مردگی):</strong>
</p>
<p>مرگ بافت‌ها به دلیل نرسیدن خون کافی. بافت‌های مرده سیاه می‌شوند و می‌توانند منجر به عفونت شدید شوند.</p>
<p>
<strong>عفونت‌های شدید و سپسیس:</strong>
</p>
<p>زخم‌های باز می‌توانند به راحتی عفونی شوند و عفونت می‌تواند وارد جریان خون شده و منجر به سپسیس (عفونت خون) شود که تهدیدکننده حیات است.</p>
<p>
<strong>خطر قطع عضو:</strong>
</p>
<p>در موارد پیشرفته و بدون درمان، ممکن است برای جلوگیری از گسترش عفونت و نجات جان بیمار، نیاز به قطع عضو باشد.</p>
<p>
<strong>📊 آمار نگران‌کننده:</strong> طبق مطالعات حدود ۲۰۲ میلیون نفر در سراسر جهان به بیماری شریان محیطی مبتلا هستند و در ایران نیز شیوع این بیماری در افراد بالای ۵۰ سال حدود ۱۰ تا ۱۵ درصد تخمین زده می‌شود، اما بسیاری از این افراد از بیماری خود آگاه نیستند.</p>
<h2>چه کسانی بیشتر در معرض خطر هستند؟</h2>
<p>برخی عوامل خطر ابتلا به گرفتگی عروق پا را به شدت افزایش می‌دهند. اگر یکی یا چند مورد از این عوامل را دارید، باید بیشتر مراقب سلامتی عروق خود باشید:</p>
<table>
<thead>
<tr>
<th>عامل خطر</th>
<th>تأثیر بر عروق</th>
<th>میزان خطر</th>
</tr>
</thead>
<tbody>
<tr>
<td>
<strong>سیگار کشیدن</strong>
</td>
<td>آسیب مستقیم به دیواره عروق، افزایش تشکیل پلاک و کاهش اکسیژن‌رسانی</td>
<td>بسیار بالا</td>
</tr>
<tr>
<td>
<strong>دیابت</strong>
</td>
<td>آسیب به عروق کوچک و بزرگ، کاهش حساسیت به درد و افزایش خطر عفونت</td>
<td>بسیار بالا</td>
</tr>
<tr>
<td>
<strong>فشار خون بالا</strong>
</td>
<td>فشار بر دیواره عروق و تسریع تشکیل پلاک‌های آترواسکلروتیک</td>
<td>بالا</td>
</tr>
<tr>
<td>
<strong>کلسترول بالا</strong>
</td>
<td>تجمع چربی در دیواره عروق و تنگی تدریجی آن‌ها</td>
<td>بالا</td>
</tr>
<tr>
<td>
<strong>سن بالای ۵۰ سال</strong>
</td>
<td>فرسودگی طبیعی عروق و کاهش انعطاف‌پذیری دیواره رگ‌ها</td>
<td>متوسط</td>
</tr>
<tr>
<td>
<strong>چاقی و کم‌تحرکی</strong>
</td>
<td>افزایش فشار بر عروق، کاهش گردش خون و افزایش التهاب</td>
<td>متوسط</td>
</tr>
<tr>
<td>
<strong>سابقه خانوادگی</strong>
</td>
<td>ژنتیک و عوامل ارثی می‌توانند خطر ابتلا را افزایش دهند</td>
<td>متوسط</td>
</tr>
</tbody>
</table>
<h2>روش‌های تشخیص | چگونه گرفتگی عروق پا تشخیص داده می‌شود؟</h2>
<p>تشخیص دقیق گرفتگی عروق پا نیازمند معاینه تخصصی و استفاده از روش‌های تصویربرداری پیشرفته است و پیشنهاد میشود به <a href="/service/کلینیک-واریس/">
<strong>کلینیک تخصصی واریس</strong>
</a> یا <a href="/service/قلب-و-عروق/">
<strong>کلینیک تخصصی قلب و عروق</strong>
</a> مراجعه فرمایید. پزشک معمولاً از روش‌های زیر برای تشخیص استفاده می‌کند:</p>
<p>
<strong>۱. معاینه فیزیکی و بررسی نبض</strong>
</p>
<p>پزشک نبض شریان‌های مختلف پا را بررسی می‌کند و به دنبال علائم ظاهری مانند تغییر رنگ پوست، زخم، سردی و ریزش مو می‌گردد. همچنین با گوشی پزشکی (استتوسکوپ) به دنبال صدای غیرطبیعی جریان خون (بروف) می‌شنود.</p>
<p>
<strong>۲. اندازه‌گیری ABI (شاخص مچ پا-بازو)</strong>
</p>
<p>این تست ساده و غیرتهاجمی، فشار خون در مچ پا را با فشار خون در بازو مقایسه می‌کند. اگر فشار خون در پا کمتر از بازو باشد، نشان‌دهنده گرفتگی عروق است. این تست معمولاً اولین قدم در تشخیص است.</p>
<p>
<strong>۳. سونوگرافی داپلر رنگی</strong>
</p>
<p>استفاده از امواج صوتی برای مشاهده جریان خون و تشخیص محل و شدت گرفتگی. این روش غیرتهاجمی است و اطلاعات دقیقی درباره وضعیت عروق ارائه می‌دهد.</p>
<p>
<strong>۴. آنژیوگرافی (Angiography)</strong>
</p>
<p>تزریق ماده حاجب از طریق یک کاتتر کوچک و تصویربرداری با اشعه ایکس برای مشاهده دقیق عروق و محل گرفتگی. این روش معمولاً زمانی انجام می‌شود که نیاز به مداخله درمانی باشد.</p>
<p>
<strong>۵. سی‌تی آنژیوگرافی یا MR آنژیوگرافی</strong>
</p>
<p>تصویربرداری سه‌بعدی از عروق برای ارزیابی دقیق‌تر و برنامه‌ریزی درمان. این روش‌ها غیرتهاجمی‌تر از آنژیوگرافی سنتی هستند.</p>
<h2>گزینه‌های درمانی</h2>
<p>خوشبختانه روش‌های مختلفی برای درمان گرفتگی عروق پا وجود دارد. انتخاب روش درمان بستگی به شدت بیماری، محل گرفتگی، وضعیت کلی بیمار و اهداف درمانی دارد:</p>
<h3>درمان‌های غیرجراحی و تغییر سبک زندگی</h3>
<ul>
<li>
<strong>ترک سیگار:</strong> مهم‌ترین قدم در درمان. سیگار مستقیماً به عروق آسیب می‌زند و ترک آن می‌تواند پیشرفت بیماری را متوقف کند.</li>
<li>
<strong>برنامه ورزشی منظم:</strong> پیاده‌روی تحت نظارت می‌تواند به تشکیل عروق جدید (کولاترال) کمک کند و علائم را بهبود بخشد.</li>
<li>
<strong>رژیم غذایی سالم:</strong> کاهش مصرف چربی‌های اشباع، افزایش مصرف میوه و سبزیجات، و کنترل وزن.</li>
<li>
<strong>دارودرمانی:</strong> داروهای ضد پلاکت (مانند آسپرین)، داروهای کاهنده کلسترول (استاتین‌ها)، و داروهای گشادکننده عروق.</li>
<li>
<strong>کنترل بیماری‌های زمینه‌ای:</strong> مدیریت دقیق دیابت، فشار خون و کلسترول.</li>
</ul>
<h3>درمان‌های کم‌تهاجمی (Interventional)</h3>
<ul>
<li>
<strong>RFA</strong>: بستن و از کار انداختن رگ‌های واریسی معیوب با استفاده از انرژی گرمایی رادیوفرکانسی از طریق یک کاتتر باریک.</li>
<li>
<strong>اسکلروتراپی</strong>: تزریق ماده‌ای شیمیایی به رگ‌های کوچک برای تحریک چسبندگی دیواره‌ها و جذب تدریجی رگ توسط بدن.</li>
<li>
<strong>لیزر</strong>: استفاده از نور متمرکز لیزر (داخل رگی یا سطحی) برای تخریب و بستن رگ‌های آسیب‌دیده بدون ایجاد برش جراحی.</li>
<li>
<strong>جراحی</strong>: خارج کردن فیزیکی رگ‌های شدیداً آسیب‌دیده در مواردی که روش‌های کم‌تهاجمی پاسخگو نیستند یا بیماری پیشرفته است.</li>
</ul>
<h3>درمان‌های جراحی</h3>
<ul>
<li>
<strong>بای‌پس عروقی (Bypass Surgery):</strong> ایجاد یک مسیر جایگزین برای خون با استفاده از رگ خود بیمار (معمولاً از پا یا بازو) یا رگ مصنوعی. این روش برای گرفتگی‌های طولانی و پیچیده استفاده می‌شود.</li>
<li>
<strong>اندآرترکتومی (Endarterectomy):</strong> برداشتن پلاک‌ها از داخل شریان به صورت جراحی. این روش معمولاً برای گرفتگی‌های کوتاه در شریان‌های بزرگ استفاده می‌شود.</li>
<li>
<strong>قطع عضو (Amputation):</strong> در موارد بسیار پیشرفته که بافت‌مردگی گسترده وجود دارد و سایر درمان‌ها مؤثر نبوده‌اند، ممکن است نیاز به قطع عضو باشد. هدف نجات جان بیمار است.</li>
</ul>
<p>
<strong>✅ نکته مهم:</strong> تشخیص زودهنگام می‌تواند نیاز به جراحی را به حداقل برساند. در مراحل اولیه، اغلب با تغییر سبک زندگی و دارودرمان می‌توان بیماری را کنترل کرد و از پیشرفت آن جلوگیری نمود.</p>
<h2>برای ارزیابی و درمان گرفتگی عروق پا، بسته به نوع و شدت بیماری، مراجعه به یکی از متخصصین زیر توصیه می‌شود</h2>
<ol>
<li>
<strong>جراح عروق</strong>: مرجع اصلی برای تشخیص جامع و تصمیم‌گیری نهایی بین درمان دارویی، روش‌های کم‌تهاجمی یا جراحی.</li>
<li>
<strong>فوق تخصص رادیولوژی مداخله‌ای</strong>: متخصص در انجام روش‌های درمانی کم‌تهاجمی و هدایت‌شده با تصویربرداری، که اغلب در کنار یا با ارجاع تیم جراحی عروق فعالیت می‌کند.</li>
</ol>
<h2>چه زمانی باید فوراً به کلینیک تخصصی قلب و عروق مراجعه کرد؟</h2>
<h3>علائم هشدار فوری &#8211; نیاز به مداخله اورژانسی</h3>
<p>اگر هر یک از علائم زیر را تجربه می‌کنید، فوراً به <strong>کلینیک تخصصی قلب و عروق</strong> مراجعه کنید:</p>
<ul>
<li>درد شدید و مداوم در پا که حتی در حالت استراحت نیز وجود دارد</li>
<li>زخم‌های باز که بهبود نمی‌یابند یا عفونی شده‌اند</li>
<li>تغییر رنگ پوست به سیاه یا آبی تیره</li>
<li>سردی شدید یک پا نسبت به پای دیگر</li>
<li>از دست دادن حس یا حرکت در پا</li>
<li>تب همراه با درد و قرمزی در پا (نشانه عفونت)</li>
</ul>
<h2>پیشگیری: چگونه از گرفتگی عروق پا جلوگیری کنیم؟</h2>
<p>پیشگیری همیشه بهتر از درمان است. با رعایت نکات زیر می‌توانید خطر ابتلا به گرفتگی عروق پا را به شدت کاهش دهید:</p>
🚭
<h3>ترک سیگار</h3>
<p>سیگار مهم‌ترین عامل خطر قابل تغییر است. ترک آن می‌تواند خطر ابتلا را به شدت کاهش دهد و پیشرفت بیماری را متوقف کند.</p>
🏃‍♂️
<h3>ورزش منظم</h3>
<p>حداقل ۳۰ دقیقه پیاده‌روی روزانه یا ورزش هوازی برای بهبود گردش خون و تقویت عروق.</p>
🥗
<h3>تغذیه سالم</h3>
<p>رژیم غذایی کم‌چرب، پرفیبر و غنی از میوه، سبزیجات و غلات کامل. کاهش مصرف نمک و قند.</p>
⚖️
<h3>کنترل وزن</h3>
<p>حفظ وزن سالم برای کاهش فشار بر عروق و قلب و بهبود گردش خون.</p>
🩺
<h3>کنترل بیماری‌ها</h3>
<p>مدیریت دقیق دیابت، فشار خون و کلسترول با نظارت پزشک و مصرف منظم داروها.</p>
👣
<h3>مراقبت از پاها</h3>
<p>بررسی روزانه پاها برای تشخیص زودهنگام زخم‌ها، تغییرات پوستی و سایر علائم.</p>
<h2>جمع‌بندی نهایی</h2>
<p>گرفتگی عروق پا یک بیماری جدی و پیشرونده است که نباید نادیده گرفته شود. این بیماری می‌تواند منجر به عوارض خطرناک مانند زخم‌های مزمن، عفونت، گنگرن و حتی قطع عضو شود. اما خبر خوب این است که با تشخیص زودهنگام و درمان مناسب، می‌توان از این عوارض پیشگیری کرد و کیفیت زندگی را حفظ نمود.</p>
<p>اگر علائمی مانند درد هنگام راه رفتن، سردی پاها، تغییر رنگ پوست یا زخم‌های دیر‌درمان دارید، نباید زمان را از دست بدهید. مراجعه به متخصص عروق می‌تواند به تشخیص دقیق و شروع درمان مناسب کمک کند. به یاد داشته باشید که هرچه بیماری زودتر تشخیص داده شود، گزینه‌های درمانی بیشتر و نتایج بهتری در انتظار شما خواهد بود.</p>
<p>سلامت عروق شما، سرمایه‌ای ارزشمند است که باید از آن مراقبت کنید. با تغییر سبک زندگی، کنترل بیماری‌های زمینه‌ای و مراجعه منظم به پزشک، می‌توانید از ابتلا به این بیماری پیشگیری کرده یا در صورت ابتلا، آن را به خوبی مدیریت کنید.</p>
<h2>
<a href="/">همراه کلینیک</a> &#8211; مرکز تخصصی درمان بیماری‌های عروقی</h2>
<p>✅ چرا همراه کلینیک را انتخاب کنید؟</p>
<ul>
<li>تیم پزشکی مجرب و متخصص در زمینه بیماری‌های عروقی</li>
<li>تشخیص دقیق با تجهیزات پیشرفته و مدرن</li>
<li>ارائه طیف کاملی از درمان‌ها از غیرجراحی تا جراحی</li>
<li>مشاوره تخصصی و پیگیری مداوم بیماران</li>
<li>محیطی آرام و حرفه‌ای برای راحتی شما</li>
</ul>
<p>📞 <a>همین حالا برای رزرو نوبت تماس بگیرید</a>
</p>
<p>
<strong>⚠️ توجه:</strong> این مقاله صرفاً جنبه آموزشی و اطلاع‌رسانی دارد و جایگزین مشاوره پزشکی نیست، برای تشخیص و درمان مناسب حتماً به پزشک متخصص مراجعه کنید.</p>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/#respond">لغو نظر</a>
</h3>' WHERE path = '/ایا-گرفتگی-عروق-پا-خطرناک-است/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
23 خرداد 1405
</li>
<li>
9:06 ق.ظ
</li>
<li>
<a href="/category/شیمی-درمانی/">شیمی درمانی</a>
</li>
</ul>
<p>بعضی افراد تصور می‌کنند روز شیمی درمانی بهتر است با معده خالی به مرکز درمانی مراجعه کنند اما در بیشتر موارد چنین توصیه‌ای وجود ندارد و بسیاری از متخصصان تغذیه معتقدند خوردن یک وعده سبک و قابل هضم می‌تواند به حفظ انرژی بدن کمک کند و حتی در برخی افراد شدت تهوع را کمتر کند، البته شرایط بیماران یکسان نیست و ممکن است پزشک معالج برای برخی افراد دستور متفاوتی داشته باشد ولی با این حال اگر محدودیت خاصی وجود نداشته باشد حذف کامل صبحانه معمولاً انتخاب ایده‌آلی نیست.</p>
<p>
<strong>پیشنهاد میشود قبل از شیمی‌درمانی این مواد غذایی را برای صبحانه مصرف کنید(غذاهای سبک و مغذی که انرژی و پروتئین کافی را برای بدن فراهم میکنند):</strong>
</p>
<p>• تخم‌مرغ آب‌پز یا املت کم‌چرب<br>
• نان سبوس‌دار یا غلات کامل<br>
• ماست یا پنیر کم‌چرب<br>
• میوه‌های تازه مانند موز و سیب<br>
• مغزها مانند بادام و گردو<br>
• شیر، شیر سویا یا شیر بدون لاکتوز<br>
• سوپ مرغ یا فرنی برای افراد کم‌اشتها<br>
• نوشیدن آب و مایعات کافی</p>
<p>بهتر است قبل از شیمی‌درمانی از غذاهای چرب، سنگین و پرادویه پرهیز شود.</p>
<h2>چرا خوردن صبحانه قبل از درمان اهمیت دارد؟</h2>
<p>شیمی درمانی می‌تواند با عوارضی مانند ضعف، خستگی، کاهش اشتها یا ناراحتی‌های گوارشی همراه باشد و وقتی بدن چند ساعت تحت درمان قرار می‌گیرد، داشتن مقداری انرژی ذخیره می‌تواند تحمل این فرایند را آسان‌تر کند، تجربه بسیاری از بیماران نشان می‌دهد که مراجعه به جلسه درمان با معده کاملاً خالی همیشه احساس بهتری ایجاد نمی‌کندو  بعضی افراد حتی گزارش می‌کنند که گرسنگی باعث تشدید حالت تهوع یا احساس ضعف در طول درمان شده است.</p>
<p>به همین دلیل معمولاً توصیه می‌شود پیش از مراجعه یک وعده سبک و متعادل مصرف شود.</p>
<h3>یک صبحانه مناسب چه ویژگی‌هایی دارد؟</h3>
<p>انتخاب غذاهای مناسب اهمیت زیادی دارد و وعده‌ای که قبل از شروع درمان مصرف می‌شود بهتر است:</p>
<ul>
<li>هضم آسانی داشته باشد.</li>
<li>حاوی مقداری پروتئین باشد.</li>
<li>بیش از حد چرب یا سنگین نباشد.</li>
<li>حجم متعادلی داشته باشد.</li>
<li>همراه با مایعات کافی مصرف شود.</li>
<li>غذاهای بسیار پرادویه یا سرخ‌شده ممکن است در برخی افراد باعث ناراحتی معده شوند و به همین دلیل بهتر است گزینه‌های ساده‌تر را انتخاب کنید.</li>
</ul>
<h3>چند پیشنهاد مناسب برای صبح روز درمان</h3>
<p>
<strong>تخم‌مرغ آب‌پز و نان تست</strong>
</p>
<p>یک عدد تخم‌مرغ آب‌پز در کنار نان تست ساده می‌تواند ترکیب خوبی از پروتئین و کربوهیدرات فراهم کند و این وعده معمولاً احساس سنگینی ایجاد نمی‌کند و برای افرادی که اشتهای زیادی ندارند هم گزینه قابل قبولی است.</p>
<p>
<strong>ماست همراه با موز یا سیب</strong>
</p>
<p>اگر به دنبال یک صبحانه سبک هستید ماست ساده در کنار میوه می‌تواند انتخاب مناسبی باشد، موز به دلیل بافت نرم و هضم آسان یکی از میوه‌هایی است که بسیاری از بیماران راحت‌تر آن را تحمل می‌کنند.</p>
<p>
<strong>اوتمیل یا فرنی جو دوسر</strong>
</p>
<p>جو دوسر علاوه بر تأمین انرژی معمولاً معده را اذیت نمی‌کند و بعضی افراد کمی شیر یا مقدار اندکی کره بادام‌زمینی به آن اضافه می‌کنند تا ارزش غذایی وعده بیشتر شود.</p>
<p>
<strong>نان تست و کره بادام‌زمینی</strong>
</p>
<p>در صورتی که محدودیت غذایی خاصی وجود نداشته باشد این ترکیب می‌تواند انرژی نسبتاً پایداری در اختیار بدن قرار دهد و فقط بهتر است مقدار کره بادام‌زمینی متعادل باشد تا وعده بیش از حد سنگین نشود.</p>
<p>
<strong>سوپ مرغ سبک</strong>
</p>
<p>همه افراد صبح‌ها تمایل به خوردن غذاهای رایج صبحانه ندارند، در چنین شرایطی یک کاسه سوپ مرغ سبک به‌ ویژه اگر کمی برنج هم داشته باشد می‌تواند انتخاب مناسبی باشد و این غذا هم مایعات بدن را تأمین می‌کند و هم به حفظ انرژی کمک می‌کند.</p>
<h3>چه غذاهایی بهتر است کنار گذاشته شوند؟</h3>
<ul>
<li>غذاهای سرخ‌شده</li>
<li>فست‌فودها</li>
<li>خوراکی‌های بسیار چرب</li>
<li>غذاهای تند و پرادویه</li>
<li>نوشیدنی‌های بسیار شیرین</li>
<li>همچنین خوردن حجم زیادی از غذا در یک وعده معمولاً ایده خوبی نیست، حتی یک غذای سالم هم اگر بیش از اندازه مصرف شود ممکن است باعث احساس سنگینی شود.</li>
</ul>
<h2>قبل از شیمی درمانی چه بنوشیم؟</h2>
<p>نوشیدن آب را نباید فراموش کرد حتی کم‌آبی خفیف هم می‌تواند خستگی و بی‌حالی را بیشتر کند همچنین در کنار آب برخی افراد از آب سیب رقیق‌شده یا دمنوش‌های ملایم استفاده می‌کنند و بهتر است مایعات به‌تدریج مصرف شوند و از نوشیدن حجم زیادی از نوشیدنی در مدت کوتاه خودداری شود؛ زیرا این موضوع در بعضی بیماران احساس تهوع را بیشتر می‌کند.</p>
<h4>اگر اشتها نداشته باشیم چه؟</h4>
<p>کم شدن اشتها یکی از مشکلات رایج در دوران درمان است و در چنین شرایطی لازم نیست خودتان را مجبور به خوردن یک وعده کامل کنید، گاهی چند لقمه نان تست، مقداری ماست یا حتی یک موز می‌تواند از ناشتا ماندن بهتر باشد و هدف اصلی این است که معده کاملاً خالی نباشد و بدن تا حدی انرژی مورد نیاز خود را دریافت کند، البته واکنش افراد به شیمی درمانی متفاوت است و غذایی که برای یک بیمار مناسب است ممکن است برای فرد دیگری چندان قابل تحمل نباشد، به همین دلیل بهتر است علاوه بر توصیه‌های عمومی، نظر پزشک و متخصص تغذیه را نیز در اولویت قرار دهید.</p>
<h4>جمع‌بندی</h4>
<p>در بیشتر موارد خوردن یک صبحانه سبک و متعادل پیش از شیمی درمانی انتخاب بهتری نسبت به ناشتا بودن است، غذاهایی مانند تخم‌مرغ آب‌پز، ماست و میوه، جو دوسر یا سوپ سبک معمولاً گزینه‌های مناسبی محسوب می‌شوند و در مقابل خوراکی‌های چرب، سنگین و پرادویه ممکن است باعث ناراحتی بیشتر شوند، اگر اشتهای کمی دارید نگران خوردن یک وعده کامل نباشید حتی مقدار کمی غذای سبک نیز می‌تواند به حفظ انرژی و تحمل بهتر روند درمان کمک کند، امیدواریم این مطلب از <a href="/">
<b>همراه کلینیک</b>
</a> برای شما مفید و کاربردی بوده باشد و توانسته باشد پاسخ مناسبی به پرسش‌های شما ارائه دهد، در صورت نیاز به دریافت اطلاعات بیشتر یا مشاوره تخصصی می‌توانید از طریق راه‌های ارتباطی همراه کلینیک با ما در تماس باشید.</p>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/#respond">لغو نظر</a>
</h3>' WHERE path = '/بهترین-صبحانه-قبل-از-شیمی-درمانی/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
10 تیر 1405
</li>
<li>
1:49 ب.ظ
</li>
<li>
<a href="/category/heart-diseases/">بیماری‌های قلبی</a>
</li>
</ul>
<h2>تشخیص آریتمی قلبی در خانه- علائم هشداردهنده + راهنمای مراجعه به پزشک</h2>
<p>
<strong>⚠️ نکته بسیار مهم:</strong>
<strong>تشخیص آریتمی قلبی در خانه</strong> به صورت قطعی و علمی <strong>امکان‌پذیر نیست</strong>. آریتمی قلبی یک وضعیت پزشکی جدی است که فقط با استفاده از تجهیزات تخصصی مانند نوار قلب (ECG) و تحت نظر پزشک متخصص قلب و عروق قابل تشخیص است. اما شما می‌توانید <strong>علائم و نشانه‌های آریتمی قلب</strong> را در خانه شناسایی کنید و در صورت مشاهده، سریعاً به پزشک مراجعه کنید. در این مقاله، به شما کمک می‌کنیم تا <strong>ضربان قلب نامنظم</strong> را بشناسید و بدانید چه زمانی باید نگران شوید و به پزشک مراجعه کنید.</p>
<strong>💡 یادآوری:</strong> البته نباید این نکته را فراموش کنیم که کنترل بیش از حد و استفاده بی رویه از ابزار های تشخیص خانگی می‌تواند منجر به افزایش اضطراب و استرس شود و به همین علت توسط پزشکان توصیه نمی‌شود.
<h2>فهرست مطالب</h2>
<ul>
<li>
<a>۱. آریتمی قلبی چیست؟</a>
</li>
<li>
<a>۲. چرا تشخیص آریتمی در خانه ممکن نیست؟</a>
</li>
<li>
<a>۳. علائم و نشانه‌های آریتمی قلبی</a>
</li>
<li>
<a>۴. ابزارهای خانگی پایش ضربان قلب (و محدودیت‌های آن‌ها)</a>
</li>
<li>
<a>۵. چه زمانی باید فوراً به پزشک مراجعه کرد؟ (علائم هشدار)</a>
</li>
<li>
<a>۶. روش‌های تشخیص پزشکی آریتمی</a>
</li>
<li>
<a>۷. عوامل خطر و پیشگیری</a>
</li>
<li>
<a>۸. نکات مهم برای ثبت علائم قبل از مراجعه به پزشک</a>
</li>
<li>
<a>۹. سؤالات متداول (FAQ)</a>
</li>
</ul>
<h2>آریتمی قلبی چیست؟</h2>
<p>آریتمی قلبی (Arrhythmia) به هرگونه نامنظمی در ریتم ضربان قلب گفته می‌شود. قلب طبیعی با ریتم منظم و سرعت مشخصی می‌تپد (معمولاً ۶۰ تا ۱۰۰ ضربه در دقیقه در حالت استراحت). در آریتمی، این ریتم مختل می‌شود و قلب ممکن است:</p>
<h4>خیلی سریع بزند</h4>
<p>تاکی‌کاردی (Tachycardia): بیش از ۱۰۰ ضربه در دقیقه</p>
<h4>خیلی کند بزند</h4>
<p>برادی‌کاردی (Bradycardia): کمتر از ۶۰ ضربه در دقیقه</p>
<h4>نامنظم بزند</h4>
<p>برای مثال فیبریلاسیون دهلیزی (AFib)، ضربان‌های اضافی یا پرش‌دار</p>
<h4>⏸ وقفه داشته باشد</h4>
<p>بلوک قلبی یا توقف موقت ضربان</p>
<p>
<strong>💡 نکته مهم:</strong>
</p>
<p>برخی آریتمی‌ها کم خطر هستند و احتیاجی به درمان تهاجمی ندارند، اما برخی دیگر می‌توانند خطرناک و حتی تهدیدکننده زندگی باشند. بنابراین تشخیص نوع آریتمی بسیار مهم است و فقط پزشک می‌تواند این کار را انجام دهد.</p>
<h2>چرا تشخیص آریتمی در خانه ممکن نیست؟</h2>
<p>بسیاری از افراد تصور می‌کنند که می‌توانند <strong>تشخیص خانگی آریتمی</strong> انجام دهند، اما این تصور اشتباه است. دلایل زیر نشان می‌دهد چرا تشخیص قطعی آریتمی فقط در محیط پزشکی امکان‌پذیر است:</p>
<p>
<strong>۱. نیاز به نوار قلب (ECG/EKG)</strong>
</p>
<p>تشخیص قطعی آریتمی نیاز به ثبت فعالیت الکتریکی قلب با دستگاه ECG دارد. دستگاه باید سیگنال‌های قلب را ثبت کند و متخصص قلب و عروق آن را تحلیل کند. بدون ثبت ecg یا هولتر نمی‌توان نوع آریتمی رو تشخیص داد.</p>
<p>
<strong>۲. انواع مختلف آریتمی علائم مشابه دارند</strong>
</p>
<p>بسیاری از آریتمی‌های مختلف (مانند AFib، تاکی‌کاردی بطنی، انقباضات زودرس) علائم مشابهی دارند. فقط با ecg ویا هولتر مونیتورینگ ریتم می‌توان تشخیص داد که کدام نوع آریتمی وجود دارد.</p>
<p>
<strong>۳. برخی آریتمی‌ها بدون علامت هستند</strong>
</p>
<p>بسیاری از آریتمی‌ها هیچ علامتی ندارند و فقط با ecg ویا هولتر مونیتورینگ ریتم قابل تشخیص هستند. بنابراین حتی اگر احساس خوبی دارید، ممکن است آریتمی داشته باشید.</p>
<p>
<strong>۴. تفسیر نیاز به تخصص دارد</strong>
</p>
<p>حتی اگر دستگاه ECG داشته باشید، تفسیر نتایج نیاز به تخصص پزشک قلب و عروق دارد. تفسیر اشتباه می‌تواند خطرناک باشد.</p>
<p>
<strong>۵. ابزارهای خانگی محدودیت دارند</strong>
</p>
<p>ساعت‌های هوشمند و اپلیکیشن‌های موبایل فقط می‌توانند ضربان قلب را اندازه‌گیری کنند، نه فعالیت الکتریکی قلب را. آن‌ها نمی‌توانند نوع آریتمی را تشخیص دهند.</p>
<p>
<strong>✅ آنچه در خانه می‌توانید انجام دهید:</strong>
</p>
<p>شما می‌توانید <strong>علائم و نشانه‌های آریتمی قلبی</strong> را شناسایی کنید، ضربان قلب خود را پایش کنید و در صورت مشاهده هرگونه نامنظمی، به پزشک مراجعه کنید. اما تشخیص قطعی فقط توسط پزشک امکان‌پذیر است.</p>
<h2>علائم و نشانه‌های آریتمی قلبی</h2>
<p>اگرچه <strong>تشخیص آریتمی قلبی در خانه</strong> ممکن نیست، اما می‌توانید <strong>نشانه های آریتمی قلبی</strong> را شناسایی کنید. این علائم ممکن است نشان‌دهنده آریتمی باشند و نیاز به بررسی پزشکی دارند:</p>
<p>
<strong>💓 احساس تپش قلب (Palpitations)</strong>
</p>
<p>احساس می‌کنید قلب شما:</p>
<ul>
<li>خیلی سریع می‌زند</li>
<li>خیلی کند می‌زند</li>
<li>نامنظم می‌زند (پرش دارد)</li>
<li>می‌لرزد یا می‌کوبد</li>
<li>انگار یک ضربه را از دست می‌دهد</li>
</ul>
<p>
<strong>😰 سرگیجه و سبکی سر</strong>
</p>
<p>احساس سرگیجه، سبکی سر یا احساس اینکه ممکن است غش کنید. این علامت نشان می‌دهد که قلب به اندازه کافی خون به مغز نمی‌رساند.</p>
<p>
<strong>😵 غش کردن (Syncope)</strong>
</p>
<p>از دست دادن هوشیاری یا غش کردن. این یک علامت جدی است و نیاز به بررسی فوری پزشکی دارد.</p>
<p>
<strong>😮‍💨 تنگی نفس</strong>
</p>
<p>تنگی نفس می‌تواند نشانه عدم پمپاژ کافی خون توسط قلب باشد. احساس مشکل در تنفس، به ویژه هنگام فعالیت یا حتی در حالت استراحت.</p>
<p>
<strong>💪 ضعف و خستگی</strong>
</p>
<p>احساس خستگی غیرعادی، ضعف عمومی یا کاهش توانایی انجام فعالیت‌های روزمره.</p>
<p>
<strong>😣 درد یا ناراحتی قفسه سینه</strong>
</p>
<p>احساس فشار، سنگینی، درد یا ناراحتی در قفسه سینه. این علامت می‌تواند نشان‌دهنده مشکلات جدی قلبی باشد.</p>
<p>
<strong>😰 تعریق شدید</strong>
</p>
<p>تعریق ناگهانی و شدید بدون دلیل واضح (مانند ورزش یا گرما). این علامت به ویژه اگر با سایر علائم همراه باشد، نگران‌کننده است.</p>
<p>
<strong>😨 اضطراب و بی‌قراری</strong>
</p>
<p>احساس اضطراب ناگهانی، بی‌قراری یا ترس بدون دلیل واضح. برخی آریتمی‌ها می‌توانند باعث این احساس شوند.</p>
<p>
<strong>💡 نکته مهم:</strong>
</p>
<p>این علائم ممکن است ناشی از آریتمی باشند، اما می‌توانند دلایل دیگری هم داشته باشند (مانند استرس، کم‌آبی، کم‌خونی، مشکلات تیروئید و&#8230;). فقط پزشک می‌تواند علت واقعی را تشخیص دهد.</p>
<h2>⌚ ابزارهای خانگی پایش ضربان قلب (و محدودیت‌های آن‌ها)</h2>
<p>ابزارهایی برای پایش ضربان قلب در خانه وجود دارند، اما باید محدودیت‌های آن‌ها را بشناسید:</p>
<table>
<thead>
<tr>
<th>ابزار</th>
<th>چه کاری انجام می‌دهد</th>
<th>محدودیت‌ها</th>
</tr>
</thead>
<tbody>
<tr>
<td>ساعت‌های هوشمند (Apple Watch, Samsung)</td>
<td>اندازه‌گیری ضربان قلب و تشخیص نامنظمی</td>
<td>فقط AFib را تشخیص می‌دهد، نه سایر آریتمی‌ها</td>
</tr>
<tr>
<td>دستگاه‌های فشار خون دیجیتال</td>
<td>نمایش ضربان قلب و تشخیص نامنظمی</td>
<td>دقت محدود، نمی‌تواند نوع آریتمی را تشخیص دهد</td>
</tr>
<tr>
<td>اپلیکیشن‌های موبایل</td>
<td>ثبت ضربان قلب با دوربین یا سنسور</td>
<td>دقت بسیار محدود، جایگزین ECG نیست</td>
</tr>
<tr>
<td>دستگاه‌های پوشیدنی ECG شخصی (مانند KardiaMobile)</td>
<td>ثبت نوار قلب تک‌کاناله</td>
<td>محدود به چند آریتمی خاص، نیاز به تفسیر پزشک</td>
</tr>
<tr>
<td>پالس‌اکسیمتر</td>
<td>اندازه‌گیری ضربان قلب و اشباع اکسیژن</td>
<td>فقط ضربان را نشان می‌دهد، نه ریتم</td>
</tr>
</tbody>
</table>
<p>
<strong>⛔ هشدار مهم:</strong>
</p>
<p>هیچ‌یک از این ابزارها نمی‌توانند جایگزین تشخیص پزشکی شوند. اگر این ابزارها نامنظمی را تشخیص دادند، حتماً به پزشک مراجعه کنید. اگر این ابزارها چیزی نشان ندادند اما شما علائم دارید، باز هم به پزشک مراجعه کنید. ابزارهای خانگی می‌توانند اشتباه کنند (هم مثبت کاذب و هم منفی کاذب).</p>
<p>
<strong>✅ استفاده صحیح از ابزارهای خانگی:</strong>
</p>
<ul>
<li>برای پایش عمومی ضربان قلب مفید هستند</li>
<li>می‌توانند به شما آگاهی بدهند که ضربان قلبتان نامنظم است</li>
<li>می‌توانید نتایج را به پزشک نشان دهید</li>
<li>اما هرگز برای تشخیص قطعی یا تصمیم‌گیری درمانی استفاده نکنید</li>
<li>
<strong>محدودیت ساعت‌های هوشمند:</strong> ممکن است به صورت کاذب پارازیت را آریتمی تشخیص دهد و یا آریتمی را نادیده بگیرد. (حساس و اختصاصی نمیباشد)</li>
</ul>
<h2>چه زمانی باید فوراً به پزشک مراجعه کرد؟ (علائم هشدار)</h2>
<p>اگر هر یک از علائم زیر را تجربه کردید، <strong>فوراً</strong> به پزشک مراجعه کنید یا با اورژانس (۱۱۵) تماس بگیرید:</p>
<p>
<strong>🔴 علائم اورژانسی (فوراً با ۱۱۵ تماس بگیرید):</strong>
</p>
<ul>
<li>درد شدید قفسه سینه که بیش از چند دقیقه طول بکشد</li>
<li>تنگی نفس شدید</li>
<li>غش کردن یا از دست دادن هوشیاری</li>
<li>ضعف ناگهانی در یک سمت بدن</li>
<li>مشکل در تکلم</li>
<li>ضربان قلب بسیار سریع (بیش از ۱۵۰ ضربه در دقیقه) که با استراحت بهتر نمی‌شود</li>
<li>ضربان قلب بسیار کند (کمتر از ۴۰ ضربه در دقیقه) همراه با سرگیجه</li>
</ul>
<p>🚑 اگر این علائم را دارید، فورا به نزدیکترین مرکز درمانی مجهز مراجعه کنید.</p>
<p>
<strong>🟡 علائم نیاز به مراجعه سریع (ظرف ۲۴ تا ۴۸ ساعت):</strong>
</p>
<ul>
<li>تپش قلب مکرر یا مداوم</li>
<li>احساس ضربان نامنظم قلب</li>
<li>سرگیجه‌های مکرر</li>
<li>خستگی غیرعادی و مداوم</li>
<li>تنگی نفس خفیف تا متوسط</li>
<li>تورم پاها یا مچ پا</li>
<li>کاهش توانایی انجام فعالیت‌های روزمره</li>
</ul>
<p>
<strong>🔵 علائم نیاز به بررسی روتین (ظرف یک هفته):</strong>
</p>
<ul>
<li>تپش قلب گاه‌به‌گاه که نگران‌کننده است</li>
<li>احساس ضربان قلب در گلو یا گردن</li>
<li>ضربان قلب کمی نامنظم به نظر می‌رسد</li>
<li>سابقه خانوادگی آریتمی یا بیماری قلبی</li>
<li>اگر بیش از ۶۵ سال سن دارید و تا به حال چکاپ قلبی نداشته‌اید</li>
<li>اگر کلسترول بالا دارید</li>
<li>اگر دیابت دارید</li>
<li>اگر مبتلا به فشار خون بالا هستید</li>
<li>اگر سابقه مصرف دخانیات دارید</li>
</ul>
<p>
<strong>💡 نکته مهم:</strong>
</p>
<p>اگر شک دارید، بهتر است احتیاط کنید و به پزشک مراجعه کنید. تشخیص زودهنگام آریتمی می‌تواند زندگی شما را نجات دهد. بهتر است احتیاط کنید و بررسی کنید تا اینکه نادیده بگیرید و پشیمان شوید.</p>
<h2>روش‌های تشخیص پزشکی آریتمی</h2>
<p>پزشک برای تشخیص آریتمی از روش‌های زیر استفاده می‌کند:</p>
<p>
<strong>۱. نوار قلب (ECG/EKG)</strong>
</p>
<p>رایج‌ترین و مهم‌ترین تست برای تشخیص آریتمی. فعالیت الکتریکی قلب را ثبت می‌کند. معمولاً در چند دقیقه انجام می‌شود.</p>
<p>
<strong>۲. هولتر مانیتورینگ (Holter Monitor)</strong>
</p>
<p>دستگاهی کوچک که به مدت ۲۴ تا ۴۸ ساعت (یا بیشتر) به بدن متصل می‌شود و نوار قلب را به صورت مداوم ثبت می‌کند. برای آریتمی‌هایی که گهگاه رخ می‌دهند عالی است.</p>
<p>
<strong>۳. مانیتورینگ رویداد (Event Monitor)</strong>
</p>
<p>مشابه هولتر است اما برای مدت طولانی‌تری (چند هفته) استفاده می‌شود و فقط زمانی که بیمار دکمه را فشار می‌دهد یا دستگاه خودکار آریتمی را حس می‌کند، ثبت انجام می‌شود.</p>
<p>
<strong>۴. اکوکاردیوگرام (Echo)</strong>
</p>
<p>سونوگرافی قلب که ساختار و عملکرد پمپاژ قلب را بررسی می‌کند تا علل زمینه‌ای آریتمی مشخص شود.</p>
<p>
<strong>۵. تست ورزش (Stress Test)</strong>
</p>
<p>ثبت نوار قلب هنگام فعالیت بدنی (دویدن روی تردمیل) برای بررسی آریتمی‌هایی که با ورزش تحریک می‌شوند.</p>
<h2>عوامل خطر و پیشگیری</h2>
<p>برخی عوامل خطر ابتلا به آریتمی را افزایش می‌دهند. مدیریت این عوامل می‌تواند به پیشگیری کمک کند:</p>
<p>
<strong>❤️ بیماری‌های قلبی</strong>
</p>
<p>سابقه سکته، نارسایی قلبی یا مشکلات دریچه‌ای.</p>
<p>
<strong>🩸 فشار خون بالا</strong>
</p>
<p>فشار خون کنترل نشده خطر آریتمی را افزایش می‌دهد.</p>
<p>
<strong>🚬 مصرف دخانیات و الکل</strong>
</p>
<p>سیگار و مصرف زیاد الکل محرک‌های قوی آریتمی هستند.</p>
<p>
<strong>☕ کافئین زیاد</strong>
</p>
<p>مصرف بیش از حد قهوه یا نوشیدنی‌های انرژی‌زا.</p>
<p>
<strong>😰 استرس مزمن</strong>
</p>
<p>استرس و اضطراب طولانی‌مدت بر ریتم قلب اثر می‌گذارد.</p>
<p>
<strong>⚖️ چاقی و دیابت</strong>
</p>
<p>وزن بالا و قند خون کنترل نشده از عوامل خطر مهم هستند.</p>
<h2>نکات مهم برای ثبت علائم قبل از مراجعه به پزشک</h2>
<p>برای کمک به پزشک در تشخیص دقیق‌تر، این اطلاعات را یادداشت کنید:</p>
<ul>
<li>
<strong>زمان شروع:</strong> اولین بار کی این علائم را حس کردید؟</li>
<li>
<strong>مدت زمان:</strong> هر episode چقدر طول می‌کشد؟ (ثانیه، دقیقه، ساعت)</li>
<li>
<strong>فرکانس:</strong> چند بار در روز یا هفته تکرار می‌شود؟</li>
<li>
<strong>محرک‌ها:</strong> آیا بعد از غذا، ورزش، استرس یا مصرف کافئین رخ می‌دهد؟</li>
<li>
<strong>علائم همراه:</strong> آیا سرگیجه، درد قفسه سینه یا تنگی نفس هم دارید؟</li>
<li>
<strong>ضربان قلب:</strong> اگر ساعت هوشمند دارید، عدد ضربان قلب را در لحظه حمله یادداشت کنید.</li>
</ul>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/تشخیص-آریتمی-قلبی-در-خانه/#respond">لغو نظر</a>
</h3>' WHERE path = '/تشخیص-آریتمی-قلبی-در-خانه/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
19 بهمن 1404
</li>
<li>
10:41 ق.ظ
</li>
<li>
<a href="/category/شیمی-درمانی/">شیمی درمانی</a>
</li>
</ul>
<p>داروهای شیمی‌درمانی به گونه‌ای طراحی شده‌اند تا سلول‌هایی که سرعت تکثیر بالایی دارند (مانند سلول‌های سرطانی) را هدف قرار دهند. اما سلول‌های مغز استخوان (که مسئول تولید گلبول‌های سفید و قرمز هستند) هم دقیقا همین ویژگی را دارند و به سرعت تکثیر می‌شوند.</p>
<p>وقتی تولید گلبول‌های سفید کاهش می‌یابد، بدن در وضعیتی به نام نوتروپنی قرار می‌گیرد. در این حالت، بدن شما در برابر عفونت‌ها آسیب‌پذیر می‌شود. حتی یک سرماخوردگی ساده که قبلا برایتان اهمیتی نداشت، حالا می‌تواند دردسرساز شود. بنابراین، هدف اصلی ما در دوران نقاهت، پیشگیری از عفونت و تغذیه سلول‌ها برای بازسازی سریع‌تر است.</p>
<h2>
<b>تغذیه مناسب برای بازسازی سیستم ایمنی</b>
</h2>
<p>احتمالا شنیده‌اید که می‌گویند شما آن چیزی هستید که می‌خورید. این جمله بعد از شیمی‌درمانی صد برابر مهم‌تر می‌شود. بدن شما برای ترمیم بافت‌های آسیب‌دیده و ساخت گلبول‌های جدید، نیاز به تغذیه مناسب دارد که مهم‌ترین آنها شامل:</p>
<h3>
<b>1. پروتئین‌ها</b>
</h3>
<p>پروتئین مهم‌ترین ماده برای ترمیم بافت‌ها و تقویت سیستم ایمنی است. بعد از شیمی‌درمانی، عضلات ممکن است تحلیل رفته باشند و سیستم ایمنی ضعیف شده باشد. به همین دلیل، نیاز است مواردی مانند گوشت مرغ، ماهی، بوقلمون، تخم‌مرغ (حتما کاملا پخته)، حبوبات (نخود و لوبیا) و سویا را باید در برنامه‌ریزی تغذیه خود قرار دهید.</p>
<p>
<b>نکته: </b>اگر اشتها ندارید، وعده‌های غذایی را کوچک و تعداد آن‌ها را زیاد کنید. مثلا به جای 3 وعده بزرگ، 6 وعده کوچک بخورید.</p>
<h3>
<b>۲. ویتامین‌ها و آنتی‌اکسیدان‌ها</b>
</h3>
<ul>
<li>
<b>ویتامین C: </b>در مرکبات (پرتقال، لیمو)، فلفل دلمه‌ای و کیوی وجود دارد و ویتامین C ایمنی بدن را تقویت می‌کند.</li>
<li>
<b>ویتامین E:</b> آجیل‌ها (گردو، بادام) و تخمه‌ها منابع عالی هستند. (حتما از آجیل‌های بسته‎‌بندی و بهداشتی استفاده کنید تا خطر قارچ و آلودگی نداشته باشند).</li>
<li>
<b>ویتامین D:</b> سطح ویتامین D در اکثر بیماران پایین می‌آید. علاوه‌بر مکمل (با تجویز پزشک)، ماهی‌های چرب مثل سالمون منابع خوبی هستند.</li>
</ul>
<h3>
<b>۳. مایعات و هیدراتاسیون</b>
</h3>
<p>داروهای شیمی‌درمانی سمومی را در بدن به جا می‌گذارند که باید دفع شوند. برای همین، نوشیدن حداقل 8 تا 10 لیوان آب در روز به کلیه‌ها کمک می‌کند تا سموم را دفع کنند و از خشکی دهان و یبوست جلوگیری می‌کند.</p>
<p>اگر طعم آب برایتان ناخوشایند است (که یکی از عوارض شیمی‌درمانی است)، می‌توانید چند قطره لیموترش تازه یا خیار به آن اضافه کنید.</p>
<h2>
<b>چه چیزهایی نباید بخوریم؟</b>
</h2>
<p>در دوران تقویت سیستم ایمنی بعد از شیمی درمانی، نخوردن برخی غذاها به اندازه خوردن غذاهای مفید مهم محسوب می‌شود. زیرا سیستم ایمنی شما هنوز شکننده است و توانایی مبارزه با باکتری‌های موجود در غذاهای خام را ندارد. مهم‌ترین غذاهایی که در این دوران نباید مصرف شود شامل:</p>
<ol>
<li>
<b>غذاهای خام و نیم‌پز</b>: سوشی، استیک آبدار، تخم‌مرغ عسلی و ماهی دودی ممنوع است. همه چیز باید کاملا پخته شود (Well-done).</li>
<li>
<b>سبزیجات و میوه‌های خوب شسته نشده:</b> اگر نمی‌توانید پوست میوه را بگیرید یا سبزی را ضدعفونی کنید، آن را نخورید. کاهو و سبزی خوردن رستوران‌ها ریسک بالایی دارند.</li>
<li>
<b>لبنیات غیرپاستوریزه: </b>شیر یا پنیر محلی ممکن است حاوی باکتری باشند. فقط از لبنیات پاستوریزه و بسته‌بندی استفاده کنید.</li>
<li>
<b> قند و شکر مصنوعی:</b> شکر التهاب بدن را افزایش می‌دهد و سیستم ایمنی را سرکوب می‌کند. تا جای ممکن شیرینی‌جات قنادی و نوشابه را حذف کنید.</li>
</ol>
<h2>
<b>سبک زندگی و بهداشت</b>
</h2>
<p>تغذیه نیمی از ماجراست. نیم دیگر، سبک زندگی شماست. تقویت سیستم ایمنی بدن بعد از شیمی درمانی نیازمند تغییرات کوچکی در عادات روزانه است.</p>
<h3>
<b>خواب کافی</b>
</h3>
<p>هورمون‌های ترمیمی در خواب عمیق ترشح می‌شوند. سعی کنید شب‌ها 7 تا 9 ساعت خواب باکیفیت داشته باشید. اگر هم در طول روز خسته می‌شوید، چرت‌های کوتاه 20 دقیقه‌ای عالی است.</p>
<h3>
<b>مدیریت استرس</b>
</h3>
<p>استرس دشمن سیستم ایمنی است. زیرا وقتی مضطرب هستید، بدن هورمون کورتیزول ترشح می‌کند که مستقیما سیستم ایمنی را ضعیف می‌کند. برای حل آن، از تکنیک‌های تنفس عمیق، مدیتیشن، یا حتی گوش دادن به موسیقی ملایم استفاده کنید. حتی دور خودتان را با آدم‌های مثبت پر کنید و اخبار منفی را دنبال نکنید.</p>
<h3>
<b>ورزش ملایم</b>
</h3>
<p>منظور، ورزش‌های حرفه‌ای نیست. برای مثال، پیاده‌روی سبک، حرکات کششی یا یوگای ملایم ورزش‌های خوبی هستند که باعث بهبود گردش خون می‌شوند. این کار کمک می‌کند سلول‌های ایمنی سریع‌تر در بدن حرکت کنند و وظیفه‌شان را انجام دهند. اما یادتان باشد که هرگز خودتان را خسته نکنید و هر جا احساس ضعف کردید، بنشینید.</p>
<h3>
<b>بهداشت دهان و دندان</b>
</h3>
<p>یکی از عوارض شایع، زخم‌های دهانی (موکوزیت) است که می‌تواند راه ورود میکروب باشد. برای جلوگیری از این موضوع، استفاده از مسواک‌های بسیار نرم (Soft) مناسب است. همچنین، دهان خود را مرتب با محلول آب و نمک رقیق (یا دهان‌شویه‌های تجویز شده) بشویید تا محیط دهان ضدعفونی شود.</p>
<h2>
<b>روش‌های جلوگیری از عفونت</b>
</h2>
<p>در ماه‌های اول پس از شیمی‌درمانی، شما باید کمی وسواسی باشید. این وسواس برای سلامتی شما مهم است.</p>
<ul>
<li>
<b>شستن دست‌ها: </b>ساده‌ترین و مهم‌ترین قانون. قبل از غذا، بعد از دستشویی و بعد از تماس با سطوح عمومی، دست‌ها را 20 ثانیه با آب و صابون بشویید.</li>
<li>
<b>دوری از جمعیت:</b> سینما، کنسرت، پاساژهای شلوغ و اتوبوس مکان‌های پرخطری هستند. اگر مجبور به حضور هستید، حتما از ماسک استاندارد استفاده کنید.</li>
<li>
<b>دوری از افراد بیمار:</b> اگر نوه کوچک شما سرماخورده است یا دوستتان تب‌خال دارد، با کمال احترام از دیدار با آن‌ها خودداری کنید.</li>
<li>
<b>مراقبت از حیوانات خانگی: </b>اگر گربه یا سگ دارید، تمیز کردن خاک یا قفس آن‌ها را به فرد دیگری بسپارید. حیوانات می‌توانند ناقل انگل‌هایی باشند که برای شما خطرناک است.</li>
</ul>
<h2>
<b>گیاهان دارویی و مکمل‌ها</b>
</h2>
<ul>
<li>
<b>زنجبیل: </b>معمولا برای کاهش تهوع ایمن است و خاصیت ضدالتهابی دارد. می‌توانید آن را در چای دم کنید.</li>
<li>
<b>عسل: </b>اگر پاستوریزه و شرکتی باشد، برای رفع عفونت‌های گلو خوب است. اما عسل خام ممکن است حاوی هاگ‌های باکتری باشد.</li>
<li>
<b>مکمل‌ها: </b>هرگز، تاکید می‌کنیم هرگز بدون مشورت با انکولوژیست (پزشک سرطان) خود، مکمل‌های ویتامین یا گیاهی مصرف نکنید. دوز بالای برخی آنتی‌اکسیدان‌ها می‌تواند اثرات درمانی باقی‌مانده را خنثی کند.</li>
</ul>
<h2>
<b>چه زمانی باید نگران شویم؟ </b>
</h2>
<p>با تمام این مراقبت‌ها، گاهی عفونت رخ می‌دهد. از آنجا که سیستم ایمنی ضعیف است، ممکن است بدن شما واکنش شدیدی (مثل چرک زیاد) نشان ندهد. بنابراین، تب مهم‌ترین نشانه است.</p>
<p>اگر علائم زیر را داشتید، منتظر صبح نمانید و سریعا به اورژانس یا پزشک خود مراجعه کنید:</p>
<ol>
<li>تب بالای 38 درجه سانتی‌گراد.</li>
<li>لرز شدید یا تعریق زیاد.</li>
<li>تنگی نفس یا سرفه جدید.</li>
<li>سوزش هنگام ادرار.</li>
<li>قرمزی، تورم یا درد در محل ورود کاتتر (پورت) شیمی‌درمانی.</li>
</ol>
<p>در کل، باید توجه داشت که فرآیند تقویت سیستم ایمنی بدن بعد از شیمی درمانی یک شبه اتفاق نمی‌افتد. بدن شما برای بازسازی خود به زمان و مواد مغذی نیاز دارد. به خودتان سخت نگیرید. روزهای بد و خوب وجود خواهند داشت، اما روند کلی شما روبه بهبودی است. زیرا شما سخت‌ترین بخش را پشت سر گذاشته‌اید. حالا با رعایت این نکات، بدنتان را تقویت می‌کنید. همچنین، شما می‌توانید برای مشاوره بیشتر با کارشناسان ما تماس بگیرید.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/#respond">لغو نظر</a>
</h3>' WHERE path = '/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
6 آبان 1404
</li>
<li>
11:43 ق.ظ
</li>
<li>
<a href="/category/شیمی-درمانی/">شیمی درمانی</a>
</li>
</ul>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/حمایت-روانی-از-بیماران-در-زمان-شیمید/#respond">لغو نظر</a>
</h3>' WHERE path = '/حمایت-روانی-از-بیماران-در-زمان-شیمید/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
19 آذر 1404
</li>
<li>
11:42 ق.ظ
</li>
<li>
<a href="/category/طب-ایرانی-سبک-زندگی/">طب ایرانی (سبک زندگی)</a>
</li>
</ul>
<p>دوران شیمی‌درمانی یکی از مراحل حساس درمان سرطان است که در آن، تغذیه صحیح نقش بسیار مهمی در حفظ قوای جسمانی بیمار و مدیریت عوارض جانبی درمان ایفا می‌کند. در این دوران، سیستم گوارش ممکن است ضعیف شود و نیازهای بدن تغییر کند. این مقاله مجموعه‌ای از توصیه‌های کلی، پرهیزات غذایی و توضیحات ضروری برای بیماران مبتلا به سرطان در طول دوره شیمی‌درمانی است.</p>
خلاصه پرهیزات غذایی مهم
<p>در یک نگاه کلی، مصرف موارد زیر در این دوران باید با احتیاط و طبق دستورالعمل‌های ذکر شده باشد:</p>
<ul>
<li>
<p>انواع خاصی از گوشت (قرمز سنگین)</p>
</li>
<li>
<p>قند و شکر مصنوعی</p>
</li>
<li>
<p>نمک زیاد</p>
</li>
<li>
<p>مصرف خودسرانه ویتامین‌ها، آهن و اسید فولیک</p>
</li>
<li>
<p>مواد غذایی نفاخ</p>
</li>
<li>
<p>ترشیجات و غذاهای اسیدی</p>
</li>
<li>
<p>غذاهای غلیظ و دیرهضم</p>
</li>
<li>
<p>روغن دنبه و غذاهای سرخ‌کردنی</p>
توضیحات تکمیلی و راهنمای مصرف
<p>در ادامه، جزئیات مربوط به هر یک از گروه‌های غذایی و دلایل پرهیز یا توصیه آن‌ها شرح داده شده است.</p>
۱. مدیریت مصرف گوشت و پروتئین‌ها
<p>پروتئین برای ترمیم بافت‌ها ضروری است، اما نوع گوشت مصرفی اهمیت دارد:</p>
<ul>
<li>
<ul>
<li>
<p>
<b>گوشت‌های ممنوعه:</b> از مصرف گوشت گاو، گوساله و شتر باید اجتناب شود (به دلیل دیرهضم بودن).</p>
</li>
<li>
<p>
<b>گوشت‌های مجاز:</b> مصرف سایر گوشت‌ها مانند گوسفند، مرغ، خروس، بلدرچین، بوقلمون و ماهی مجاز است.</p>
<ul>
<li>
<p>
<i>نکته مهم:</i> مقدار کلی مصرف انواع گوشت‌ها نباید از ۳۵۰ تا ۵۰۰ گرم در هفته بیشتر شود.</p>
</li>
</ul>
</li>
<li>
<p>
<b>احشاء داخلی:</b> م</p>
</li>
<li>
<p>صرف جگر، دل و قلوه در این دوران به طور کلی توصیه نمی‌شود زیرا دیرهضم هستند و ممکن است خوب پخته نشوند.</p>
</li>
<li>
<p>
<b>بیماران دارای متاستاز:</b> در بیمارانی که متاستاز دارند (یعنی تومور به قسمت‌های دیگر بدنشان گسترش پیدا کرده است)، مصرف گوشت باید محدودتر و حدود ۳۵۰ گرم در هفته باشد.</p>
</li>
<li>
<p>
<b>فرآورده‌های گوشتی:</b> از مصرف گوشت‌های فرآوری‌شده مانند سوسیس، کالباس، تن ماهی یا ماهی نمک‌سود شده جداً پرهیز شود.</p>
</li>
</ul>
</li>
</ul>
۲. کنترل مصرف قند، شکر و نمک
<p>تعادل در مصرف طعم‌دهنده‌ها برای جلوگیری از مشکلات سلامتی دیگر ضروری است.</p>
<p>
<b>الف) قند و شکر:</b>
</p>
<ul>
<li>
<p>از مصرف قندهای ساده مانند قند و شکر باید پرهیز شود. توجه کنید که مقدار مورد نیاز قند برای اعمال حیاتی بدن، در قندهای طبیعی مانند میوه‌ها، عسل و بسیاری از مواد غذایی روزمره وجود دارد؛ لذا تا جای ممکن مصرف شکر، قندهای مصنوعی، مرباها و شیرینی‌جات محدود گردد.</p>
</li>
<li>
<p>حتی در مصرف قندهای طبیعی مانند عسل و شیره انگور نیز نباید افراط شود.</p>
</li>
</ul>
<p>
<b>ب) نمک:</b>
</p>
<ul>
<li>
<p>مصرف نمک باید محدود گردد. مقادیر مورد نیاز نمک برای اعمال حیاتی بدن در نان و بسیاری دیگر از مواد غذایی روزمره وجود دارد.</p>
</li>
<li>
<p>
<i>نکته:</i> غذا را با سایر چاشنی‌ها خوش‌طعم کنید؛ نباید غذای بیمار بی‌مزه یا بدطعم باشد.</p>
</li>
<li>
<p>از مصرف شوریجات مانند کلم شور، خیار شور و موارد مشابه پرهیز شود.</p>
</li>
<li>
<p>
<b>هشدار جدی در مورد نمک دریا:</b> از مصرف نمک‌هایی که تحت عنوان &#8220;نمک دریا&#8221; در عطاری‌ها عرضه می‌شود پرهیز شود، زیرا معمولاً تصفیه نشده‌اند و در بسیاری موارد حاوی فلزات سنگینی مانند سرب، آرسنیک و کادمیوم هستند که مصرف آن‌ها می‌تواند منجر به بروز سرطان یا مسمومیت شود.</p>
</li>
</ul>
۳. هشدار درباره مصرف مکمل‌ها و ویتامین‌ها
<ul>
<li>
<ul>
<li>
<p>بسیاری اوقات مشاهده می‌شود که افراد مبتلا به سرطان، خودسرانه انواع مختلف مکمل‌ها را مصرف می‌کنند که این کار اصلاً توصیه نمی‌شود. در مصرف خودسرانه مکمل‌ها، امکان تداخل با داروهای شیمی‌درمانی و همچنین افزایش احتمال متاستاز یا عود بیماری وجود دارد.</p>
</li>
<li>
<p>البته پزشک معالج بررسی می‌کند و در صورتی که کمبود ویتامین‌ها (مانند ویتامین D) یا مواد معدنی (مانند کلسیم و منیزیم) وجود داشته باشد، حتماً تحت نظر پزشک، ویتامین‌ها و مکمل‌های لازم تجویز می‌گردد.</p>
</li>
</ul>
</li>
</ul>
۴. مراقبت از سیستم گوارش (نفخ، ترشی و هضم)
<p>در دوران شیمی‌درمانی، قدرت هضم دستگاه گوارش ضعیف می‌شود؛ بنابراین رعایت نکات زیر ضروری است:</p>
<p>
<b>الف) مدیریت نفخ (نفاخات):</b>
</p>
<ul>
<li>
<p>مصرف مواد غذایی نفاخ موجب سوءهاضمه، تشدید تهوع و گاهاً تپش قلب و سرگیجه می‌گردد.</p>
</li>
<li>
<p>با این حال، مصرف غلات و حبوبات در برنامه غذایی بیماران یک تا سه وعده در هفته توصیه می‌شود. بنابراین، توصیه می‌شود که قبل از مصرف حتماً خیسانده شوند، نفخ آن‌ها گرفته شود و خیلی خوب پخته شوند. (حبوبات توصیه شده شامل نخود، لوبیا، ماش و یا دال عدس هستند).</p>
</li>
<li>
<p>مصرف آش رشته که علاوه بر حبوبات، رشته نیز دارد توصیه نمی‌شود.</p>
</li>
<li>
<p>
<b>اصول صحیح غذا خوردن:</b> خیلی از اوقات، نفخ بر اثر رعایت نکردن اصول صحیح غذا خوردن ایجاد می‌شود. یعنی فرد غذای نفاخ نخورده، ولی همراه غذای غیر نفاخ، آب، دوغ یا نوشابه نوشیده، همراه غذا سالاد خورده، و یا پرخوری/درهم‌خوری کرده است. تمام این موارد موجب ایجاد نفخ خواهد شد.</p>
</li>
<li>
<p>
<b>میوه‌ها و سبزیجات نفاخ:</b> مصرف برخی از میوه‌ها و سبزیجات موجب نفخ می‌گردد؛ مانند تره، ترب، شاهی، سیر خام، پیاز خام، هلو، زردآلو و&#8230; .</p>
</li>
</ul>
<p>
<b>ب) پرهیز از ترشیجات و اسیدی‌ها:</b>
</p>
<ul>
<li>
<p>از مصرف ترشیجات، خصوصاً همراه سرکه (مانند ترشی لیته) جداً خودداری شود.</p>
</li>
<li>
<p>از مصرف هرگونه ماده غذایی ترش و یا نوشیدنی ترش اجتناب گردد. مواد غذایی مانند رب انار، تمرهندی، غوره، آب نارنج یا لیموترش جهت خوش‌طعم کردن غذا به عنوان چاشنی می‌توانند به مقدار کم به غذا اضافه گردند، ولی میزان آن‌ها باید به قدری باشد که غذا ترش نشود و طعم ملایم داشته باشد.</p>
</li>
<li>
<p>از مصرف آب پرتقال، آب گریپ‌فروت، سایر مرکبات و همچنین آب انار ترش پرهیز شود.</p>
</li>
<li>
<p>مصرف میوه‌های نارس یا ترش مانند چاقاله بادام، گوجه سبز و آلو پرهیز شود.</p>
</li>
</ul>
<p>
<b>ج) غذاهای دیرهضم و غلیظ:</b>
</p>
<ul>
<li>
<ul>
<li>
<p>منظور از غذاهای دیرهضم، غذاهایی است که ترکیباتشان طوری است که هضم سختی دارند؛ مانند الویه، لازانیا، ماکارونی، پاستا، پیتزا (با پنیر زیاد و خصوصاً با خمیر کلفت)، کله‌پاچه، آش رشته و&#8230; .</p>
</li>
<li>
<p>همچنین مصرف انواع نوشیدنی‌های گازدار یا انرژی‌زا، چیپس، پفک و موارد مشابه توصیه نمی‌شود.</p>
</li>
</ul>
</li>
</ul>
۵. انتخاب روغن‌ها و چربی‌های مناسب
<ul>
<li>
<p>از مصرف روغن دنبه جداً اجتناب شود.</p>
</li>
<li>
<p>غذاها بیشتر به صورت خوراک، خورش و سوپ باشند و مصرف غذاهای سرخ‌کردنی محدود گردد.</p>
</li>
<li>
<p>از مصرف غذاهای چرب پرهیز شود.</p>
</li>
<li>
<p>
<b>بهترین روغن‌ها:</b> بهترین روغن، <b>روغن زیتون</b> است که اثرات سودمند آن در رژیم‌های مدیترانه‌ای در مطالعات متعدد نشان داده شده است. در درجه بعدی، <b>روغن کانولا (کلزا)</b> توصیه می‌شود. ارزش غذایی روغن کانولا به دلیل مقدار کم اسیدهای چرب اشباع و مقدار نسبتاً زیاد امگا ۹ (اسید اولئیک &#8211; حدود ۶۰ درصد) و امگا ۳ (آلفا لینولنیک &#8211; حدود ۱۰ درصد) است. کانولا بعد از روغن زیتون، از نظر مقدار امگا ۹ در بین چربی‌ها و روغن‌های نباتی خوراکی در مقام دوم قرار دارد. به جز روغن سویا، کانولا تنها روغن خوراکی است که مقدار قابل توجهی اسید امگا ۳ دارد.</p>
</li>
<li>
<p>
<i>نکته اختصاصی:</i> مصرف روغن سویا و کنجد در بیماران مبتلا به سرطان پستان که هورمون مثبت هستند، باید پرهیز شود.</p>
</li>
</ul>
۶. نکات ویژه درباره گردو و لبنیات
<ul>
<li>
<p>
<b>گردو:</b> مصرف گردو در دوره شیمی‌درمانی توصیه نمی‌شود زیرا ممکن است موجب ایجاد یا تشدید زخم‌های دهانی گردد.</p>
</li>
<li>
<p>
<b>لبنیات:</b> در دوره شیمی‌درمانی هضم ضعیف می‌شود، لذا مصرف خیلی از مواد غذایی که فرد قبلاً با آن‌ها مشکلی نداشته است، در این دوره باعث ایجاد نفخ، درد و ناراحتی (سوءهاضمه) می‌گردد. لبنیات از جمله مواد غذایی است که در این دوره مصرف آن با توجه به شرایط بیمار توصیه می‌شود، ولی به طور کلی می‌توان گفت که مصرف <b>پنیر کم‌چرب پروبیوتیک</b> و <b>ماست کم‌چرب پروبیوتیک</b> مجاز است، در حالیکه مصرف کشک و دوغ در این دوره توصیه نمی‌شود.</p>
</li>
</ul>
نکته پایانی و اطلاعات تماس
<p>این توصیه‌ها ماهیت کلی دارند. در صورتی که سوءتغذیه در دوره شیمی‌درمانی یا رادیوتراپی داشته باشید یا دچار عارضه‌ای شدید شدید، جهت گرفتن مشاوره تخصصی می‌توانید با کلینیک فوق تخصصی همراه تماس بگیرید.</p>
</li>
</ul>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/راهنمای-جامع-تغذیه-در-شیمی-درمانی/#respond">لغو نظر</a>
</h3>' WHERE path = '/راهنمای-جامع-تغذیه-در-شیمی-درمانی/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
26 مرداد 1405
</li>
<li>
10:34 ق.ظ
</li>
<li>
<a href="/category/قلب-و-عروق/">قلب و عروق</a>
</li>
</ul>
<p>آیا شما هم ماه‌هاست که هر شب پاهایتان را با روغن سیاه‌دانه ماساژ می‌دهید اما همچنان هنگام ایستادن طولانی‌مدت احساس سنگینی، تیر کشیدن و برجستگی آزاردهنده رگ‌ها را تجربه می‌کنید؟ این یکی از رایج‌ترین مشکلاتی است که بیماران در مطب ما مطرح می‌کنند و بسیاری از افراد تصور می‌کنند واریس پا صرفاً یک مشکل سطحی پوستی یا یک گرفتگی عضلانی ساده است که با پمادها و روغن‌های گیاهی برطرف می‌شود اما واقعیت پزشکی چیز دیگری است، واریس یک بیماری پیش‌رونده سیستم گردش خون است و نادیده گرفتن ریشه مکانیکی آن نه تنها زمان طلایی درمان را از دست می‌دهد بلکه می‌تواند منجر به عوارض جبران‌ناپذیری مانند زخم‌های وریدی یا لخته شدن خون شود.</p>
<h2>واریس چیست و روغن سیاه‌دانه چه تاثیری در درمان آن دارد؟</h2>
<p>برای درک اثربخشی هر درمانی ابتدا باید پاتوفیزیولوژی بیماری را بشناسیم، در پاهای ما وریدهایی وجود دارد که وظیفه بازگرداندن خون برخلاف نیروی جاذبه به سمت قلب را بر عهده دارند. برای جلوگیری از بازگشت خون به پایین، این رگ‌ها دارای دریچه‌های یک‌طرفه ظریفی هستند. وقتی این دریچه‌ها به دلایلی مانند ژنتیک، بارداری، چاقی یا ایستادن‌های طولانی‌مدت ضعیف یا تخریب می‌شوند، خون در پاها تجمع پیدا می‌کند. این پدیده «نارسایی وریدی» یا «رفلاکس وریدی» نامیده می‌شود که فشار هیدرواستاتیک را بالا برده و در نهایت باعث گشاد، پیچ‌خورد و برجسته شدن رگ‌ها (واریس) می‌شود.</p>
<p>روغن سیاه‌دانه (با نام علمی Nigella Sativa) حاوی ترکیب فعالی به نام «تیموکینون» است. از نظر فارماکولوژی، تیموکینون یک ضدالتهاب و آنتی‌اکسیدان بسیار قوی است. وقتی شما این روغن را روی پوست ماساژ می‌دهید، می‌تواند التهاب بافت اطراف رگ را کاهش دهد، درد موضعی را تسکین دهد و تا حدودی گردش خون مویرگی را بهبود ببخشد، هرچند در مقایسه با روش‌های کلینیک خیلی کم است اما نکته کلیدی و بسیار مهم اینجاست: <strong>هیچ ماده شیمیایی یا گیاهی در دنیا وجود ندارد که بتواند یک دریچه وریدی پاره یا تخریب‌شده را از نظر مکانیکی ترمیم کند.</strong> روغن سیاه‌دانه فقط علائم را مدیریت می‌کند، اما علت اصلی بیماری (نارسایی دریچه) را برطرف نمی‌سازد.</p>
<h2>۵ اشتباه رایج که درمان خانگی واریس را بی‌اثر می‌کند</h2>
<p>بسیاری از بیماران ما در کلینیک ماه‌ها وقت و هزینه خود را صرف روش‌های خانگی کرده‌اند اما به دلیل ارتکاب اشتباهات زیر، هیچ نتیجه‌ای نگرفته‌اند:</p>
<strong>۱. ماساژ در جهت اشتباه:</strong> بسیاری از افراد روغن را از رگ به سمت مچ پا ماساژ می‌دهند. این کار فشار خون را روی دریچه‌های معیوب بیشتر کرده و واریس را بدتر می‌کند. جهت صحیح ماساژ همیشه از مچ به سمت ران (به سمت قلب) است.
<strong>۲. انتظار محو شدن رگ‌های برجسته:</strong> روغن سیاه‌دانه نمی‌تواند رگی که یک‌بار گشاد و پیچ‌خورد شده را دوباره به حالت اولیه برگرداند. دیواره ورید در واریس‌های پیشرفته، خاصیت ارتجاعی خود را کاملاً از دست داده است.
<strong>۳. نادیده گرفتن وریدهای عمقی:</strong> واریس‌های سطحی که شما می‌بینید، تنها نوک کوه یخ هستند. مشکل اصلی ممکن است در وریدهای عمقی (مانند ورید صافن) باشد که با چشم دیده نمی‌شود و نیاز به سونوگرافی داپلر دارد.
<strong>۴. استفاده از روغن‌های حرارت‌دیده:</strong> تیموکینون به شدت به حرارت حساس است. روغن‌های بازاری که با حلال یا حرارت استخراج شده‌اند، بخش زیادی از خواص خود را از دست می‌دهند و اثربخشی درمانی آن‌ها برای عروق به‌شدت کاهش می‌یابد.
<strong>۵. به تعویق انداختن مراجعه به پزشک:</strong> بزرگترین اشتباه، صبر کردن برای معجزه روغن‌هاست. هر ماه تأخیر در درمان پزشکی، باعث گسترش شبکه وریدی معیوب و افزایش هزینه‌های درمان می‌شود.
<h2>مرز بین تسکین علائم و درمان قطعی، چرا به متخصص عروق نیاز دارید؟</h2>
<p>به عنوان متخصصین جراحی عروق ما همیشه رویکرد پزشکی ترکیبی را به بیماران توصیه می‌کنیم و این یعنی استفاده از درمان‌های خانگی برای کنترل علائم در کنار روش‌های کلینیکال برای حذف ریشه بیماری. وقتی شما با پاهای واریسی به کلینیک ما مراجعه می‌کنید اولین قدم انجام <strong>سونوگرافی رنگی داپلر (Color Doppler Ultrasound)</strong> است. این تصویربرداری دقیقاً به ما نشان می‌دهد که کدام دریچه‌ها نارسا هستند، میزان رفلاکس خون چقدر است و آیا وریدهای عمقی درگیر هستند یا خیر.</p>
<p>بر اساس نقشه دقیق عروق پای شما، پزشک متخصص ما یکی از روش‌های مینیمال اینوسیو (کم‌تهاجمی) زیر را طراحی می‌کند که هیچ‌کدام نیاز به بیهوشی عمومی یا بستری در بیمارستان ندارند و شما همان روز به خانه برمی‌گردید:</p>
<ul>
<li>
<strong>اسکلروتراپی با فوم (Sclerotherapy):</strong> تزریق فوم مخصوص به داخل رگ‌های واریسی کوچک و متوسط که باعث می‌شود رگ جمع شده و به مرور زمان توسط بدن جذب شود. این روش برای رگ‌های عنکبوتی و واریس‌های رشته‌ای بی‌نظیر است.</li>
<li>
<strong>لیزر درون‌رگی (EVLT):</strong> استفاده از انرژی لیزر از طریق یک فیبر نازک برای بستن وریدهای صافن بزرگ و معیوب. این روش استاندارد طلایی درمان واریس‌های اصلی است و دوران نقاهت بسیار کوتاهی دارد.</li>
<li>
<strong>فلبکتومی سرپایی (Ambulatory Phlebectomy):</strong> خارج کردن رگ‌های بسیار برجسته و پیچ‌خورد از طریق سوراخ‌های ریز پوستی بدون نیاز به بخیه.</li>
</ul>
<p>تنها با انجام این روش‌ها در کلینیک تخصصی ماست که می‌توانید رگ‌های زشت و دردناک را برای همیشه حذف کنید و از بازگشت بیماری پیشگیری نمایید.</p>
<p>گاهی اوقات مشکلات عروقی پا می‌تواند با اختلالات گردش خون و مسائل جدی‌تری مانند <a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
<strong>فشار دیاستولیک پایین</strong>
</a> همراه باشد که نیاز به بررسی تخصصی دارد. به همین دلیل، تشخیص دقیق توسط متخصص عروق اهمیت بالایی دارد.</p>
<h2>چه زمانی درمان خانگی را متوقف و فوراً به کلینیک مراجعه کنیم؟</h2>
<p>اگر هر یک از علائم زیر را در پاهای خود مشاهده می‌کنید، استفاده از روغن سیاه‌دانه و درمان‌های خانگی را متوقف کرده و در اسرع وقت برای معاینه توسط دکتر متخصص ما وقت رزرو کنید:</p>
<h3>تغییر رنگ پوست</h3>
<p>تیره شدن، قهوه‌ای شدن یا پوسته‌پوسته شدن پوست مچ پا نشانه نارسایی شدید وریدی است.</p>
<h3>تورم ناگهانی و یک‌طرفه</h3>
<p>اگر یک پا به طور ناگهانی و شدید متورم شد و درد داشت، خطر ترومبوز وریدی (لخته خون) وجود دارد.</p>
<h3>زخم‌های وریدی</h3>
<p>ایجاد زخم‌های باز در اطراف مچ پا که به سختی بهبود می‌یابند، نیازمند مداخله فوری پزشکی است.</p>
<h3>خونریزی از رگ</h3>
<p>پارگی رگ‌های واریسی سطحی می‌تواند باعث خونریزی شدید شود و نیاز به درمان اورژانسی دارد.</p>
<h2>درمان‌های خانگی در برابر روش‌های درمانی در کلینیکال ما</h2>
<table>
<thead>
<tr>
<th>ویژگی / روش درمان</th>
<th>روغن سیاه‌دانه (خانگی)</th>
<th>اسکلروتراپی (کلینیک)</th>
<th>لیزر درون‌رگی EVLT (کلینیک)</th>
</tr>
</thead>
<tbody>
<tr>
<td>هدف اصلی</td>
<td>تسکین درد و کاهش التهاب</td>
<td>حذف رگ‌های عنکبوتی و متوسط</td>
<td>بستن وریدهای اصلی و بزرگ</td>
</tr>
<tr>
<td>درمان قطعی ریشه بیماری</td>
<td>خیر</td>
<td>بله</td>
<td>بله</td>
</tr>
<tr>
<td>نیاز به سونوگرافی داپلر</td>
<td>خیر</td>
<td>توصیه می‌شود</td>
<td>الزامی است</td>
</tr>
<tr>
<td>دوران نقاهت</td>
<td>ندارد</td>
<td>بازگشت فوری به کار</td>
<td>۱ تا ۲ روز استراحت نسبی</td>
</tr>
<tr>
<td>نتیجه زیبایی</td>
<td>تأثیری بر ظاهر رگ ندارد</td>
<td>محو شدن کامل رگ‌ها</td>
<td>صاف شدن کامل سطح پا</td>
</tr>
<tr>
<td>انجام شده توسط</td>
<td>خود بیمار</td>
<td>فوق تخصص عروق در کلینیک ما</td>
<td>جراح عروق در کلینیک ما</td>
</tr>
</tbody>
</table>
<h2>رویکرد ترکیبی برای بهترین نتیجه</h2>
<p>اگر واریس شما در مراحل اولیه است و پزشک ما تشخیص داده که فعلاً نیازی به مداخله تهاجمی نیست، یا اگر در دوران پس از عمل لیزر/اسکلروتراپی در کلینیک ما هستید، می‌توانید از روغن سیاه‌دانه به عنوان درمان مکمل استفاده کنید. برای این کار، نکات زیر را رعایت کنید:</p>
<ol>
<li>
<strong>استفاده از جوراب واریس:</strong> پس از ماساژ ملایم روغن (از مچ به ران)، حتماً جوراب فشارنده طبی (با فشار مناسب که پزشک تجویز کرده) را بپوشید. این کار اثر درمان را چند برابر می‌کند.</li>
<li>
<strong>پرهیز از حرارت:</strong> روغن سیاه‌دانه را پیش از ماساژ، تنها در حدی گرم کنید که به دمای محیط یا کمی بالاتر برسد، مثلاً قرار دادن ظرف روغن روی شوفاژ برای چند دقیقه کافی است. به‌هیچ‌وجه روغن را به نقطه جوش نرسانید و دمای آن را خیلی بالا نبرید، زیرا حرارت زیاد، مواد مؤثره روغن را تخریب کرده و اث ربخشی آن را به‌طور چشمگیری کاهش می‌دهد.</li>
</ol>
🏥
<h2>رزرو نوبت و معاینه تخصصی در کلینیک ما</h2>
<p>زمان را برای درمان‌های آزمایشی خانگی تلف نکنید. واریس پا با گذشت زمان بدتر می‌شود. تیم فوق‌تخصصی ما در <a href="/service/کلینیک-واریس/">
<strong>کلینیک واریس</strong>
</a>، با بهره‌گیری از پیشرفته‌ترین دستگاه‌های لیزر و سونوگرافی داپلر، آماده است تا نقشه دقیق عروق پاهای شما را ترسیم کرده و بهترین، سریع‌ترین و زیباترین روش درمان را برایتان اجرا کند.</p>
<p>۰۲۱-۹۱۳۰۳۱۳۲</p>
<p>⚕️ <strong>سلب مسئولیت پزشکی:</strong> اطلاعات ارائه‌شده در این مقاله صرفاً جنبه آموزشی و آگاهی‌بخشی دارد و به هیچ وجه جایگزین تشخیص، مشاوره و درمان توسط پزشک متخصص نیست، پیش از استفاده از هرگونه روغن گیاهی یا تغییر در روند درمان حتماً با پزشک معالج خود مشورت نمایید و در صورت مشاهده علائم حاد مانند تورم ناگهانی، درد شدید یا تغییر رنگ پوست فوراً به مراکز درمانی مراجعه کنید.</p>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/روغن-سیاه-دانه-برای-واریس-پا/#respond">لغو نظر</a>
</h3>' WHERE path = '/روغن-سیاه-دانه-برای-واریس-پا/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
19 بهمن 1404
</li>
<li>
11:19 ق.ظ
</li>
<li>
<a href="/category/شیمی-درمانی/">شیمی درمانی</a>
</li>
</ul>
<p>احتمالا ذهن شما هم درگیر این موضوع شود که شب قبل از شیمی درمانی چه بخوریم تا فردا حال بهتری داشته باشیم؟ زیرا همان‌طور که می‌دانید، غذایی که میل می‌کنید می‌تواند تفاوت بزرگی در میزان عوارض جانبی، سطح انرژی و حال عمومی شما ایجاد کند. برای همین، در ادامه با ما همراه باشید تا کامل این موضوع را بررسی کنیم.</p>
<h2>
<b>چرا شام قبل از شیمی‌درمانی اینقدر مهم است؟</b>
</h2>
<ul>
<li>
<b>ذخیره انرژی</b>: بدن برای ترمیم بافت‌های آسیب‌دیده به انرژی نیاز دارد. شام شب قبل از شیمی درمانی باید این انرژی را بدون سنگین کردن معده تأمین کند.</li>
<li>
<b>مدیریت تهوع</b>: یکی از شایع‌ترین عوارض شیمی‌درمانی، تهوع است. خوردن غذای نامناسب در شب قبل می‌تواند معده را حساس‌تر کرده و تهوع را تشدید کند.</li>
<li>
<b>هیدراتاسیون (آبرسانی): </b>سلول‌های بدن شما برای دفع سموم ناشی از داروها به آب نیاز دارند. شروع آبرسانی باید از شب قبل باشد، نه صبح درمان.</li>
</ul>
<h2>
<b>بهترین غذاها برای شب قبل از شیمی‌درمانی</b>
</h2>
<p>بهترین غذاها برای شب قبل از شیمی‌درمانی عبارتند از:</p>
<h3>
<b>۱. پروتئین‌های کم‌چرب و سبک</b>
</h3>
<p>پروتئین‌ها برای تقویت سیستم ایمنی ضروری‌اند. اما هر پروتئینی مناسب نیست. گوشت‌های قرمز و پرچرب دیرهضم هستند و ممکن است در روز شیمی درمانی، باعث احساس سنگینی شوند.</p>
<ul>
<li>
<b>مرغ آب‌پز یا بخارپز</b>: سینه مرغ یکی از بهترین گزینه‌هاست. زیرا بافت نرمی دارد و معده را اذیت نمی‌کند.</li>
<li>
<b>ماهی:</b> ماهی‌های چرب مثل سالمون (اگر به‌صورت کبابی و کم‌روغن طبخ شوند) عالی هستند چون حاوی امگا-3 هستند که خاصیت ضدالتهابی دارد.</li>
<li>
<b>تخم‌مرغ آب‌پز</b>: یک منبع پروتئین عالی و سبک، به شرطی که نسبت به بوی آن حساس نباشید.</li>
<li>
<b>توفو یا پنیر کم‌چرب</b>: برای کسانی که میلی به گوشت ندارند.</li>
</ul>
<h3>
<b>۲. کربوهیدرات‌های پیچیده اما ملایم</b>
</h3>
<p>کربوهیدرات‌ها انرژی لازم را به شما می‌دهند. اما باید کربوهیدراتی را انتخاب کنید که قند خون را ناگهانی بالا نبرد و در عین حال هضم راحتی داشته باشد.</p>
<ul>
<li>
<b>برنج کته (کم‌روغن)</b>: برنج سفید ساده یکی از بهترین مواد غذایی برای معده است.</li>
<li>
<b>پاستا (بدون سس‌های سنگین):</b> پاستا با کمی روغن زیتون و سبزیجات معطر عالی است.</li>
<li>
<b>سیب‌زمینی پخته: </b>سیب‌زمینی آب‌پز یا پوره شده (بدون کره زیاد) بسیار تسکین‌دهنده است.</li>
<li>
<b>جو دوسر:</b> اگر تمایل به یک شام سبک و سوپ‌مانند دارید، سوپ جو بسیار مقوی است.</li>
</ul>
<h3>
<b>۳. سبزیجات پخته شده</b>
</h3>
<p>سبزیجات خام ممکن است باعث نفخ شوند و هضمشان سخت باشد، به‌خصوص اگر استرس دارید. در عوض، سبزیجات پخته شده ویتامین‌ها را بدون فشار به دستگاه گوارش به بدن می‌رسانند.</p>
<ul>
<li>
<b>هویج پخته: </b>شیرین، خوشمزه و سرشار از ویتامین A.</li>
<li>
<b>کدو سبز:</b> بسیار زود هضم و سبک.</li>
<li>لوبیای سبز بخارپز.</li>
</ul>
<h3>
<b>۴. معجزه مایعات و هیدراتاسیون</b>
</h3>
<p>شاید مهم‌تر از غذا، نوشیدنی‌های شما باشد. داروهای شیمی‌درمانی باید از طریق کلیه‌ها دفع شوند و این کار نیازمند آب فراوان است.</p>
<ul>
<li>
<b>آب</b>: ساده‌ترین و بهترین گزینه.</li>
<li>
<b>آب گوشت یا مرغ (Broth)</b>: اگر اشتها ندارید، عصاره گوشت یا مرغ بدون چربی هم غذاست و هم دارو.</li>
<li>
<b>دمنوش زنجبیل</b>: اگر نگران تهوع در روز شیمی درمانی هستید، از شب قبل، دمنوش زنجبیل کم‌شیرین بنوشید. </li>
</ul>
<h2>
<b>چه چیزهایی را نباید بخوریم؟</b>
</h2>
<p>آگاهی از اینکه چه چیزهایی را نباید بخوریم، دقیقا به اندازه دانستن اینکه چه چیزی باید بخوریم هم مهم است:</p>
<h3>
<b>۱. غذاهای سرخ‌کرده و چرب</b>
</h3>
<p>سیب‌زمینی سرخ‌کرده، فست‌فود، کباب‌های چرب و غذاهای غرق در روغن را در شب قبل از شیمی درمانی فراموش کنید. چربی زیاد مدت زمان تخلیه معده را طولانی می‌کند. یعنی وقتی فردا صبح برای درمان می‌روید، هنوز غذا در معده‌تان سنگینی می‌کند و احتمال استفراغ را به‌شدت بالا می‌برد.</p>
<h3>
<b>۲. غذاهای تند و پرادویه</b>
</h3>
<p>فلفل، ادویه‌های کاری و سس‌های تند می‌توانند پوشش داخلی معده و روده را تحریک کنند. شیمی‌درمانی خودبه‌خود باعث حساسیت گوارشی می‌شود.</p>
<h3>
<b>۳. سبزیجات نفاخ و خام</b>
</h3>
<p>کلم بروکلی خام، کلم پیچ، پیاز خام و حبوبات خیس‌نخورده می‌توانند باعث گاز معده و دل‌پیچه شوند. </p>
<h3>
<b>۴. شیرینی‌های مصنوعی و قند بالا</b>
</h3>
<p>کیک‌ها، شیرینی‌های خامه‌ای و نوشابه‌ها شاید انرژی لحظه‌ای بدهند، اما باعث سقوط انرژی (Sugar Crash) می‌شوند و التهاب بدن را افزایش می‌دهند.</p>
<h3>
<b>۵. الکل و کافئین زیاد</b>
</h3>
<p>این دو ماده به‌شدت آب بدن را دفع می‌کنند (دیورتیک هستند). بدن کم‌آب، میزبان خوبی برای شیمی‌درمانی نیست و عوارض را شدیدتر حس می‌کند.</p>
<h2>
<b>پیشنهادات غذایی برای شام شب قبل</b>
</h2>
<table>
<tbody>
<tr>
<td>
<b>نوع غذا</b>
</td>
<td>
<b>ترکیبات پیشنهادی</b>
</td>
<td>
<b>چرا خوب است؟</b>
</td>
</tr>
<tr>
<td>
<b>خوراک مرغ و سبزیجات</b>
</td>
<td>سینه مرغ پخته + هویج و کدو بخارپز + کمی روغن زیتون و لیمو</td>
<td>پروتئین بالا، هضم آسان، ویتامین کافی</td>
</tr>
<tr>
<td>
<b>پلو ماش یا کته ساده</b>
</td>
<td>برنج ایرانی (کته نرم) + کمی ماش یا شوید</td>
<td>کربوهیدرات ملایم، ضد نفخ (در صورت استفاده از زیره)</td>
</tr>
<tr>
<td>
<b>سوپ جو یا ورمیشل</b>
</td>
<td>آب مرغ + هویج رنده شده + کمی جعفری + ورمیشل</td>
<td>آبرسانی عالی، گرم و تسکین‌دهنده معده</td>
</tr>
<tr>
<td>
<b>ماهی کبابی</b>
</td>
<td>فیله ماهی (تیلاپیا یا قزل‌آلا) در فر + سیب‌زمینی پخته</td>
<td>امگا 3 بالا، سبک و بدون بوی زهم شدید</td>
</tr>
</tbody>
</table>
<h2>
<b>نکات مهم برای غذا خوردن </b>
</h2>
<ol>
<li>
<b>وعده‌های کوچک:</b> به جای یک بشقاب پر و سنگین، شام را در دو نوبت با حجم کم میل کنید. پرخوری فشار زیادی به دیافراگم و معده وارد می‌کند.</li>
<li>
<b>زود شام بخورید:</b> سعی کنید حداقل 2 تا 3 ساعت قبل از خواب شام را تمام کرده باشید تا هنگام دراز کشیدن، رفلاکس معده نداشته باشید.</li>
<li>
<b>محیط آرام: </b>استرس هضم غذا را مختل می‌کند. تلویزیون را خاموش کنید، موزیک ملایم بگذارید و با آرامش غذا بخورید.</li>
<li>
<b>از غذاهای مورد علاقه خیلی خاص پرهیز کنید:</b> این یک نکته روانشناسی عجیب است. گاهی اوقات اگر غذای محبوبتان را قبل از شیمی‌درمانی بخورید و بعد دچار تهوع شوید، مغز شما آن غذا را با تهوع شرطی‌سازی می‌کند و ممکن است تا ابد از آن غذا متنفر شوید (Food Aversion). پس غذاهای معمولی و ساده را انتخاب کنید.</li>
</ol>
<p>در کل به یاد داشته باشید که شام شما در شب قبل از شیمی‌درمانی، تاثیر زیادی روی بدن دارد. با انتخاب غذاهای سبک، زود هضم و پروتئین‌دار در کنار نوشیدن آب کافی، می‌توانید احتمال بروز عوارضی مثل تهوع و خستگی مفرط را کاهش دهید. همچنین، از غذاهای چرب، سنگین و محرک دوری کنید و اجازه دهید سیستم گوارشتان پیش از شروع درمان در آرامش باشد. این مراقبت‌های تغذیه‌ای، اگرچه ساده به نظر می‌رسند، اما تاثیر عمیقی بر کیفیت درمان و حال عمومی شما خواهند داشت. علاوه‌برآن، شما می‌توانید درصورت نیاز به مشاوره بیشتر در این زمینه، با کارشناسان ما تماس بگیرید.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/#respond">لغو نظر</a>
</h3>' WHERE path = '/شب-قبل-از-شیمی-درمانی-چه-بخوریم/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
6 آبان 1404
</li>
<li>
11:43 ق.ظ
</li>
<li>
<a href="/category/تغذیه/">تغذیه</a>
</li>
</ul>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/نقش-آنتیاکسیدانها-در-پیشگیری-از-سر/#respond">لغو نظر</a>
</h3>' WHERE path = '/نقش-آنتیاکسیدانها-در-پیشگیری-از-سر/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
19 بهمن 1404
</li>
<li>
10:33 ق.ظ
</li>
<li>
<a href="/category/شیمی-درمانی/">شیمی درمانی</a>
</li>
</ul>
<h2>
<b>هر دوره شیمی درمانی چند جلسه است؟ </b>
</h2>
<p>شاید پرتکرارترین و البته منطقی‌ترین سوالی که بیماران یا همراهان آن‌ها در همان جلسه اول از پزشک می‌پرسند، این است که هر دوره شیمی درمانی چند جلسه است و این پروسه چقدر طول می‌کشد؟ اما به‌طور ثابت نمی‌توان گفت مثلا 10 جلسه است.</p>
<p>شیمی درمانی، به‌صورت دوره‌ای (Cyclic) انجام می‌شود. بنابراین، وقتی پرسیده می‌شود که هر دوره چند جلسه است؟، در واقع باید بدانیم که کل درمان از چندین سیکل (Cycle) تشکیل شده است. هر سیکل شامل روزهای دریافت دارو و روزهای استراحت است.</p>
<h2>
<b>تعداد جلسات شیمی درمانی چطور تعیین می‌شود؟</b>
</h2>
<p>پزشک آنکولوژیست (متخصص سرطان) براساس چه معیاری تصمیم می‌گیرد که شما 4 جلسه شیمی درمانی نیاز دارید یا 12 جلسه؟ این تصمیم به موارد بسیار مهمی بستگی دارد:</p>
<h3>
<b>۱. نوع سرطان و بافت‌شناسی آن</b>
</h3>
<p>سرطان‌های خونی (مثل لوسمی) پروتکل‌های درمانی طولانی‌تر نسبت به تومورهای جامد (مثل سرطان پستان یا روده) دارند. برخی سرطان‌ها رشد سریع‌تر و نیاز به جلسات فشرده‌تری دارند، اما برخی دیگر با فواصل طولانی‌تر درمان می‌شوند.</p>
<h3>
<b>۲. مرحله (Stage) بیماری</b>
</h3>
<p>همچنین به اینکه آیا سرطان در مراحل اولیه است یا پیشرفته است هم بستگی دارد. در <b>مراحل اولیه</b>، بیشتر هدف درمان ریشه‌کنی کامل است و ممکن است دوره‌ها کوتاه‌تر اما با دوز مشخص باشد (مثلا 4 تا 6 ماه). در <b>مراحل متاستاتیک (پیشرفته)</b>، هدف کنترل بیماری است. در این حالت ممکن است تعداد جلسات محدود نباشد و تا زمانی که دارو اثر دارد و بدن بیمار کشش دارد، درمان ادامه یابد.</p>
<h3>
<b>۳. هدف از درمان (کیوراتیو یا پالیاتیو)</b>
</h3>
<p>
<b>درمان قطعی (Curative)</b>، وقتی است که هدف از بین بردن کامل سرطان است، تعداد جلسات مشخص و محدود است (مثلا 8 جلسه). <b>درمان تسکینی (Palliative)</b> هم برای زمانی است که هدف کاهش درد و کنترل علائم است. برای همین، تعداد جلسات ممکن است کمتر باشد و با ملایمت بیشتری انجام شود تا کیفیت زندگی بیمار حفظ شود.</p>
<h3>
<b>۴. نوع داروهای تجویزی</b>
</h3>
<p>برخی داروها بسیار قوی هستند و بدن برای ریکاوری به 3 هفته زمان نیاز دارد (یعنی هر 21 روز یک جلسه). برخی دیگر سبک‌ترند و می‌توانند به‌صورت هفتگی (Weekly) تجویز شوند.</p>
<h3>
<b>۵. پاسخ بدن بیمار به درمان</b>
</h3>
<p>پاسخ بدن بیمار به درمان، فاکتوری است که در طول مسیر مشخص می‌شود. اگر در وسط درمان، آزمایش‌ها نشان دهند که تومور کاملا از بین رفته است، ممکن است پزشک تعداد جلسات باقی‌مانده را کم کند. برعکس، اگر تومور مقاومت کند، ممکن است داروها و تعداد جلسات تغییر کنند.</p>
<h2>
<b>استاندارد تعداد جلسات </b>
</h2>
<p>یک دوره کامل درمان معمولا بین 3 تا 6 ماه طول می‌کشد. اما این زمان چگونه تقسیم‌بندی می‌شود؟ استانداردترین الگوهای زمانی در شیمی درمانی عبارتند از:</p>
<ul>
<li>
<b>سیکل‌های 21 روزه (هر 3 هفته یکبار)</b>: شما در روز اول دارو را دریافت می‌کنید و سپس 20 روز استراحت دارید. این 21 روز، یک سیکل نامیده می‌شود. بیشتر هم 4 تا 8 سیکل تجویز می‌شود.</li>
<li>
<b>سیکل‌های 14 روزه (هر 2 هفته یکبار):</b> در برخی سرطان‌ها (مثل برخی موارد سرطان روده یا پستان)، برای افزایش اثرگذاری، فواصل را کم می‌کنند. به این روش Dose-dense گفته می‌شود.</li>
<li>
<b>سیکل‌های 28 روزه (هر 4 هفته یکبار)</b>: گاهی برای داروهای خوراکی یا برخی رژیم‌های خاص استفاده می‌شود.</li>
<li>
<b>رژیم‌های هفتگی (Weekly)</b>: در این روش، دوز دارو پایین می‌آید اما بیمار باید هر هفته (مثلا شنبه‌ها) برای تزریق مراجعه کند. این روش، عوارض شدید ناگهانی را کم می‌کند اما رفت‌وآمد بیشتری دارد.</li>
</ul>
<h2>
<b>مدت زمان هر جلسه چقدر است؟</b>
</h2>
<p>مدت زمانی که شما در کلینیک یا بیمارستان سپری می‌کنید، به <b>نوع تزریق</b> بستگی دارد:</p>
<ol>
<li>
<b>تزریق سریع (IV Push):</b> برخی داروها فقط چند دقیقه طول می‌کشند تا از طریق سرنگ به آنژیوکت تزریق شوند.</li>
<li>
<b>اینفیوژن کوتاه (IV Infusion): </b>این تزریق، رایج‌ترین حالت است. دارو در یک کیسه سرم رقیق شده و طی 1 تا 4 ساعت قطره‌قطره وارد رگ می‌شود.</li>
<li>
<b>تزریق طولانی (Continuous Infusion):</b> گاهی لازم است دارو خیلی آرام و طی 24 یا 48 ساعت وارد بدن شود. در این شرایط، به بیمار یک پمپ کوچک وصل می‌شود که می‌تواند با آن به خانه برود و پمپ به‌صورت خودکار دارو را تزریق می‌کند.</li>
</ol>
<p>
<b>نکته:</b> همیشه به زمان تزریق دارو، حدود 1 ساعت هم برای کارهای جانبی اضافه کنید. این کارها شامل آزمایش خون قبل از تزریق، ویزیت پزشک، و دریافت داروهای پیش‌درمان است. </p>
<h2>
<b>چرا بین جلسات استراحت وجود دارد؟ </b>
</h2>
<p>زیرا داروهای شیمی درمانی، هر سلولی که سرعت رشد بالایی دارد را هدف می‌گیرند. سلول‌های سرطانی رشد سریعی دارند، اما متاسفانه سلول‌های مغز استخوان (که گلبول‌های سفید و قرمز را می‌سازند)، سلول‌های ریشه مو و سلول‌های پوششی دهان و روده هم رشد سریعی دارند.</p>
<p>وقتی شیمی درمانی وارد بدن می‌شود، سطح گلبول‌های سفید خون (سربازان ایمنی) کاهش می‌یابد. این کاهش، در روز 7 تا 10 بعد از تزریق به اوج خود می‌رسد (به این نقطه Nadir می‌گویند). بدن شما نیاز به زمان دارد تا مغز استخوان دوباره فعالیت کند و سطح گلبول‌ها را به حد نرمال برساند.</p>
<p>اگر قبل از اینکه بدن ریکاوری شود، جلسه بعدی را انجام دهید:</p>
<ul>
<li>سیستم ایمنی بدن به‌شدت ضعیف می‌شود و خطر عفونت‌های مرگبار بالا می‌رود.</li>
<li>پلاکت‌ها افت می‌کنند و خطر خونریزی ایجاد می‌شود.</li>
<li>بافت‌های سالم بدن فرصت ترمیم پیدا نمی‌کنند.</li>
</ul>
<h2>
<b>چه زمانی برنامه زمانی تغییر می‌کند؟ </b>
</h2>
<p>گاهی اوقات ممکن است به کلینیک بروید و پزشک بگوید: امروز تزریق نداریم. این جمله ممکن است نگران‌کننده باشد، اما بیشتر برای حفظ ایمنی شماست. دلایل رایجی که برای تغییر تعداد جلسات یا تاخیر در آن‌ها وجود دارد شامل:</p>
<ol>
<li>
<b>افت شدید گلبول‌های سفید (نوتروپنی)</b>: اگر آزمایش خون روز تزریق نشان دهد که گلبول‌های سفید خیلی پایین هستند، تزریق انجام نمی‌شود چون خطرناک است.</li>
<li>
<b>عوارض جانبی شدید</b>: اگر بیمار دچار زخم‌های دهانی شدید، مشکلات کلیوی یا ضعف مفرط شده باشد، پزشک ممکن است دوز را کم کند یا یک هفته استراحت اضافه بدهد.</li>
<li>
<b>پیشرفت یا عدم پاسخ بیماری:</b> اگر در تصویربرداری‌های میان‌دوره مشخص شود که تومور به داروی فعلی پاسخ نمی‌دهد، ممکن است دارو عوض شود و سیکل‌بندی جدیدی (با تعداد جلسات متفاوت) شروع شود.</li>
</ol>
<h2>
<b>آیا تعداد جلسات بیشتر به معنی وخامت بیماری است؟</b>
</h2>
<p>این موضوع، یکی از بزرگترین ترس‌های بیماران است. تعداد جلسات بیشتر لزوما به معنی بدتر بودن سرطان نیست. گاهی اوقات، نوع رژیم درمانی، ایجاب می‌کند که دوزهای پایین‌تر (که عوارض کمتری دارند) در دفعات بیشتر (مثلا هفتگی) تزریق شوند. اما رژیم‌هایی با تعداد جلسات کم، ممکن است دوزهای بسیار بالا و سنگین داشته باشند.</p>
<p>شیمی درمانی دوره‌ای از زندگی است که در آن تقویم و روزها اهمیت زیادی پیدا می‌کنند. شاید در ابتدا، شنیدن اینکه باید 6 ماه یا 8 دوره درمان شوید، ترسناک و طولانی به نظر برسد. مهم‌ترین نکته این است که خودتان را با دیگران مقایسه نکنید. بدن شما، نوع بیماری شما و پاسخ سلول‌های شما به دارو، مختص خودتان است. </p>
<p>امیدواریم این مطلب از <a href="/">
<b>همراه کلینیک</b>
</a> برای شما مفید بوده باشد و به پرسش‌های شما پاسخ داده باشد.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/#respond">لغو نظر</a>
</h3>' WHERE path = '/هر-دوره-شیمی-درمانی-چند-جلسه-است/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
6 آبان 1404
</li>
<li>
11:42 ق.ظ
</li>
<li>
<a href="/category/روانشناسی/">روانشناسی</a>
</li>
</ul>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/چرا-مغز-ما-در-مواجهه-با-استرس-بیشفعال/#respond">لغو نظر</a>
</h3>' WHERE path = '/چرا-مغز-ما-در-مواجهه-با-استرس-بیشفعال/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
6 آبان 1404
</li>
<li>
11:42 ق.ظ
</li>
<li>
<a href="/category/heart-diseases/">بیماری‌های قلبی</a>, <a href="/category/قلب-و-عروق/">قلب و عروق</a>
</li>
</ul>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/10-نشانه-پنهان-بیماری-قلبی-که-نباید-ناد/#respond">لغو نظر</a>
</h3>' WHERE path = '/10-نشانه-پنهان-بیماری-قلبی-که-نباید-ناد/';

UPDATE pages SET body = '<h4>جدیدترین مقالات</h4>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
</a>
<h3>
<a href="/ایا-گرفتگی-عروق-پا-خطرناک-است/">
ایا گرفتگی عروق پا خطرناک است؟ </a>
</h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
</a>
<h3>
<a href="/روغن-سیاه-دانه-برای-واریس-پا/">
روغن سیاه دانه برای واریس پا [فواید و روش مصرف] </a>
</h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
</a>
<h3>
<a href="/فشار-دیاستولیک-پایین-نشانه-چیست/">
فشار دیاستولیک پایین نشانه چیست؟ </a>
</h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
</a>
<h3>
<a href="/قرص-نیتروگلیسیرین-چه-زمانی-مصرف-شود/">
قرص نیتروگلیسیرین چه زمانی مصرف شود؟ </a>
</h3>
<h3>
<a href="/تشخیص-آریتمی-قلبی-در-خانه/">
تشخیص آریتمی قلبی در خانه </a>
</h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
</a>
<h3>
<a href="/بهترین-صبحانه-قبل-از-شیمی-درمانی/">
بهترین صبحانه قبل از شیمی درمانی </a>
</h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
</a>
<h3>
<a href="/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/">
از کجا بفهمیم شیمی درمانی جواب داده؟ علائم و روش‌های تشخیص </a>
</h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
</a>
<h3>
<a href="/شب-قبل-از-شیمی-درمانی-چه-بخوریم/">
شب قبل از شیمی درمانی چه بخوریم </a>
</h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
</a>
<h3>
<a href="/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/">
تقویت سیستم ایمنی بدن بعد از شیمی درمانی </a>
</h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
</a>
<h3>
<a href="/هر-دوره-شیمی-درمانی-چند-جلسه-است/">
تعداد جلسات شیمی‌ درمانی و فاصله بین جلسات چقدر است؟ </a>
</h3>
<ul>
<li>
6 آبان 1404
</li>
<li>
11:42 ق.ظ
</li>
<li>
<a href="/category/تغذیه/">تغذیه</a>
</li>
</ul>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>
<h2>فرم صفحه اصلی</h2>
<h3>پیام بگذارید <a href="/7-اشتباه-رایج-تغذیهای-که-مانع-کاهش-وز/#respond">لغو نظر</a>
</h3>' WHERE path = '/7-اشتباه-رایج-تغذیهای-که-مانع-کاهش-وز/';

UPDATE pages SET body = '<p>❤️ بخش قلب و عروق همراه کلینیک، مرکز تخصصی تشخیص و درمان بیماری‌های قلبی</p>
<p>نظر به عوارض قلبی-عروقی درمان‌های مبتنی بر رادیوتراپی و شیمی‌درمانی، همراهی فلوشیپ کاردیوآنکولوژی در پروسه درمان بخش جدایی ناپذیر درمان‌های آنکولوژی می‌باشد. بخش قلب کلینیک فوق تخصصی همراه با بهره گیری از پیشرفته ترین دستگاه‌ها، شامل دستگاه اکوکاردیوگرافی فیلیپس مدل افنیتی پیشرفته، دستگاه تست ورزش، نوار قلب و هولتر های ریتم و فشار و تیم فوق تخصصی شامل فلوشیپ کاردیو آنکولوژی، فلوشیپ اکوکاردیوگرافی و فلوشیپ نارسایی قلب آماده خدمت رسانی به انواع بیماران قلبی عروقی، بیماران سرطانی تحت درمان می‌باشد.</p>
<h4>لیست خدمات</h4>
<ul>
<li>نوار قلب</li>
<li> اکوکاردیوگرافی پیشرفته</li>
<li> اکوکاردیوگرافی با تزریق کنتراست</li>
<li> استرس اکوکاردیوگرافی</li>
<li>هولتر مونیتورینگ نوار قلب </li>
<li>هولتر مونیتورینگ فشار</li>
<li>هولتر مونیتورینگ فشار خون</li>
<li>معاینه و مراقبت های کاردیو آنکولوژی</li>
<li>درمان های تزریقی در بیماران نارسایی قلبی (infusion unit)</li>
</ul>
<p>بخش قلب و عروق همراه کلینیک، با بهره‌گیری از پیشرفته‌ترین تجهیزات تصویربرداری، خدمات جامع کاردیولوژی را ارائه می‌دهد. این بخش با تیمی متشکل از فلوشیپ‌های کاردیوآنکولوژی ، فلوشیپ اکوکاردیوگرافی و فلوشیپ نارسایی قلب و پرستاران ویژه، آماده خدمت‌رسانی به بیماران در تمامی مراحل بیماری‌های قلبی و عروقی است. در این مقاله، با خدمات، امکانات و رویکردهای نوین این بخش آشنا می‌شوید.</p>
<h2>بیماری‌های قلبی و عروقی شایع</h2>
<p>بیماری‌های قلبی و عروقی، نخستین علت مرگ‌ومیر در سطح جهانی محسوب می‌شوند و ایران نیز از این قاعده مستثنی نیست. بیماری عروق کرونر (CAD)، نارسایی قلبی، آریتمی‌ها، بیماری‌های دریچه‌ای و بیماری‌های مادرزادی قلب، شایع‌ترین علل مراجعه به بخش قلب و عروق هستند. تشخیص زودهنگام و مدیریت صحیح این بیماری‌ها، نقش حیاتی در کاهش عوارض و بهبود کیفیت زندگی بیماران دارد.</p>
<p>در همراه کلینیک، رویکرد چندتخصصی (Multidisciplinary) برای مدیریت این بیماری‌ها به کار گرفته می‌شود. به این معنا که فلوشیپ‌های کاردیوآنکولوژی ، فلوشیپ اکوکاردیوگرافی و فلوشیپ نارسایی قلب ، فوق تخصص غدد، فوق تخصص عفونی ، روانپزشک ، متخصص تغذیه ، کارشناس بیهوشی و پرستاران ویژه ، بهترین استراتژی درمانی را برای هر بیمار طراحی می‌کنند.</p>
<p>این رویکرد، به ویژه در موارد پیچیده مانند بیماران در حال درمان سرطان، بیماران مبتلا به گرفتگی شدید کرونر یا ترکیب بیماری‌های دریچه‌ای و عروقی، نتایج بسیار مطلوب‌تری نسبت به تصمیم‌گیری تک‌بعدی دارد.</p>
<p>آیا می‌دانستید که بسیاری از حملات قلبی قابل پیشگیری هستند؟ کنترل فشار خون، مدیریت دیابت، ترک سیگار، فعالیت بدنی منظم و تغذیه سالم، می‌توانند ریسک بیماری‌های قلبی را تا ۸۰ درصد کاهش دهند. با این حال، در صورت بروز علائمی مانند درد قفسه سینه، تنگی نفس ناگهانی یا تپش قلب غیرطبیعی، مراجعه فوری به مرکز تخصصی قلب ضروری است.</p>
<h2>خدمات تشخیصی و درمانی پیشرفته</h2>
<p>بخش قلب و عروق همراه کلینیک، طیف گسترده‌ای از خدمات تشخیصی و درمانی را ارائه می‌دهد. در حوزه تشخیص، اکوکاردیوگرافی پیشرفته ، استرس اکوکاردیوگرافی ، کنتراست اکوکاردیوگرافی ، هولتر ریتم و فشار خون  در دسترس است.</p>
<h3>توصیه تخصصی کاردیولوژیست</h3>
<p>برای تمامی افراد بالای ۳۵ سال، انجام چکاپ قلب شامل نوار قلب، اکوکاردیوگرافی، آزمایش چربی و قند خون، و در صورت وجود ریسک‌فاکتور، استرس اکوکاردیوگرافی یا سی‌تی‌آنژیوگرافی کرونر، توصیه می‌شود. تشخیص زودهنگام تنگی‌های خاموش کرونر، می‌تواند از سکته‌های قلبی ناگهانی جلوگیری کند. همچنین، بیماران با سابقه خانوادگی بیماری قلبی زودرس، باید غربالگری را از سنین پایین‌تر آغاز کنند.</p>
<h3>نکته مهم</h3>
<p>هرگز داروهای ضدانعقاد (مانند وارفارین، ریواروکسابان، آپیکسابان) یا ضدپلاکت (مانند آسپرین، کلوپیدوگرل) را بدون مشورت با پزشک قطع نکنید. قطع ناگهانی این داروها، به ویژه پس از آنژیوپلاستی یا کاشت استنت، می‌تواند منجر به ترومبوز استنت و سکته قلبی کشنده شود. هرگونه تغییر در دوز یا نوع دارو باید تحت نظارت کاردیولوژیست معالج انجام شود.</p>
<h2>چک‌لیست انتخاب مرکز تخصصی قلب مناسب</h2>
<p>✅ دسترسی به آزمایشگاه مرجع برای تست‌های تخصصی قلب و مارکرهای بیوشیمیایی</p>
<p>✅ پوشش بیمه‌ای گسترده</p>
<p>✅ ‫تیم چندتخصصی شامل فلوشیپ‌های کاردیوآنکولوژی، اکوکاردیوگرافی و نارسایی قلب</p>
<p>✅ ‫همکاری با متخصصان غدد، عفونی، روانپزشکی و تغذیه برای مدیریت جامع بیماران پیچیده</p>
<h2>اشتباهات رایج در مدیریت بیماری‌های قلبی</h2>
<h3>اشتباهات در پیشگیری و سبک زندگی</h3>
<ul>
<li>نادیده گرفتن علائم هشداردهنده مانند درد قفسه سینه، تنگی نفس فعالیتی یا ورم پاها</li>
<li>عدم کنترل منظم فشار خون و قند خون در افراد در معرض خطر</li>
<li>مصرف خودسرانه مکمل‌های گیاهی که با داروهای قلبی تداخل دارند (مانند جینسنگ با وارفارین)</li>
<li>ترک ناگهانی ورزش بدون جایگزینی فعالیت بدنی ملایم</li>
<li>تکیه صرف بر داروها و نادیده گرفتن اصلاح رژیم غذایی و سبک زندگی</li>
<li>عدم انجام چکاپ سالانه قلب پس از ۳۵ سالگی</li>
</ul>
<h3>هشدار ایمنی</h3>
<p>در صورت بروز درد شدید قفسه سینه که به دست چپ، فک یا پشت انتشار می‌یابد، همراه با تنگی نفس، عرق سرد، تهوع یا احساس مرگ قریب‌الوقوع، بلافاصله به مرکز مجهز درمانی مراجعه بفرمایید. این علائم می‌توانند نشانه سکته قلبی باشند و هر دقیقه تأخیر، به از دست رفتن بافت قلب منجر می‌شود.</p>
<p>«قلب، موتور حیات انسان است و مراقبت از آن، نه یک انتخاب، بلکه یک ضرورت است. در همراه کلینیک، ما با تلفیق دانش روز، تکنولوژی پیشرفته و تعهد انسانی، تلاش می‌کنیم تا بهترین مراقبت قلبی را در کنار بیمار و خانواده‌اش ارائه دهیم. پیشگیری همیشه بهتر از درمان است، اما در صورت بروز بیماری، زمان طلایی درمان، کلید نجات است.»</p>
<h2>جمع‌بندی نهایی</h2>
<p>به یاد داشته باشید که سلامت قلب، سرمایه‌ای است که باید از جوانی مراقبت آن را کرد. چکاپ منظم، سبک زندگی سالم و مراجعه به‌موقع به متخصص قلب، می‌تواند از بسیاری از عوارض جدی جلوگیری کند. همراه کلینیک با رویکرد پیشگیرانه و درمانی جامع، در تمامی مراحل حفظ و بازیابی سلامت قلب، همراه شما خواهد بود.</p>
<h3>همین امروز برای مشاوره تخصصی قلب اقدام کنید</h3>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/قلب-و-عروق/';

UPDATE pages SET body = '<h2>خدمات مشاوره و درمان آنکولوژی در همراه کلینیک</h2>
<p>همراه کلینیک با بهره‌گیری از <strong>پزشکان متخصص رادیو آنکولوژی</strong> و <strong>فوق تخصص هماتولوژی آنکولوژی</strong>، آماده ارائه انواع درمان‌های ترکیبی و تخصصی بر اساس آخرین دستورالعمل‌های اروپایی و آمریکایی می‌باشد. ما در کنار شما هستیم تا مسیر تشخیص تا درمان را با اطمینان و آرامش طی کنید.</p>
<p>از غربالگری دقیق تا درمان‌های هدفمند و مراقبت‌های حمایتی، همه‌چیز در یک مجموعه فراهم است. تیم ما با رویکردی چندتخصصی، برنامه‌ای شخصی‌سازی‌شده برای هر بیمار طراحی می‌کند.</p>
<p>
<strong>خدمات کلیدی:</strong> غربالگری، درمان و پیگیری انواع سرطان.</p>
<h2>آنکولوژی همراه کلینیک؛ تلفیق دانش روز و مراقبت انسانی</h2>
<p>در همراه کلینیک، ما درمان سرطان را فقط یک پروتکل پزشکی نمی‌دانیم؛ بلکه سفری همراه با بیمار و خانواده‌اش هستیم. واحد آنکولوژی ما با تکیه بر <strong>آخرین نسخه‌های راهنمای بالینی ESMO و NCCN</strong>، خدمات غربالگری، تشخیص، درمان و پیگیری را به صورت یکپارچه ارائه می‌دهد. تیم ما متشکل از رادیوآنکولوژیست‌ها، هماتولوژیست‌ آنکولوژیست، و پرستاران آموزش‌دیده، همه در کنار هم برای ارائه بهترین نتیجه ممکن تلاش می‌کنند.</p>
<p>یکی از مزیت‌های کلیدی ما، برگزاری جلسات <strong>تیم درمانی چندتخصصی (MDT)</strong> است که در آن هر پرونده به طور جامع و از ابعاد مختلف بررسی می‌شود. این رویکرد باعث می‌شود که هیچ گزینه درمانی بالقوه‌ای نادیده گرفته نشود و بیماران از بهترین ترکیب درمانی ممکن بهره‌مند شوند.</p>
<h2>خدمات جامع غربالگری، درمان و پیگیری</h2>
<p>
<strong>غربالگری</strong> اولین و حیاتی‌ترین گام در مبارزه با سرطان است. در همراه کلینیک، با استفاده از روش‌های پیشرفته تصویربرداری، تست‌های ژنتیکی و نشانگرهای توموری، ریسک ابتلا را شناسایی کرده و در صورت لزوم برنامه‌های پیشگیرانه را آغاز می‌کنیم. برای افرادی که سابقه خانوادگی دارند، پکیج‌های غربالگری تخصصی با فواصل زمانی معین طراحی می‌شود.</p>
<p>
<strong>درمان و پیگیری انواع سرطان</strong> با بهره‌گیری از روش‌های نوین شامل شیمی‌درمانی هدفمند، ایمونوتراپی، رادیوتراپی با دقت بالا، و درمان‌های هورمونی انجام می‌شود. ما به دنبال درمان نیستیم، بلکه به دنبال <strong>بهبود کیفیت زندگی</strong> در کنار افزایش طول عمر هستیم. برنامه پیگیری پس از درمان، با معاینات دوره‌ای و تست‌های منظم، عود مجدد را به حداقل می‌رساند.</p>
<ul>
<li>✅ مشاوره ژنتیک و تست‌های پیش‌بینی‌کننده</li>
<li>✅ برنامه‌های شیمی‌درمانی سرپایی با کمترین عوارض</li>
<li>✅ رادیوتراپی</li>
<li>✅ مراقبت‌های تسکینی و مدیریت درد</li>
</ul>
<h2>درمان‌های ترکیبی و فردمحور</h2>
<p>یکی از افتخارات همراه کلینیک، توانایی اجرای <strong>درمان‌های ترکیبی</strong> به صورت هماهنگ است. به عنوان مثال، برای بیماران مبتلا به سرطان پستان، ترکیب جراحی با رادیوتراپی و سپس هورمون‌درمانی یا ایمونوتراپی، بسته به پروفایل ژنتیکی تومور، به دقت برنامه‌ریزی می‌شود. این هماهنگی بین فوق‌تخصص‌ها، نتیجه‌ای بسیار بهتر از درمان‌های تکی دارد.</p>
<p>ما به آخرین یافته‌های بالینی در زمینه <strong>بیومارکرهای پیش‌بینی‌کننده پاسخ به درمان</strong> دسترسی داریم و از این دانش برای شخصی‌سازی دوز و نوع داروها استفاده می‌کنیم. این رویکرد نه تنها اثربخشی را بالا می‌برد، بلکه عوارض جانبی غیرضروری را نیز کاهش می‌دهد.</p>
<p>🧬</p>
<p>تشخیص دقیق</p>
<p>استفاده از پاتولوژی مولکولی و ایمونوهیستوشیمی</p>
<p>🎯</p>
<p>درمان هدفمند</p>
<p>داروهای هوشمند متناسب با جهش‌های تومور</p>
<p>🛡️</p>
<p>ایمن‌درمانی</p>
<p>فعال‌سازی سیستم ایمنی علیه سلول‌های سرطانی</p>
<p>📊</p>
<p>پیگیری هوشمند</p>
<p>اپلیکیشن اختصاصی برای ثبت علائم و یادآوری</p>
<p>🤝</p>
<p>حمایت روانی</p>
<p>جلسات مشاوره با روان‌آنکولوژیست</p>
<p>🧪</p>
<p>کارآزمایی بالینی</p>
<p>دسترسی به درمان‌های نوین و تحقیقاتی</p>
<table>
<thead>
<tr>
<th>خدمت</th>
<th>توضیحات</th>
<th>نیاز به بستری</th>
<th>پوشش بیمه</th>
</tr>
</thead>
<tbody>
<tr>
<td>غربالگری جامع</td>
<td>تست‌های ژنتیکی، تصویربرداری، نشانگرها</td>
<td>خیر</td>
<td>بسته به نوع بیمه</td>
</tr>
<tr>
<td>شیمی‌درمانی هدفمند</td>
<td>بر اساس پروفایل مولکولی تومور</td>
<td>سرپایی</td>
<td>بله (با محدودیت‌هایی)</td>
</tr>
<tr>
<td>رادیوتراپی (IMRT)</td>
<td>دقت بالا، آسیب کم به بافت سالم</td>
<td>خیر</td>
<td>بله</td>
</tr>
<tr>
<td>ایمونوتراپی</td>
<td>فعال‌سازی سلول‌های T</td>
<td>سرپایی</td>
<td>بله (با محدودیت)</td>
</tr>
<tr>
<td>مراقبت تسکینی</td>
<td>مدیریت درد، تهوع، خستگی</td>
<td>بسته به شرایط</td>
<td>بله</td>
</tr>
</tbody>
</table>
<p>💚 <strong>توصیه تخصصی</strong>:<br>
«انتخاب مرکز درمانی که به روزترین پروتکل‌ها را با رویکرد چندتخصصی اجرا می‌کند، نقشی تعیین‌کننده در نتیجه درمان دارد. در همراه کلینیک، ما هر بیمار را منحصربه‌فرد می‌بینیم و برنامه درمانی را دقیقاً برای او طراحی می‌کنیم.»</p>
<h2>جدیدترین رویکردها و ترندهای درمان سرطان</h2>
<h3>بیوپسی مایع<br>
جدید</h3>
<p>بیوپسی مایع یا <strong>ctDNA</strong>، انقلابی در پیگیری درمان ایجاد کرده است. با یک آزمایش خون ساده، می‌توان جهش‌های جدید تومور را شناسایی و مقاومت دارویی را پیش‌بینی کرد. در همراه کلینیک، این روش به طور روتین برای بیماران با ریسک بالا استفاده می‌شود و امکان تنظیم به موقع درمان را فراهم می‌آورد. این تکنیک تهاجم‌پذیری پایینی دارد و قابل تکرار است.</p>
<h3>درمان‌های اپی‌ژنتیک<br>
نوین</h3>
<p>داروهای اپی‌ژنتیک با تغییر الگوی بیان ژن‌ها، سلول‌های سرطانی را به حالت عادی بازمی‌گردانند. در همراه کلینیک، برای برخی از انواع سرطان‌های خون و لنفوم، از این ترکیبات به همراه ایمونوتراپی استفاده می‌کنیم. نتایج اولیه نشان‌دهنده افزایش چشمگیر پاسخ‌دهی در بیمارانی است که به درمان‌های معمول مقاوم بوده‌اند.</p>
<p>⚠️ نکته مهم: غربالگری منظم را جدی بگیرید. بسیاری از سرطان‌ها در مراحل اولیه قابل درمان هستند. همراه کلینیک برنامه‌های غربالگری سالیانه را با تخفیف ویژه برای افراد بالای ۴۰ سال ارائه می‌دهد (با هماهنگی بیمه).</p>
<h2>چک‌لیست انتخاب یک مرکز آنکولوژی معتبر</h2>
✔️ دسترسی به فوق‌تخصص‌های آنکولوژی
✔️ اجرای پروتکل‌های به‌روز بین‌المللی
✔️ تیم چندتخصصی و جلسات MDT منظم
✔️ برنامه مراقبت تسکینی و مدیریت عوارض
✔️ دسترسی به کارآزمایی‌های بالینی
✔️ پشتیبانی روانی و تغذیه‌ای
✔️ شفافیت در هزینه‌ها و پوشش بیمه
✔️ رضایت بیماران و نرخ موفقیت بالا
<h2>اشتباهات رایج بیماران و خانواده‌ها</h2>
<h3>اشتباهات در زمان‌بندی درمان</h3>
<ul>
<li>به تعویق انداختن شروع درمان به دلیل ترس از عوارض</li>
<li>قطع زودهنگام شیمی‌درمانی یا رادیوتراپی بدون مشورت پزشک</li>
<li>فاصله انداختن بین جلسات به دلیل تصور بهبودی</li>
<li>عدم پیگیری منظم پس از درمان کامل</li>
</ul>
<h3>اشتباهات در نگهداری و مراقبت</h3>
<ul>
<li>نادیده گرفتن علائم هشداردهنده مانند تب یا کاهش وزن</li>
<li>استفاده از مکمل‌های غیرمجاز بدون هماهنگی با تیم درمان</li>
<li>عدم توجه به بهداشت دهان و دندان در طی رادیوتراپی سر و گردن</li>
<li>کنار گذاشتن فعالیت بدنی به دلیل خستگی مفرط (بدون مشورت)</li>
</ul>
<p>🛑 هشدار ایمنی: هرگونه تغییر در برنامه درمانی (شامل کاهش دوز، تغییر فاصله جلسات، یا مصرف داروهای گیاهی) باید با پزشک معالج هماهنگ شود. خودسرانه‌ترین اقدامات می‌توانند اثربخشی درمان را به خطر بیندازند.</p>
<h2>جمع‌بندی</h2>
<p>انتخاب یک مرکز آنکولوژی معتبر، یکی از مهم‌ترین تصمیماتی است که بیمار و خانواده‌اش در مسیر درمان می‌گیرند. همراه کلینیک با <strong>تیم فوق‌تخصصی، تجهیزات پیشرفته، و رویکرد چندتخصصی</strong>، تمام تلاش خود را به کار گرفته است تا استانداردهای جهانی را در ایران پیاده‌سازی کند. از غربالگری دقیق تا درمان‌های ترکیبی و مراقبت‌های حمایتی، ما در هر قدم در کنار شما هستیم.</p>
<p>به یاد داشته باشید که درمان سرطان یک ماراتن است، نه یک دوی سرعت. با اتکا به دانش روز، همدلی تیم درمانی، و همراهی خانواده، می‌توان این مسیر را با امید و آرامش بیشتری طی کرد. اگر شما یا عزیزانتان به خدمات آنکولوژی نیاز دارید، همراه کلینیک آماده ارائه بهترین مراقبت‌ها بر اساس آخرین پروتکل‌های اروپایی و آمریکایی است. <strong>همین امروز برای مشاوره اقدام کنید.</strong>
</p>
<p>همین الان وقت مشاوره بگیرید</p>
<p>با کارشناسان ما تماس بگیرید یا از طریق سایت نوبت خود را رزرو کنید</p>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/آنکولوژی/';

UPDATE pages SET body = '<p>کلینیک فوق تخصصی همراه بخش شیمی‌درمانی خود را نیز با ۶ تخت در محیطی سرشار از انرژی، بر این مبنا بنا نهاد تا بیماران تحت درمان آنکولوژی تمام نیاز های درمانی خود را در محل کلینیک تامین کنند و از جابجایی های غیر ضروری در شهر خودداری کنند. در بخش شیمی‌درمانی درمانی کلینیک همراه از انواع شیوه های مدرن و به روز با توجه به نظر پزشک برای تزریق دارو بهره گیری می‌شود که می‌توان به استفاده از پمپ سرم، پمپ تزریق ۲۴ و ۴۸ ساعته، پورت، تزریق با سرم و پرفیوزر اشاره کرد. وجود پزشکان متخصص و فوق تخصص، پرستاران مجرب و بهیاران کاربلد در حین درمان آرامش بیمار را در حین گرفتن دارو تضمین می‌نماید.</p>
<h2>بخش شیمی‌درمانی همراه کلینیک</h2>
<p>بخش شیمی‌درمانی همراه کلینیک، یکی از پیشرفته‌ترین واحدهای درمانی است که با بهره‌گیری از تجهیزات مدرن، داروهای نسل جدید و تیمی متشکل از انکولوژیست‌های مجرب، خدمات تخصصی درمان سرطان را ارائه می‌دهد. در این مقاله، شما را با تمامی جنبه‌های این بخش، از فرآیند پذیرش تا مراقبت‌های پس از درمان، آشنا می‌کنیم تا با دیدی روشن‌تر و آگاهی کامل، مسیر درمان را آغاز کنید.</p>
<h2>شیمی‌درمانی چیست و چگونه عمل می‌کند؟</h2>
<p>شیمی‌درمانی یا کِموتراپی (Chemotherapy)، یکی از روش‌های اصلی درمان سرطان محسوب می‌شود که در آن از داروهای ضدسرطانی برای از بین بردن سلول‌های بدخیم یا مهار رشد آن‌ها استفاده می‌شود. این داروها معمولاً به صورت سیستمیک وارد بدن شده و از طریق جریان خون به تمامی بافت‌ها می‌رسند. هدف اصلی، تخریب سلول‌هایی است که با سرعت غیرطبیعی تکثیر می‌شوند.</p>
<p>در بخش شیمی‌درمانی همراه کلینیک، پروتکل‌های درمانی بر اساس نوع تومور، مرحله بیماری، سن بیمار و وضعیت عمومی سلامت او طراحی می‌شود. گاهی شیمی‌درمانی به تنهایی و گاهی در ترکیب با جراحی، پرتودرمانی یا ایمونوتراپی تجویز می‌گردد. انتخاب رژیم دارویی مناسب، نقشی کلیدی در موفقیت درمان دارد.</p>
<p>آیا می‌دانستید که امروزه با پیشرفت علم فارماکولوژی، عوارض جانبی شیمی‌درمانی به شکل چشمگیری کاهش یافته است؟ داروهای ضدتهوع نسل جدید، فاکتورهای رشد گلبولی و مراقبت‌های حمایتی، تجربه درمان را برای بیماران بسیار قابل تحمل‌تر کرده‌اند.</p>
<h2>فرآیند پذیرش و شروع درمان در همراه کلینیک</h2>
<p>اولین گام در مسیر شیمی‌درمانی، مراجعه به متخصص انکولوژی و تشکیل پرونده درمانی است. در این مرحله، مدارک پزشکی مانند پاتولوژی، تصویربرداری‌ها (سی‌تی‌اسکن، MRI، پت‌اسکن) و آزمایش‌های خون بررسی می‌شوند. سپس یک جلسه مشاوره تخصصی با حضور پزشک معالج، پرستار آنکولوژی و در صورت نیاز روان‌شناس بالینی برگزار می‌گردد.</p>
<p>پس از تعیین رژیم درمانی، اقداماتی نظیر کاشت پورت (Port) یا PICC برای دسترسی راحت‌تر وریدی انجام می‌شود. این کار از آسیب به رگ‌های محیطی جلوگیری کرده و فرآیند تزریق را ایمن‌تر می‌سازد. آزمایش‌های پایه شامل CBC، عملکرد کبد و کلیه نیز پیش از اولین سیکل درمان تکرار می‌شوند.</p>
<h2>امکانات و زیرساخت‌های بخش شیمی‌درمانی</h2>
<p>بخش شیمی‌درمانی همراه کلینیک با استانداردهای بین‌المللی طراحی شده و شامل سالن تزریق ، هود تخصصی شیمی درمانی ، پمپ سرم ، پرفیوزر و سیستم پایش مداوم علائم حیاتی است. تمامی پمپ‌های سرم انفوزیون از نوع هوشمند بوده و دوز دارو با دقت بالا تنظیم می‌شود.</p>
<p>💊</p>
<h3>داروهای هدفمند</h3>
<p>استفاده از جدیدترین داروهای Targeted Therapy و ایمونوتراپی مطابق با پروتکل‌های NCCN و ESMO</p>
<p>🩺</p>
<h3>تیم چندتخصصی</h3>
<p>همکاری انکولوژیست، کاردیوآنکولوژیست ، جراح، متخصص تغذیه ، روان پزشک ، متخصص غدد ، متخصص عفونی و پرستار متخصص شیمی درمانی</p>
<p>🧪</p>
<h3>آزمایشگاه مرجع</h3>
<p>انجام تست‌های ژنتیک، مارکرهای توموری و بررسی حساسیت دارویی در کوتاه‌ترین زمان</p>
<p>🛏️</p>
<h3>سالن شیمی درمانی مجهز</h3>
<p>مبل‌های طبی و فضای آرام برای کاهش استرس حین دریافت دارو</p>
<p>📊</p>
<h3>پایش هوشمند</h3>
<p>مانیتورینگ مداوم علائم حیاتی و ثبت الکترونیک تمامی مراحل درمان در صورت نیاز</p>
<p>🤝</p>
<h3>مشاوره روان‌شناختی</h3>
<p>پشتیبانی روانی از بیمار و خانواده در تمامی مراحل درمان توسط متخصص بالینی</p>
<h3>توصیه تخصصی انکولوژیست</h3>
<p>پیش از شروع هرگونه رژیم شیمی‌درمانی، انجام تست‌های مولکولی و ژنتیکی بر روی نمونه تومور بسیار حیاتی است. این تست‌ها امکان انتخاب درمان‌های هدفمند و کاهش عوارض جانبی را فراهم می‌کنند. همچنین حفظ وضعیت تغذیه‌ای مناسب و فعالیت بدنی ملایم در طول دوره درمان، تأثیر مستقیمی بر موفقیت پروتکل درمانی دارد.</p>
<h2>جدیدترین ترندها و مدل‌های درمانی در شیمی‌درمانی</h2>
<h3>ایمونوتراپی ترکیبی (Immunotherapy Combination)</h3>
<p>ایمونوتراپی با مهار نقاط بازدارنده سیستم ایمنی (Checkpoints) مانند PD-1 و CTLA-4، انقلابی در درمان سرطان‌های پیشرفته ایجاد کرده است. در همراه کلینیک، ترکیب ایمونوتراپی با شیمی‌درمانی کلاسیک برای سرطان‌های ریه، پستان سه‌گانه منفی و ملانوما با موفقیت بالایی به کار می‌رود. این رویکرد، پاسخ درمانی را به شکل معناداری افزایش می‌دهد.</p>
<h3>درمان‌های هدفمند مولکولی (Targeted Therapy)</h3>
<p>داروهای مهارکننده تیروزین کیناز (TKI)، مهارکننده‌های PARP و آنتی‌بادی‌های مونوکلونال، نمونه‌هایی از درمان‌های هدفمند هستند که به‌طور اختصاصی سلول‌های سرطانی را هدف قرار می‌دهند. این داروها با کاهش آسیب به بافت‌های سالم، عوارض جانبی کمتری نسبت به شیمی‌درمانی سنتی دارند.</p>
<h3>شیمی‌درمانی هیپرترمیک داخل صفاقی (HIPEC)</h3>
<p>این روش نوین، مخصوص سرطان‌های منتشرشده در حفره شکمی نظیر سرطان تخمدان، آپاندیس و پریتون است. در این تکنیک، داروی شیمی‌درمانی گرم‌شده به‌طور مستقیم داخل حفره صفاق تزریق می‌شود و غلظت بالایی از دارو در محل تومور ایجاد می‌کند. همراه کلینیک از معدود مراکزی است که این پروتکل را با تجهیزات پیشرفته ارائه می‌دهد.</p>
<h3>نکته مهم</h3>
<p>هرگز بدون مشورت با انکولوژیست معالج خود از مکمل‌های گیاهی، ویتامین‌های با دوز بالا یا داروهای غیرتخصصی در طول دوره شیمی‌درمانی استفاده نکنید، برخی از این مواد می‌توانند با داروهای ضدسرطانی تداخل داشته و اثربخشی درمان را کاهش دهند یا عوارض را تشدید کنند.</p>
<h2>چک‌لیست انتخاب بخش شیمی‌درمانی مناسب</h2>
<p>✅ همکاری انکولوژیست، کاردیوآنکولوژیست ، جراح، متخصص تغذیه ، روان پزشک ، متخصص غدد ، متخصص عفونی و پرستار متخصص شیمی درمانی</p>
<p>✅ دسترسی به آزمایشگاه پاتولوژی مولکولی و تست‌های ژنتیک پیشرفته</p>
<p>✅ استفاده از داروهای تأییدشده توسط FDA و EMA</p>
<p>✅ وجود پمپ‌های انفوزیون هوشمند و سیستم پایش علائم حیاتی</p>
<p>✅ پشتیبانی روان‌شناختی و تغذیه‌ای برای بیمار و خانواده</p>
<p>✅ امکان دریافت درمان‌های هدفمند و ایمونوتراپی</p>
<p>✅ پوشش بیمه‌ای گسترده</p>
<h2>اشتباهات رایج در مسیر شیمی‌درمانی</h2>
<h3>اشتباهات در شروع درمان</h3>
<ul>
<li>عدم انجام تست‌های مولکولی پیش از شروع درمان و انتخاب رژیم غیرهدفمند</li>
<li>پنهان کردن سابقه مصرف داروهای گیاهی یا مکمل‌ها از پزشک معالج</li>
<li>تأخیر غیرمنطقی در شروع درمان به بهانه جستجوی روش‌های جایگزین اثبات‌نشده</li>
<li>عدم مشورت دوم (Second Opinion) در موارد پیچیده و نادر</li>
<li>انتخاب مرکز درمانی فاقد تجهیزات کافی و تیم تخصصی</li>
</ul>
<h3>اشتباهات در طول دوره درمان و مراقبت</h3>
<ul>
<li>نادیده گرفتن علائم هشداردهنده مانند تب بالای ۳۸ درجه یا خونریزی غیرطبیعی</li>
<li>عدم رعایت بهداشت دست و پرهیز از تماس با افراد مبتلا به عفونت</li>
<li>مصرف غذاهای خام، نیم‌پز یا غیربهداشتی در دوران نوتروپنی</li>
<li>قطع خودسرانه داروهای حمایتی مانند ضدتهوع یا فاکتورهای رشد</li>
<li>انجام فعالیت‌های سنگین ورزشی بدون مشورت با تیم درمان</li>
<li>عدم مراجعه به‌موقع برای آزمایش‌های بینابین سیکل‌ها</li>
</ul>
<h3>هشدار ایمنی</h3>
<p>در صورت بروز هر یک از این علائم بلافاصله با پزشک خود تماس بگیرید: تب بالای ۳۸ درجه، تنگی نفس ناگهانی، درد قفسه سینه، خونریزی شدید، استفراغ غیرقابل کنترل بیش از ۲۴ ساعت، یا کاهش شدید ادرار. این علائم می‌توانند نشانه عوارض جدی باشند و نیاز به مداخله فوری پزشکی دارند.</p>
<p>«موفقیت در درمان سرطان، تنها به دارو وابسته نیست؛ بلکه ترکیبی از دانش تیم پزشکی، پایبندی بیمار به پروتکل، حمایت خانواده و مراقبت‌های حمایتی است. همراه کلینیک با رویکرد جامع‌نگر، تمامی این ابعاد را در کنار هم قرار می‌دهد.»</p>
<h2>جمع‌بندی نهایی</h2>
<p>بخش شیمی‌درمانی همراه کلینیک با تلفیقی از دانش روز انکولوژی، تجهیزات پیشرفته و تیمی مجرب، محیطی امن و حرفه‌ای را برای بیماران سرطانی فراهم کرده است. از لحظه تشخیص تا پایان درمان و پیگیری‌های پس از آن، تمامی نیازهای پزشکی، روانی و حمایتی بیمار در نظر گرفته می‌شود. رویکرد چندتخصصی و استفاده از درمان‌های نوین نظیر ایمونوتراپی و درمان‌های هدفمند، افق‌های تازه‌ای را در مبارزه با سرطان پیش روی بیماران قرار داده است.</p>
<p>به یاد داشته باشید که سرطان دیگر به معنای پایان راه نیست؛ با انتخاب مرکز درمانی مناسب، پایبندی به پروتکل درمانی و حفظ امید، می‌توان به نتایج بسیار مطلوبی دست یافت. همراه کلینیک در تمامی این مسیر، با تعهد و دلسوزی در کنار شما خواهد بود تا بهترین نتیجه درمانی حاصل شود.</p>
<h3>همین امروز برای مشاوره رایگان اقدام کنید</h3>
<p>همراه کلینیک آماده پاسخگویی به سوالات شما و تنظیم نوبت ویزیت میباشد</p>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>
<p>&#8220;`</p>' WHERE path = '/service/شیمی-درمانی/';

UPDATE pages SET body = '<h2>خدمات پزشک هماتولوژی &#8211; از تشخیص تا درمان اختلالات خونی</h2>
<p>هماتولوژی بالینی در همراه کلینیک، فراتر از یک آزمایش ساده است. این بخش تخصصی به بررسی دقیق سلول‌های خونی، مغز استخوان و ارائه راهکارهای درمانی برای اختلالات انعقادی، ایمنی و <strong>بدخیمی‌های خونی</strong> می‌پردازد.<br>
ما با بهره‌گیری از تیم متخصص و تجهیزات پیشرفته، خدماتی جامع در زمینه تشخیص و درمان بیماری‌های خونی ارائه می‌دهیم.</p>
<p>از مدیریت کم‌خونی‌های مقاوم تا انجام پروسیجرهای تخصصی مانند شیمی‌درمانی، بیوپسی مغز استخوان و فصد خون، تمامی اقدامات در محیطی کاملاً بهداشتی و تحت نظارت مستقیم پزشک متخصص انجام می‌شود.</p>
<h2>اهمیت مراقبت‌های تخصصی هماتولوژی</h2>
<p>بسیاری از بیماری‌های خونی نیازمند مداخله سریع و دقیق هستند. کم‌خونی‌های فقر آهن که به درمان‌های معمول پاسخ نمی‌دهند، تالاسمی‌ها، یا اختلالات پلاکتی از جمله مواردی هستند که در کلینیک همراه با رویکردی درمانی و حمایتی مدیریت می‌شوند.</p>
<p>در این بخش، علاوه بر تفسیر دقیق آزمایش‌ها، پروسیجرهای درمانی حیاتی مانند تزریق وریدی آهن، فصد خون (برای غلظت خون بالا) و شروع دوره‌های شیمی‌درمانی با بالاترین استانداردهای ایمنی انجام می‌پذیرد.</p>
<h2>خدمات تخصصی و پروسیجرهای بالینی</h2>
<p>ما در همراه کلینیک، طیف وسیعی از خدمات درمانی و تشخیصی را ذیل بخش هماتولوژی ارائه می‌دهیم. تمرکز ما بر ارائه درمان‌های هدفمند، شیمی‌درمانی ایمن و کاهش عوارض بیماری‌های خونی است.</p>
💊
شیمی‌درمانی و ایمونوتراپی
درمان لوسمی، لنفوم و میلوما و سرطان های سایر قسمت های بدن
🦴
بیوپسی مغز استخوان
نمونه‌برداری دقیق توسط متخصص
💉
تزریق آهن وریدی
درمان سریع کم‌خونی‌های مقاوم
🩸
فصد خون (Therapeutic Phlebotomy)
کنترل غلظت خون و پلی‌سیتمی
🧬
الکتروفورز هموگلوبین
تشخیص تالاسمی و هموگلوبینوپاتی‌ها
⚖️
مدیریت اختلالات انعقادی
تنظیم دوز داروهای رقیق‌کننده خون
🩺
مشاوره تخصصی خون
بررسی لام خون توسط هماتولوژیست
🛡️
مدیریت عوارض جانبی
کنترل تهوع، عفونت و درد حین درمان
📋
تفسیر جامع آزمایش
ارائه نقشه راه درمانی شخصی‌سازی شده
<table>
<thead>
<tr>
<th>خدمت / پروسیجر</th>
<th>کاربرد اصلی</th>
<th>مدت زمان انجام</th>
<th>نیاز به آمادگی</th>
</tr>
</thead>
<tbody>
<tr>
<td>شیمی‌درمانی سرپایی</td>
<td>درمان سرطان‌های خون و لنفوم و سرطان های سایر قسمت های بدن</td>
<td>۲ تا ۴ ساعت (بسته به پروتکل)</td>
<td>آزمایش خون روز تزریق</td>
</tr>
<tr>
<td>تزریق آهن وریدی</td>
<td>درمان کم‌خونی شدید و مقاوم</td>
<td>۳۰ تا ۶۰ دقیقه</td>
<td>تست حساسیت اولیه</td>
</tr>
<tr>
<td>فصد خون</td>
<td>کاهش غلظت خون (Polycythemia)</td>
<td>۲۰ تا ۴۰ دقیقه</td>
<td>مصرف مایعات قبل از عمل</td>
</tr>
<tr>
<td>بیوپسی مغز استخوان</td>
<td>تشخیص علل ناشناخته کم‌خونی/سرطان</td>
<td>۴۵ دقیقه (با بی‌حسی)</td>
<td>بررسی فاکتورهای انعقادی</td>
</tr>
</tbody>
</table>
<p>💡 توصیه پزشک متخصص</p>
<p>«افرادی که مرتباً احساس خستگی مفرط، تنگی نفس یا سرگیجه دارند، نباید تنها به مصرف قرص آهن اکتفا کنند. در کلینیک همراه، با انجام بررسی‌های تکمیلی و در صورت نیاز تزریق وریدی آهن، سطح انرژی و سلامت خون شما در کوتاه‌ترین زمان ممکن بازیابی می‌شود.»</p>
<h2>رویکردهای نوین در درمان‌های خونی</h2>
<h3>شیمی‌درمانی ایمن و هدفمند<br>
آنکولوژی</h3>
<p>درمان سرطان‌های خون (لوسمی و لنفوم) و سرطان های سایر قسمت های بدن در همراه کلینیک با استفاده از جدیدترین پروتکل‌های جهانی انجام می‌شود.<br>
اتاق‌های شیمی‌درمانی ما مجهز به صندلی‌های راحت و سیستم‌های مانیتورینگ حیاتی هستند تا بیمار در طول دریافت دارو احساس آرامش و امنیت کامل داشته باشد.</p>
<h3>درمان‌های هدفمند مولکولی<br>
پیشرفته</h3>
<p>امروزه درمان بسیاری از بدخیمی‌های خونی از شیمی‌درمانی‌های عمومی به سمت داروهای هدفمند تغییر کرده است.<br>
در همراه کلینیک، با بررسی دقیق پروفایل ژنتیکی بیمار، بهترین گزینه درمانی با کمترین عوارض جانبی انتخاب می‌شود.</p>
<h3>جایگزینی مؤثر آهن وریدی<br>
درمانی</h3>
<p>برای بیمارانی که جذب گوارشی ضعیفی دارند یا به قرص آهن حساسیت نشان می‌دهند، تزریق آهن‌های نسل جدید (مانند فروسوکربوکسیمالت) در کلینیک همراه، سطح ذخایر آهن را در چند جلسه به طور چشمگیری افزایش می‌دهد.</p>
<p>⭐️ نکته مهم برای بیماران</p>
<p>قبل از انجام پروسیجرهایی مانند فصد خون، بیوپسی یا شروع شیمی‌درمانی، حتماً سوابق دارویی خود (به ویژه داروهای رقیق‌کننده خون مثل آسپرین یا وارفارین) را به پزشک اطلاع دهید. ایمنی شما اولویت اصلی تیم پزشکی همراه کلینیک است.</p>
<h2>چرا خدمات هماتولوژی همراه کلینیک؟</h2>
<ul>
<li>✓ انجام پروسیجرها توسط پزشک متخصص</li>
<li>✓ محیط کاملاً استریل</li>
<li>✓ استفاده از جدیدترین فرمولاسیون‌های دارویی</li>
<li>✓ کاهش درد و استرس در حین نمونه‌برداری</li>
<li>✓ پیگیری مستمر پس از تزریق یا فصد</li>
<li>✓ مشاوره تغذیه‌ای مکمل برای بیماران خونی</li>
</ul>
<h2>باورهای غلط در مورد بیماری‌های خونی</h2>
<h4>غلط: &#8220;فصد خون باعث ضعف می‌شود&#8221;</h4>
<p>برعکس، در افراد دارای غلظت خون بالا، فصد خون باعث بهبود جریان خون‌رسانی به مغز و کاهش سردردهای مزمن می‌شود. این کار باید تحت نظر پزشک و با حجم کنترل شده انجام شود.</p>
<h4>غلط: &#8220;شیمی‌درمانی همیشه غیرقابل تحمل است&#8221;</h4>
<p>با پیشرفت داروهای ضدتهوع و حمایتی، امروزه بسیاری از بیماران دوره‌های شیمی‌درمانی را با عوارض بسیار کم و کیفیت زندگی مناسب سپری می‌کنند. تیم ما در همراه کلینیک تمام تلاش خود را برای مدیریت این عوارض به کار می‌گیرد.</p>
<p>🚨 هشدار ایمنی در پروسیجرهای خونی</p>
<p>تمامی اقدامات تهاجمی مانند بیوپسی یا تزریق‌های شیمی‌درمانی باید در محیطی انجام شود که امکانات احیا و مدیریت شوک آلرژیک وجود داشته باشد. همراه کلینیک با داشتن اتاق پروسیجر مجهز، امنیت کامل شما را تضمین می‌کند.</p>
<h2>جمع‌بندی</h2>
<p>بخش هماتولوژی همراه کلینیک، با تلفیق دانش روز و تجربه بالینی، آماده ارائه خدمات درمانی و پروسیجرهای تخصصی خونی است.<br>
هدف ما تنها تشخیص نیست، بلکه بازگرداندن کیفیت زندگی به بیماران مبتلا به اختلالات خونی از طریق درمان‌های مؤثر، شیمی‌درمانی ایمن و مراقبت‌های کم‌عارضه است.</p>
<p>برای دریافت مشاوره، انجام فصد خون، تزریق آهن یا شروع درمان‌های تخصصی سرطان خون و یا سرطان های سایر قسمت های بدن با ما در تماس باشید.</p>
<p>دریافت نوبت فوری از پزشک هماتولوژی</p>
<p>همین حالا با همراه کلینیک تماس بگیرید و سلامت خون خود را به متخصصین بسپارید.</p>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/هماتولوژی/';

UPDATE pages SET body = '<p>دپارتمان اعصاب و روان کلینیک فوق تخصصی همراه با بهره‌گیری از متخصصین روانپزشک، علاوه بر سرویس دهی به مراجعین اعصاب و روان، آماده سرویس دهی به کلیه بخشها، خصوصا بخش‌های مرتبط با سرطان، رژیم درمانی و قلب و عروق می‌باشد.</p>
<h2>بخش روان‌پزشکی همراه کلینیک</h2>
<p>بخش روان‌پزشکی همراه کلینیک، واحدی تخصصی است که با هدف ارائه خدمات جامع تشخیص، درمان و توانبخشی اختلالات روانی در کنار سایر تخصص‌های پزشکی فعالیت می‌کند. این بخش با بهره‌گیری از روان‌پزشکان مجرب ، رویکردی چندبعدی به سلامت روان دارد.</p>
<h2>ساختار و تشکیلات بخش روان‌پزشکی در کلینیک</h2>
<p>‫بخش روان‌پزشکی در همراه کلینیک، فراتر از یک مطب ساده عمل می‌کند. این واحد با ادغام تخصص روان‌پزشکی در دلِ تیم چندتخصصی قلب و عروق، بستری را فراهم می‌آورد که بیمار بتواند جنبه‌های روانی بیماری‌های جسمی خود را نیز تحت نظر داشته باشد. در بسیاری از موارد، استرس و اضطراب ناشی از بیماری‌های قلبی یا پروسه درمان سرطان، نیازمند مداخله همزمان روان‌پزشک است تا کیفیت درمان افزایش یابد.<br>
در این بخش، روان‌پزشک متخصص مسئولیت ارزیابی دقیق، تشخیص اختلالات خلقی و اضطرابی و در صورت نیاز، تجویز و مدیریت درمان دارویی را بر عهده دارد.</p>
<p>تمرکز اصلی بر ایجاد ارتباط موثر با سایر اعضای تیم درمان (مانند متخصصان انکولوژی ، هماتولوژی ، قلب، غدد و تغذیه) است تا تداخلات دارویی کنترل شده و سلامت روان بیمار به عنوان بخشی جدایی‌ناپذیر از سلامت کلی او مدیریت شود.<br>
فضای مشاوره در این بخش با رعایت کامل استانداردهای حریم خصوصی و آرامش طراحی شده است تا بیمار بتواند با احساس امنیت و اعتماد، مسائل خود را با پزشک مطرح کند.</p>
<p>این رویکرد حمایتی، به ویژه برای بیماران مبتلا به بیماری‌های مزمن مانند نارسایی قلبی یا سرطان، نقش حیاتی در بهبود روند درمان و افزایش تاب‌آوری آن‌ها ایفا می‌کند.</p>
<h2>طیف خدمات ارائه‌شده در بخش روان‌پزشکی</h2>
<p>خدمات این بخش را می‌توان به سه دسته اصلی تقسیم کرد: خدمات تشخیصی، خدمات درمانی و خدمات پیشگیرانه. در بخش تشخیصی، ارزیابی بالینی جامع (Clinical Interview) انجام می‌شود که شامل مصاحبه ساختاریافته، تست‌های روان‌سنجی و در صورت نیاز، تصویربرداری عصبی است.</p>
<p>در بخش درمانی، دارودرمانی (Psychopharmacology) با استفاده از داروهای ضدافسردگی، ضدروان‌پریشی، تثبیت‌کننده خلق و ضد اضطراب انجام می‌شود. همزمان، روان‌درمانی‌های فردی، گروهی، زوج‌درمانی و خانواده‌درمانی نیز ارائه می‌گردد. رویکردهای نوین مانند EMDR برای تروما، DBT برای اختلال شخصیت مرزی و ACT برای پذیرش و تعهد نیز در کلینیک‌های پیشرو در دسترس هستند.</p>
<p>خدمات پیشگیرانه نیز شامل آموزش مهارت‌های مقابله‌ای، مدیریت استرس، پیشگیری از عود در بیماران دوقطبی و اسکیزوفرنی، و غربالگری اختلالات خلقی در گروه‌های پرخطر است. این خدمات به کاهش بار بیماری و هزینه‌های درمانی بلندمدت کمک می‌کنند.</p>
<h2>ویژگی‌های کلیدی یک بخش روان‌پزشکی استاندارد</h2>
🔒
<h3>رازداری و محرمانگی</h3>
<p>پایبندی کامل به اصول اخلاق حرفه‌ای و حفظ اطلاعات بیمار</p>
📋
<h3>پرونده الکترونیک یکپارچه</h3>
<p>ثبت دقیق سوابق، داروها و روند درمان در سامانه دیجیتال</p>
🧪
<h3>آزمایش‌های مکمل</h3>
<p>انجام تست‌های تیروئید، سطح دارو و بررسی‌های متابولیک</p>
🤝
<h3>رویکرد بیمار-محور</h3>
<p>طرح درمان شخصی‌سازی‌شده بر اساس نیازهای منحصربه‌فرد هر فرد</p>
<h3>توصیه تخصصی</h3>
<p>برای شروع فرآیند درمان، بهتر است ابتدا به یک کلینیک چندتخصصی مراجعه کنید تا در صورت نیاز، سایر ارزیابی‌های پزشکی نیز به‌صورت همزمان انجام شود. این رویکرد از دوباره‌کاری جلوگیری کرده و تشخیص دقیق‌تری ارائه می‌دهد.</p>
<h3>نکته مهم</h3>
<p>هرگز درمان دارویی خود را بدون مشورت با روان‌پزشک قطع یا تغییر ندهید. قطع ناگهانی برخی داروها مانند SSRIها می‌تواند منجر به سندرم قطع (Discontinuation Syndrome) شود که علائمی مانند سرگیجه، تهوع و شوک‌های الکتریکی مغز را به همراه دارد.</p>
<h2>چک‌لیست انتخاب بخش روان‌پزشکی مناسب</h2>
✓<br>
داشتن روان‌پزشک دارای بورد تخصصی و عضو انجمن روان‌پزشکی
✓<br>
دسترسی به پرونده الکترونیک یکپارچه و محرمانه
✓<br>
برنامه‌ریزی برای جلسات پیگیری منظم و ارزیابی مجدد
✓<br>
آموزش به بیمار و خانواده درباره بیماری و روند درمان
✓<br>
هماهنگی با سایر متخصصان (قلب ، غدد و&#8230;)
<h2>اشتباهات رایج در ارتباط با بخش روان‌پزشکی</h2>
<h3>اشتباهات در شروع درمان</h3>
<ul>
<li>انتظار بهبودی فوری پس از جلسه اول؛ درمان روان‌پزشکی زمان‌بر است.</li>
<li>مقایسه درمان خود با دیگران؛ هر فرد پاسخ متفاوتی به دارو و روان‌درمانی دارد.</li>
<li>پنهان‌کردن علائم یا مصرف مواد از درمانگر؛ صداقت کلید تشخیص دقیق است.</li>
<li>تغییر مکرر درمانگر بدون دادن فرصت کافی به هر کدام.</li>
</ul>
<h3>اشتباهات در ادامه و نگهداری درمان</h3>
<ul>
<li>قطع خودسرانه دارو پس از احساس بهبودی نسبی.</li>
<li>عدم مراجعه برای جلسات پیگیری و ارزیابی دوره‌ای.</li>
<li>ترکیب داروهای تجویزی با مکمل‌های گیاهی بدون اطلاع پزشک.</li>
<li>نادیده‌گرفتن عوارض جانبی و عدم گزارش آن به درمانگر.</li>
<li>تکیه صرف بر دارو و نپذیرفتن روان‌درمانی مکمل.</li>
</ul>
<h3>هشدار ایمنی</h3>
<p>در صورت داشتن افکار خودکشی، آسیب به دیگران یا علائم روان‌پریشی حاد (مانند توهم یا هذیان)، فوراً با اورژانس اجتماعی (۱۲۳) یا اورژانس پزشکی (۱۱۵) تماس بگیرید. این شرایط نیازمند مداخله فوری هستند و نباید منتظر نوبت مطب بمانید.</p>
<blockquote>
<p>«سلامت روان، بخش جدایی‌ناپذیر از سلامت عمومی است. کلینیکی موفق است که روان‌پزشکی را نه به‌عنوان یک جزیره مجزا، بلکه به‌عنوان بخشی از یک اکوسیستم درمانی یکپارچه ببیند.»</p>
</blockquote>
<h2>جمع‌بندی نهایی</h2>
<p>بخش روان‌پزشکی همراه کلینیک، نقطه اتصال مهمی میان سلامت جسم و روان است. این بخش با ارائه خدمات تشخیصی دقیق، درمان‌های دارویی و غیردارویی مبتنی بر شواهد، و رویکرد چندتخصصی، به بیماران کمک می‌کند تا کیفیت زندگی بهتری داشته باشند. انتخاب یک کلینیک با استانداردهای مناسب، تیم متخصص مجرب و امکانات تشخیصی کامل، می‌تواند تأثیر چشمگیری بر روند بهبودی داشته باشد.</p>
<p>به‌یاد داشته باشید که مراجعه به روان‌پزشک نشانه ضعف نیست، بلکه نشان‌دهنده بلوغ فکری و اهمیت دادن به سلامت خود است. با آگاهی از ساختار بخش، خدمات ارائه‌شده، ترندهای نوین و نکات کلیدی انتخاب، می‌توانید تصمیمی هوشمندانه برای مراقبت از سلامت روان خود و عزیزانتان بگیرید. درمان به‌موقع، کلید پیشگیری از مزمن‌شدن اختلالات روانی است.</p>
<h3>همین امروز برای سلامت روان خود اقدام کنید</h3>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/روان-پزشکی/';

UPDATE pages SET body = '<h2>بخش روان‌شناسی بالینی</h2>
<p>دپارتمان روان‌شناسی <strong>کلینیک فوق تخصصی همراه</strong> با رویکردی چندوجهی و مبتنی بر شواهد علمی روز، فراتر از خدمات سنتی مشاوره عمل می‌کند. این بخش با تلفیق تخصص‌های بالینی، شناختی و صنعتی-سازمانی، بستری جامع برای ارتقای سلامت روان مراجعان حین درمان‌های پزشکی (به‌ویژه در حوزه‌های آنکولوژی، قلب و اعصاب) و همچنین ارائه راهکارهای نوین به سازمان‌ها فراهم آورده است.</p>
<p>
<strong>چشم‌انداز ما:</strong> ارائه خدمات روان‌شناختی دقیق از طریق ارزیابی‌های استاندارد، روان‌درمانی‌های تخصصی (MCT و EFT) و اجرای پروژه‌های بهبود کیفیت تجربه مراجع و سلامت نیروی انسانی در محیط‌های درمانی و سازمانی.</p>
<h2>خدمات تخصصی و متمایز ما</h2>
<p>بر خلاف مراکز معمول، خدمات این بخش بر پایه پروتکل‌های دقیق تشخیصی و درمانی طراحی شده است:</p>
<h3>روان‌درمانی تخصصی (MCT &amp; EFT)</h3>
<p>استفاده از رویکردهای پیشرفته <strong>فراشناخت‌درمانی (MCT)</strong> برای مدیریت نشخوار فکری و اضطراب، و <strong>درمان هیجان‌مدار (EFT)</strong> برای تنظیم هیجانات عمیق و بهبود روابط بین‌فردی.</p>
<h3>ارزیابی‌های روان‌سنجی دقیق</h3>
<p>اجرای آزمون‌های استاندارد و معتبر جهانی شامل ارزیابی شخصیت، ساختارهای شناختی، هوش هیجانی، میزان استرس و فرسودگی شغلی با تفسیر تخصصی.</p>
<h3>سلامت سازمانی و توسعه منابع انسانی</h3>
<p>طراحی برنامه‌های ارتقای تاب‌آوری کارکنان، مدیریت استرس شغلی، ارزیابی صلاحیت‌های روان‌شناختی مدیران و بهبود تجربه مشتری (CX) در سازمان‌ها با مدل‌های علمی.</p>
<h3>حمایت روان‌شناختی بیماران مزمن</h3>
<p>خدمات ویژه برای افزایش تاب‌آوری و کاهش پریشانی روانی در بیماران تحت درمان‌های قلبی، سرطانی (آنکولوژی) و نورولوژیک.</p>
<h2>ابزارها و متدولوژی‌های مورد استفاده</h2>
<p>ما در فرآیند ارزیابی و درمان از ترکیب روش‌های کمی و کیفی بهره می‌بریم تا دقت تشخیص و اثربخشی درمان را به حداکثر برسانیم:</p>
<ul>
<li>✅ <strong>تست‌های روان‌سنجی:</strong> استفاده از پرسشنامه‌های چندمحوری شخصیت، مقیاس‌های افسردگی و اضطراب بک، و آزمون‌های شناختی کامپیوتری.</li>
<li>✅ <strong>مصاحبه‌های تشخیصی ساختاریافته:</strong> انجام مصاحبه‌های عمیق بالینی برای تدوین طرح درمان شخصی‌سازی شده (Case Formulation).</li>
</ul>
<h3>چرا رویکرد ما متفاوت است؟</h3>
<p>ترکیب دانش <strong>روانشناسی بالینی</strong> با اصول <strong>مدیریت و رفتار سازمانی</strong> به ما این امکان را می‌دهد که نه تنها به درمان فرد بپردازیم، بلکه ریشه‌های محیطی و سیستمیک مشکلات (مانند استرس شغلی یا نارضایتی از خدمات) را نیز شناسایی و اصلاح کنیم.</p>
<h2>این بخش برای چه کسانی مناسب است؟</h2>
<table>
<thead>
<tr>
<th>مخاطب هدف</th>
<th>نیاز اصلی</th>
<th>راهکار پیشنهادی ما</th>
</tr>
</thead>
<tbody>
<tr>
<td>
<strong>بیماران تحت درمان</strong>
</td>
<td>مدیریت ترس، اضطراب و افسردگی ناشی از بیماری</td>
<td>مشاوره حمایتی، تکنیک‌های آرام‌سازی و MCT</td>
</tr>
<tr>
<td>
<strong>سازمان‌ها و شرکت‌ها</strong>
</td>
<td>کاهش فرسودگی شغلی و افزایش بهره‌وری</td>
<td>کارگاه‌های مدیریت استرس، ارزیابی سرمایه انسانی</td>
</tr>
<tr>
<td>
<strong>مدیران و رهبران</strong>
</td>
<td>تصمیم‌گیری بهتر و هوش هیجانی بالا</td>
<td>کوچینگ روان‌شناختی و ارزیابی‌های شخصیت</td>
</tr>
<tr>
<td>
<strong>عموم مراجعان</strong>
</td>
<td>اختلالات اضطرابی، وسواس، مشکلات رابطه</td>
<td>روان‌درمانی EFT و CBT استاندارد</td>
</tr>
</tbody>
</table>' WHERE path = '/service/روان-شناسی/';

UPDATE pages SET body = '<h2>بخش تخصصی تغذیه و رژیم‌درمانی بالینی همراه کلینیک</h2>
<p>بخش تغذیه و رژیم‌درمانی کلینیک همراه، واحدی کاملاً بالینی است که بر پایه اصول <strong>رژیم‌درمانی پزشکی (MNT)</strong> فعالیت می‌کند. تفاوت اصلی این بخش با مشاوره‌های معمولی در آن است که تمرکز ما صرفاً بر کاهش وزن نیست؛ بلکه هدف اصلی، مدیریت بیماری‌های مزمن از طریق تنظیم دقیق درشت‌مغذی‌ها، ریزمغذی‌ها و الگوهای غذایی است.</p>
<p>در کلینیک فوق تخصصی همراه، تیم تغذیه به صورت ایزوله عمل نمی‌کند. ما با همکاری تنگاتنگ با پزشکان متخصص بخش‌های <strong>قلب، انکولوژی (سرطان)، عفونی و غدد</strong>، پروتکل‌های غذایی دقیقی را طراحی می‌کنیم که نه تنها با داروهای بیمار تداخل نداشته باشد، بلکه اثرگذاری درمان‌های پزشکی را افزایش دهد.</p>
<p>بخش تخصصی تغذیه همراه کلینیک، بازوی مشورتی قدرتمند برای سایر بخش‌های درمانی است. رویکرد ما «تغذیه درمانی پزشکی» است؛ یعنی استفاده از غذا به عنوان بخشی از پروسه درمان. ارزیابی دقیق وضعیت بیمار، بررسی پرونده پزشکی و مصاحبه بالینی عمیق، پایه‌های اصلی طراحی رژیم درمانی شما هستند.</p>
<h2>ساختار بالینی و همکاری بین‌رشته‌ای</h2>
<p>بخش تغذیه در کلینیک همراه، یک واحد کاملاً بالینی است که با استانداردهای متفاوت از یک مطب معمولی تغذیه طراحی شده است. فرآیند پذیرش با یک غربالگری پزشکی آغاز می‌شود. در این مرحله، سابقه بیماری‌های فرد، داروهای مصرفی (از جمله داروهای تأثیرگذار بر اشتها و متابولیسم)، سوابق جراحی، و نتایج آزمایش‌های اخیر مانند قند ناشتا، HbA1c، پروفایل چربی، آنزیم‌های کبدی، اوره و کراتینین، ویتامین D، B12 و تیروئید بررسی می‌شود.</p>
<p>تیم ما متشکل از متخصصین تغذیه با پروانه رسمی است که به صورت روزانه با پزشکان بخش‌های زیر در ارتباط هستند:</p>
<ul>
<li>
<strong>بخش انکولوژی:</strong> طراحی رژیم‌های ضد التهاب و پرپروتئین برای مقابله با کاچکسی (تحلیل عضلانی) ناشی از سرطان و کاهش تهوع شیمی‌درمانی.</li>
<li>
<strong>بخش قلب و عروق:</strong> تدوین رژیم‌های کم‌سدیم و کنترل چربی برای بیماران دارای فشار خون بالا، نارسایی قلبی و پس از عمل جراحی قلب.</li>
<li>
<strong>بخش غدد و متابولیسم:</strong> مدیریت دقیق کربوهیدرات‌ها برای بیماران دیابتی، تنظیم رژیم در اختلالات تیروئید و سندرم تخمدان پلی‌کیستیک (PCOS).</li>
<li>
<strong>بخش عفونی:</strong> تقویت سیستم ایمنی از طریق ریزمغذی‌ها برای بیماران مبتلا به عفونت‌های مزمن یا حاد.</li>
</ul>
<h2>طیف خدمات تخصصی و بیماری‌های تحت پوشش</h2>
<p>رژیم‌درمانی پزشکی (MNT) طیف وسیعی از بیماری‌ها را پوشش می‌دهد که هر کدام پروتکل اختصاصی خود را دارند. خدمات ما بر پایه ارزیابی‌های بالینی دقیق استوار است:</p>
<p>🩺</p>
<h3>ارزیابی بالینی دقیق</h3>
<p>بررسی تاریخچه پزشکی، داروها، علائم فیزیکی و تفسیر آزمایش‌های خون</p>
<p>💊</p>
<h3>مدیریت تداخلات دارو-غذا</h3>
<p>تنظیم زمان مصرف غذا و دارو برای حداکثر جذب و حداقل عوارض جانبی</p>
<p>🥗</p>
<h3>رژیم‌درمانی بیماری‌های خاص</h3>
<p>رژیم‌های اختصاصی برای کلیه، کبد چرب، گوارش و بیماری‌های خودایمنی</p>
<p>🧠</p>
<h3>مشاوره تغییر سبک زندگی</h3>
<p>اصلاح رفتارهای غذایی غلط و آموزش مهارت‌های انتخاب غذای سالم</p>
<h2>مقایسه رویکرد رژیم‌درمانی در بیماری‌های مختلف</h2>
<table>
<thead>
<tr>
<th>بخش مرتبط / بیماری</th>
<th>چالش تغذیه‌ای بیمار</th>
<th>راهکار کلینیک همراه</th>
</tr>
</thead>
<tbody>
<tr>
<td>
<strong>انکولوژی (سرطان)</strong>
</td>
<td>بی‌اشتهایی، زخم دهان، تهوع شدید</td>
<td>رژیم‌های نرم، پرکالری، تقسیم وعده‌های کوچک و مکرر</td>
</tr>
<tr>
<td>
<strong>قلب و عروق</strong>
</td>
<td>احتباس مایعات، فشار خون بالا</td>
<td>کنترل دقیق سدیم، پتاسیم و مایعات ورودی (رژیم DASH)</td>
</tr>
<tr>
<td>
<strong>غدد (دیابت)</strong>
</td>
<td>نوسانات قند خون، مقاومت انسولینی</td>
<td>محاسبه دقیق شاخص گلیسمی (GI) و شمارش کربوهیدرات</td>
</tr>
<tr>
<td>
<strong>بیماری کلیوی (CKD)</strong>
</td>
<td>انباشت سموم، اختلال الکترولیت‌ها</td>
<td>کنترل دقیق پروتئین، پتاسیم و فسفر بر اساس مرحله بیماری</td>
</tr>
<tr>
<td>
<strong>کبد چرب (NAFLD)</strong>
</td>
<td>تجمع چربی در کبد، التهاب</td>
<td>حذف فروکتوز صنعتی، کاهش وزن تدریجی و رژیم مدیترانه‌ای</td>
</tr>
</tbody>
</table>
<h3>چرا مشاوره تخصصی بهتر از دستگاه است؟</h3>
<p>دستگاه‌ها تنها اعداد را نشان می‌دهند، اما متخصص تغذیه &#8220;بیمار&#8221; را می‌بیند. در کلینیک همراه، ما با بررسی آزمایش‌های خون و داروهای شما، رژیمی می‌نویسیم که نه تنها وزن شما را مدیریت کند، بلکه با داروهایتان تداخل نداشته باشد و روند درمان بیماری اصلی‌تان را تسریع بخشد.</p>
<h2>ویژگی‌های کلیدی بخش تغذیه استاندارد</h2>
<p>🎓</p>
<h3>متخصص دارای پروانه رسمی</h3>
<p>متخصص تغذیه بالینی و رژیم درمانی از دانشگاه علوم پزشکی تهران</p>
<p>🔬</p>
<h3>تفسیر آزمایش‌های بالینی</h3>
<p>امکان درخواست و تفسیر دقیق آزمایش‌های متابولیک و ریزمغذی</p>
<p>💻</p>
<h3>نرم‌افزار آنالیز ریزمغذی</h3>
<p>استفاده از نرم‌افزارهای معتبر برای محاسبه دقیق دریافت‌های غذایی</p>
<p>📋</p>
<h3>رژیم شخصی‌سازی‌شده</h3>
<p>طراحی برنامه بر اساس سن، جنس، فعالیت، بیماری و ترجیحات غذایی</p>
<p>🔄</p>
<h3>پیگیری دوره‌ای منظم</h3>
<p>جلسات پیگیری هفتگی یا ماهانه برای تعدیل رژیم و پایش پیشرفت</p>
<p>🤝</p>
<h3>همکاری بین‌رشته‌ای</h3>
<p>ارتباط مستقیم با پزشک غدد، گوارش، قلب و انکولوژی</p>
<h2>جدیدترین مدل‌ها و ترندهای تغذیه بالینی</h2>
<h3>۱. تغذیه شخصی‌سازی‌شده بر اساس ژنتیک (Nutrigenomics)</h3>
<p>تغذیه ژنتیکی یا Nutrigenomics، رویکردی نوین است که با تحلیل ژن‌های مرتبط با متابولیسم، حساسیت به کافئین، عدم تحمل لاکتوز، و پاسخ به چربی‌ها و کربوهیدرات‌ها، رژیم را به‌صورت کاملاً شخصی‌سازی‌شده طراحی می‌کند. کلینیک‌های پیشرو در حال همکاری با آزمایشگاه‌های ژنتیک برای ارائه این خدمات هستند.</p>
<h3>۲. تغذیه مبتنی بر میکروبیوم روده</h3>
<p>پژوهش‌های اخیر نشان می‌دهند که میکروبیوم روده نقش کلیدی در تنظیم وزن، خلق‌وخو، سیستم ایمنی و حتی پاسخ به رژیم‌های غذایی دارد. آنالیز میکروبیوم و طراحی رژیم‌های حاوی پری‌بیوتیک‌ها و پروبیوتیک‌های اختصاصی، یکی از جذاب‌ترین ترندهای تغذیه بالینی است.</p>
<h3>۳. رژیم‌درمانی ضدالتهابی (Anti-Inflammatory Diet)</h3>
<p>التهاب مزمن زمینه بسیاری از بیماری‌ها از جمله دیابت، بیماری‌های قلبی و سرطان است. رژیم‌های ضدالتهابی با تمرکز بر اسیدهای چرب امگا ۳، آنتی‌اکسیدان‌ها و ادویه‌هایی مانند زردچوبه، به کاهش مارکرهای التهابی کمک می‌کنند.</p>
<h3>نکته مهم</h3>
<p>مکمل‌های غذایی جایگزین رژیم متعادل نیستند. مصرف خودسرانه مکمل‌هایی مانند ویتامین D، آهن، یا مکمل‌های بدنسازی بدون انجام آزمایش خون و نظارت متخصص، می‌تواند منجر به مسمومیت، تداخل دارویی و عوارض جدی شود. همیشه قبل از مصرف هر مکملی، با متخصص تغذیه مشورت کنید.</p>
<h2>چک‌لیست انتخاب بخش تغذیه مناسب</h2>
<p>✓<br></p>
<p>داشتن متخصص تغذیه</p>
<p>✓<br></p>
<p>تسلط بر رژیم‌درمانی بیماری‌های خاص (دیابت، کلیوی، کبدی و&#8230;)</p>
<p>✓<br></p>
<p>بررسی دقیق آزمایش‌های خون و تفسیر آن‌ها در طراحی رژیم</p>
<p>✓<br></p>
<p>بررسی تداخلات دارو-تغذیه و مکمل‌های مصرفی</p>
<p>✓<br></p>
<p>ارائه پروتکل مکتوب با محاسبه دقیق درشت‌مغذی‌ها و ریزمغذی‌ها</p>
<p>✓<br></p>
<p>هماهنگی مستقیم با پزشک معالج بیمار</p>
<p>✓<br></p>
<p>جلسات پیگیری منظم با فاصله ۲ تا ۴ هفته</p>
<p>✓<br></p>
<p>آموزش عملی به بیمار و خانواده درباره پخت‌وپز درمانی</p>
<p>✓<br></p>
<p>استفاده از گایدلاین‌های معتبر بین‌المللی (ADA, KDIGO, AASLD)</p>
<h2>اشتباهات رایج در ارتباط با بخش تغذیه</h2>
<h3>اشتباهات در شروع رژیم و انتخاب متخصص</h3>
<ul>
<li>مراجعه به افراد بدون مدرک علمی (مربی ورزش، بلاگر، عطاری) برای دریافت رژیم.</li>
<li>انتظار کاهش وزن سریع؛ کاهش وزن سالم ۰.۵ تا ۱ کیلوگرم در هفته است.</li>
<li>پنهان‌کردن بیماری‌های زمینه‌ای، داروهای مصرفی یا عادات غذایی واقعی.</li>
<li>کپی‌برداری از رژیم افراد دیگر بدون در نظر گرفتن تفاوت‌های فردی.</li>
<li>آغاز رژیم در دوران استرس شدید یا بحران‌های روانی بدون آمادگی ذهنی.</li>
</ul>
<h3>اشتباهات در ادامه و نگهداری رژیم</h3>
<ul>
<li>قطع ناگهانی رژیم پس از رسیدن به هدف، بدون مرحله تثبیت (Maintenance).</li>
<li>وزن‌کردن روزانه و نوسان خلقی بر اساس عدد ترازو (وزن روزانه تا ۲ کیلو نوسان طبیعی دارد).</li>
<li>حذف کامل گروه‌های غذایی مانند کربوهیدرات یا چربی بدون دلیل پزشکی.</li>
<li>مصرف بی‌رویه مکمل‌ها و چربی‌سوزها بدون نظارت متخصص.</li>
<li>نادیده‌گرفتن سیگنال‌های گرسنگی و سیری طبیعی بدن و پایبندی خشک به گرم‌های رژیم.</li>
<li>عدم ثبت دقیق غذاها؛ پژوهش‌ها نشان می‌دهند ثبت غذایی، موفقیت را تا ۲ برابر افزایش می‌دهد.</li>
</ul>
<h3>هشدار ایمنی</h3>
<p>در بیماران دیابتی تحت درمان با انسولین، تغییر ناگهانی در رژیم غذایی می‌تواند منجر به هیپوگلیسمی شدید شود. در بیماران کلیوی، مصرف خودسرانه غذاهای پرپتاسیم مانند موز و پرتقال می‌تواند باعث آریتمی قلبی کشنده شود. هرگونه تغییر در رژیم باید تحت نظارت متخصص انجام شود.</p>
<blockquote>
<p>«تغذیه بالینی، علم تطبیق غذا با فیزیولوژی منحصربه‌فرد هر فرد است. یک رژیم خوب، رژیمی نیست که همه را لاغر کند، بلکه رژیمی است که سلامت را پایدار کند و با سبک زندگی فرد سازگار باشد. کلینیکی موفق است که این تفاوت‌ها را محترم بشمارد.»</p>
</blockquote>
<h2>جمع‌بندی نهایی</h2>
<p>بخش تخصصی تغذیه و رژیم‌درمانی همراه کلینیک، نقطه اتصال مهمی میان علم تغذیه و سلامت پایدار است. این بخش با ارائه خدمات ارزیابی دقیق، رژیم‌درمانی پزشکی مبتنی بر شواهد، و رویکردهای نوین مانند تغذیه ژنتیکی و کرونو-تغذیه، به مراجعان کمک می‌کند تا نه تنها به وزن مطلوب برسند، بلکه سلامت متابولیک، انرژی روزانه و کیفیت زندگی خود را ارتقا دهند. انتخاب یک کلینیک با متخصص دارای پروانه، و رویکرد شخصی‌سازی‌شده، می‌تواند تفاوت چشمگیری در موفقیت بلندمدت ایجاد کند.</p>
<p>به‌یاد داشته باشید که تغذیه سالم، یک رژیم موقت نیست، بلکه سبک زندگی است. با آگاهی از ساختار بخش، انواع رژیم‌های درمانی، ترندهای نوین و نکات کلیدی انتخاب، می‌توانید تصمیمی هوشمندانه برای سلامت خود و خانواده‌تان بگیرید. مراجعه به متخصص تغذیه، سرمایه‌گذاری بلندمدتی است که بازگشت آن در پیشگیری از بیماری‌های مزمن، افزایش طول عمر و بهبود کیفیت زندگی، چندین برابر هزینه آن خواهد بود.</p>
<h3>همین امروز برای سلامت تغذیه‌ای خود اقدام کنید</h3>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/تغذیه/';

UPDATE pages SET body = '<h2>بخش طب ایرانی همراه کلینیک | طب سنتی مبتنی بر شواهد برای بیماران سرطانی</h2>
<p>بخش طب ایرانی در کلینیک فوق تخصصی، با بهره‌گیری از پزشکان متخصص طب ایرانی، آماده همراهی بیماران سرطانی در مسیر درمان جهت کاهش عوارض درمان‌های شیمی‌درمانی و رادیوتراپی است. این بخش با رویکرد علمی و مبتنی بر شواهد، به کمک تغییر سبک زندگی به شیوه صحیح طب سنتی ایرانی، از اشتباهات متداول احتمالی در استفاده از درمان‌های گیاهی توسط افراد غیرمتخصص جلوگیری می‌کند. خدمات این بخش توسط برترین اساتید هیئت علمی دانشگاه علوم پزشکی شهید بهشتی ارائه می‌شود.</p>
<h2>کلینیک سبک زندگی بیماران مبتلا به سرطان</h2>
<p>همراه شما برای داشتن درمانی مؤثرتر و زندگی باکیفیت‌تر</p>
<p>در این کلینیک، پزشکان ما با روش‌های علمی و رویکرد طب تلفیقی، به شما آموزش می‌دهند تا با تغییرات ساده در سبک زندگی:</p>
<p>✓ کاهش عوارض شیمی‌درمانی</p>
<p>✓ کاهش عوارض پرتودرمانی</p>
<p>✓ تحمل بهتر روند درمان</p>
<p>✓ احساس آرامش و امید بیشتر در مسیر درمان</p>
<p>«ما باور داریم آگاهی، بخشی از درمان است»</p>
<p>با راهکارهای علمی و طبیعی در زندگی روزمره، در مسیر درمان در کنار شما هستیم.</p>
<h2>ساختار و فلسفه بخش طب ایرانی در کلینیک سرطان</h2>
<p>بخش طب ایرانی در این کلینیک، برخلاف تصور رایج از طب سنتی، یک واحد کاملاً علمی و آکادمیک است که تحت نظارت اساتید هیئت علمی دانشگاه علوم پزشکی شهید بهشتی فعالیت می‌کند. فلسفه اصلی این بخش، نه جایگزینی درمان‌های مدرن سرطان، بلکه تکمیل و حمایت از آن‌ها است. هدف، کاهش عوارض جانبی شیمی‌درمانی و پرتودرمانی، بهبود کیفیت زندگی بیمار، و تقویت توان بدن برای تحمل بهتر روند درمان است.</p>
<h2>طیف خدمات ارائه‌شده در بخش طب ایرانی</h2>
<p>خدمات این بخش را می‌توان در چهار دسته اصلی طبقه‌بندی کرد: تدابیر غذایی (غذاداروها)، تدابیر دارویی (گیاهان دارویی و ترکیبات)، تدابیر یداوی (درمان‌های دستی و فیزیکی)، و اصلاح سته ضروریه (شش عامل اساسی سلامت). در بخش تدابیر غذایی، برای هر بیمار بر اساس مزاج و مرحله درمان، برنامه غذایی اختصاصی طراحی می‌شود. به‌عنوان مثال، برای کاهش تهوع ناشی از شیمی‌درمانی، مصرف زنجبیل، نعناع، و آب انار ترش توصیه می‌شود. برای مقابله با خستگی و ضعف، غذاهای گرم و تر مانند سوپ گوشت گوسفند با ادویه‌های گرم مانند زعفران و دارچین تجویز می‌گردد.</p>
<p>در بخش تدابیر دارویی، از گیاهان دارویی با پشتوانه علمی استفاده می‌شود. برای تقویت سیستم ایمنی، گیاهانی مانند آستراگالوس (گون)، جینسینگ، و قارچ ری شی پیشنهاد می‌شوند. برای کاهش التهاب، زردچوبه (کورکومین) و کندر کاربرد دارند. برای بهبود خواب و کاهش اضطراب، سنبل‌الطیب، بادرنجبویه و گل‌گاوزبان تجویز می‌شوند. اما نکته حیاتی این است که تمام این گیاهان باید با نظارت پزشک متخصص و با در نظر گرفتن تداخلات دارویی با شیمی‌درمانی مصرف شوند. به‌عنوان مثال، برخی گیاهان ممکن است با داروهای شیمی‌درمانی تداخل داشته و اثربخشی آن‌ها را کاهش دهند.</p>
<p>تدابیر یداوی شامل حجامت، بادکش، فصد، و ماساژ درمانی با روغن‌های گیاهی است. برای بیماران سرطانی، حجامت و فصد تنها در شرایط خاص و با احتیاط فراوان انجام می‌شود، زیرا ممکن است خطر خونریزی یا عفونت را افزایش دهد. اما بادکش خشک و ماساژ با روغن‌های گرم مانند روغن سیاه‌دانه یا روغن کنجد، برای کاهش درد، بهبود گردش خون، و کاهش استرس بسیار مفید است. اصلاح سته ضروریه نیز شامل تنظیم هوا (استنشاق بخورات گیاهی)، خوراک (رژیم غذایی)، حرکت (ورزش‌های سبک مانند پیاده‌روی و یوگا)، خواب (تنظیم الگوی خواب)، دفع (مدیریت یبوست و اسهال)، و اعراض نفسی (مدیریت استرس و اضطراب) است.</p>
<h2>ویژگی‌های کلیدی بخش طب ایرانی استاندارد</h2>
<p>🎓</p>
<h3>پزشکان متخصص هیئت علمی</h3>
<p>اساتید دانشگاه علوم پزشکی شهید بهشتی با فلوشیپ طب ایرانی</p>
<p>🔬</p>
<h3>رویکرد مبتنی بر شواهد</h3>
<p>استفاده از گیاهان دارویی با پشتوانه پژوهش‌های علمی معتبر</p>
<p>🤝</p>
<h3>هماهنگی با انکولوژیست</h3>
<p>ارتباط مستقیم با پزشک انکولوژیست برای جلوگیری از تداخلات</p>
<p>📋</p>
<h3>ارزیابی مزاجی دقیق</h3>
<p>تشخیص مزاج با استفاده از معاینه نبض، ادرار و علائم بالینی</p>
<p>🌿</p>
<h3>داروهای گیاهی استاندارد</h3>
<p>استفاده از فرآورده‌های گیاهی تأییدشده با کیفیت تضمین‌شده</p>
<p>📊</p>
<h3>پایش مستمر و تعدیل درمان</h3>
<p>جلسات پیگیری منظم برای ارزیابی اثربخشی و ایمنی درمان</p>
<h3>توصیه تخصصی</h3>
<p>هرگز بدون مشورت با پزشک متخصص طب ایرانی، گیاهان دارویی را همزمان با شیمی‌درمانی مصرف نکنید. برخی گیاهان مانند گریپ‌فروت، سبزیجات چلیپایی (کلم، بروکلی) و جینسینگ می‌توانند با داروهای شیمی‌درمانی تداخل داشته و اثربخشی آن‌ها را کاهش یا عوارض آن‌ها را افزایش دهند. زمان‌بندی مصرف گیاهان دارویی نیز اهمیت دارد؛ معمولاً باید حداقل ۲۴ تا ۴۸ ساعت فاصله بین شیمی‌درمانی و مصرف گیاهان وجود داشته باشد.</p>
<h2>جدیدترین رویکردها در طب ایرانی برای بیماران سرطانی</h2>
<h3>۱. طب ایرانی مبتنی بر ژنتیک و بیومارکرها</h3>
<p>یکی از جدیدترین رویکردها، تلفیق مزاج‌شناسی سنتی با یافته‌های ژنتیک مدرن است. پژوهش‌ها نشان می‌دهند که برخی پروفایل‌های ژنتیکی با مزاج‌های خاص همبستگی دارند. به‌عنوان مثال، افرادی با پروفایل التهابی بالا (CRP بالا) معمولاً مزاج صفراوی دارند و به گیاهان ضدالتهابی مانند کورکومین و کندر بهتر پاسخ می‌دهند. این رویکرد شخصی‌سازی‌شده، اثربخشی درمان را به‌طور قابل‌توجهی افزایش می‌دهد و در کلینیک‌های پیشرو در حال اجرا است.</p>
<h3>۲. استفاده از نانوتکنولوژی در داروهای گیاهی</h3>
<p>فناوری نانو به‌عنوان یک رویکرد نوین در فرمولاسیون داروهای گیاهی، می‌تواند با بهبود حلالیت، پایداری و نفوذپذیری غشایی، فراهمی زیستی و در نتیجه اثربخشی بسیاری از ترکیبات گیاهی را افزایش دهد. در مورد کورکومین، مطالعات متعددی نشان داده‌اند که برخی نانوفرمولاسیون‌ها فراهمی زیستی این ترکیب را نسبت به شکل معمولی آن به‌طور قابل‌توجهی (گاهی تا چندین برابر) افزایش می‌دهند، هرچند میزان دقیق این افزایش به نوع نانوحامل و طراحی مطالعه وابسته است.</p>
<p>نانوذرات حاوی عصاره یا اجزای فعال کندر و سایر گیاهان ضدالتهاب نیز در مدل‌های آزمایشگاهی و پیش‌بالینی برای بررسی اثرات ضدالتهابی و ایمنی‌تعدیل‌کننده در حال ارزیابی هستند و نتایج اولیه امیدوارکننده‌اند، اما برای تعمیم بالینی به کارآزمایی‌های کنترل‌شده انسانی بیشتری نیاز است.</p>
<p>به‌طور کلی، نانوفورمولاسیون‌ها این پتانسیل را دارند که با افزایش فراهمی زیستی، امکان دستیابی به اثرات درمانی با دوزهای پایین‌تر را فراهم کنند و الگوی عوارض ناخواسته را تغییر دهند، هرچند تأثیر آن‌ها بر تداخلات دارویی باید برای هر فرآورده به‌طور اختصاصی و بر اساس شواهد فارماکوکینتیک و بالینی ارزیابی شود.</p>
<h3>۳. رویکرد روان‌تنی (Psychosomatic) در طب ایرانی</h3>
<p>طب ایرانی همواره بر ارتباط تن و روان تأکید داشته است. در رویکرد نوین، تکنیک‌های مدیریت استرس مانند مدیتیشن مبتنی بر متون کهن ایرانی، تنفس عمیق، و موسیقی‌درمانی با سازهای سنتی، در کنار درمان‌های گیاهی برای بهبود کیفیت زندگی بیماران استفاده می‌شوند. پژوهش‌ها نشان می‌دهند که این رویکرد یکپارچه، نه‌تنها علائم فیزیکی، بلکه افسردگی و اضطراب مرتبط با سرطان را نیز به‌طور معناداری کاهش می‌دهد.</p>
<h3>نکته مهم</h3>
<p>طب ایرانی به‌هیچ‌وجه جایگزین درمان‌های مدرن سرطان (جراحی، شیمی‌درمانی، پرتودرمانی، ایمونوتراپی) نیست. این طب به‌عنوان یک رویکرد مکمل و حمایتی عمل می‌کند که هدف آن کاهش عوارض درمان‌های مدرن و بهبود کیفیت زندگی بیمار است. هرگونه تصمیم برای تغییر یا قطع درمان‌های مدرن باید صرفاً با مشورت پزشک انکولوژیست گرفته شود.</p>
<h2>چک‌لیست انتخاب بخش طب ایرانی مناسب برای بیماران سرطانی</h2>
<p>✓<br></p>
<p>داشتن پزشک متخصص طب ایرانی با فلوشیپ و مدرک معتبر</p>
<p>✓<br></p>
<p>عضویت پزشک در هیئت علمی دانشگاه علوم پزشکی</p>
<p>✓<br></p>
<p>هماهنگی مستقیم با پزشک انکولوژیست بیمار</p>
<p>✓<br></p>
<p>ارائه پروتکل درمانی مکتوب و شفاف</p>
<p>✓<br></p>
<p>استفاده از گیاهان دارویی استاندارد و تأییدشده</p>
<p>✓<br></p>
<p>بررسی دقیق تداخلات دارو-گیاه قبل از تجویز</p>
<p>✓<br></p>
<p>جلسات پیگیری منظم برای پایش اثربخشی و ایمنی</p>
<p>✓<br></p>
<p>آموزش کامل به بیمار و خانواده درباره تدابیر خانگی</p>
<p>✓<br></p>
<p>پرهیز از فروش اجباری محصولات گیاهی خاص</p>
<h2>اشتباهات رایج در استفاده از طب ایرانی برای بیماران سرطانی</h2>
<h3>اشتباهات در شروع درمان</h3>
<ul>
<li>مراجعه به افراد غیرمتخصص (عطاری، اینفلوئنسرهای شبکه‌های اجتماعی) برای دریافت درمان گیاهی.</li>
<li>قطع خودسرانه درمان‌های مدرن (شیمی‌درمانی، پرتودرمانی) به بهانه استفاده از طب سنتی.</li>
<li>مصرف همزمان ده‌ها گیاه دارویی بدون نظارت پزشک (خطر تداخلات دارویی).</li>
<li>استفاده از دوزهای بسیار بالای گیاهان به امید اثر سریع‌تر (خطر مسمومیت).</li>
<li>نادیده‌گرفتن تداخلات دارو-گیاه و عدم اطلاع‌رسانی به پزشک انکولوژیست.</li>
</ul>
<h3>اشتباهات در ادامه و نگهداری درمان</h3>
<ul>
<li>توقف ناگهانی درمان گیاهی بدون مشورت با پزشک پس از احساس بهبودی نسبی.</li>
<li>عدم پایش منظم آزمایش‌های خون برای بررسی تأثیر گیاهان بر کبد و کلیه.</li>
<li>استفاده از گیاهان دارویی با منبع نامشخص (خطر آلودگی به فلزات سنگین یا سموم قارچی).</li>
<li>نادیده‌گرفتن علائم هشداردهنده مانند زردی پوست، تهوع شدید، یا تغییر در آزمایش‌های کبدی.</li>
<li>انتظار معجزه فوری؛ طب ایرانی یک رویکرد تدریجی است و نیازمند صبر و پایبندی است.</li>
<li>عدم رعایت تدابیر سته ضروریه (مانند تغذیه نامناسب یا خواب ناکافی) که اثربخشی درمان را کاهش می‌دهد.</li>
</ul>
<h3>هشدار ایمنی</h3>
<p>برخی گیاهان دارویی می‌توانند با شیمی‌درمانی تداخل خطرناک داشته باشند. به‌عنوان مثال، گیاهان حاوی آنتی‌اکسیدان‌های قوی (مانند دوز بالای ویتامین C، E، یا عصاره چای سبز) ممکن است اثربخشی برخی داروهای شیمی‌درمانی را کاهش دهند. گیاهانی مانند سنت جانز وورت (علف چای) می‌توانند متابولیسم داروها را تسریع کرده و سطح خونی آن‌ها را کاهش دهند. همیشه قبل از مصرف هر گیاه دارویی، با پزشک متخصص طب ایرانی و انکولوژیست مشورت کنید.</p>
<blockquote>
<p>«طب ایرانی یک گنجینه ارزشمند است، اما باید با زبان علم روز ترجمه شود. برای بیماران سرطانی، هنر ما در تلفیق حکمت طب سنتی با دقت پزشکی مدرن است. هدف ما نه جایگزینی، بلکه تکمیل درمان است تا بیمار نه‌تنها زنده بماند، بلکه با کیفیت بهتری زندگی کند.»</p>
</blockquote>
<h2>جمع‌بندی نهایی</h2>
<p>بخش طب ایرانی همراه کلینیک، با رویکردی علمی و مبتنی بر شواهد، پلی میان حکمت طب سنتی ایران و پزشکی مدرن است. این بخش با بهره‌گیری از تخصص اساتید هیئت علمی دانشگاه علوم پزشکی شهید بهشتی، به بیماران سرطانی کمک می‌کند تا عوارض شیمی‌درمانی و پرتودرمانی را بهتر تحمل کنند، کیفیت زندگی خود را ارتقا دهند، و با تغییر سبک زندگی به شیوه صحیح، مسیر درمان را با آرامش و امید بیشتری طی کنند. تدابیر غذایی، گیاهان دارویی استاندارد، درمان‌های یداوی، و اصلاح سته ضروریه، ابزارهای اصلی این بخش برای دستیابی به این اهداف هستند.</p>
<p>به‌یاد داشته باشید که طب ایرانی یک رویکرد مکمل است و هرگز نباید جایگزین درمان‌های مدرن سرطان شود. موفقیت در این مسیر نیازمند همکاری نزدیک بین بیمار، پزشک انکولوژیست، و متخصص طب ایرانی است. با انتخاب یک کلینیک معتبر با پزشکان متخصص و مجرب، می‌توانید مطمئن باشید که تدابیر تجویز‌شده نه‌تنها بی‌خطر، بلکه کاملاً متناسب با شرایط پزشکی منحصربه‌فرد شما هستند. آگاهی، بخشی از درمان است و ما در کنار شما هستیم تا این مسیر را با اعتماد و آرامش طی کنید.</p>
<h3>همین امروز برای بهبود کیفیت زندگی خود اقدام کنید</h3>
<p>برای دریافت نوبت ارزیابی مزاجی و مشاوره با متخصصان طب ایرانی کلینیک، روی دکمه زیر کلیک کنید.</p>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/طب-ایرانی/';

UPDATE pages SET body = '<p>🩺 مرکز تخصصی تشخیص و درمان واریس و بیماری‌های عروقی</p>
<h2>کلینیک واریس همراه؛ همراه گام‌های سالم شما</h2>
<p>اگر از درد، سنگینی، خستگی پاها، تورم، گرفتگی‌های شبانه، رگ‌های برجسته یا واریس رنج می‌برید، کلینیک فوق تخصصی همراه با بهره‌گیری از تجهیزات پیشرفته و پزشکان باتجربه، مسیر تشخیص دقیق و درمان مؤثر را برای شما هموار می‌کند.</p>
<p>📍 قلب تجریش<br></p>
<p>⚡ درمان سرپایی و کم‌تهاجمی<br></p>
<p>👨‍⚕️ پزشکان فوق تخصص</p>
<h2>کلینیک واریس چیست و چرا اهمیت دارد؟</h2>
<p>واریس تنها یک مشکل ظاهری نیست؛ بلکه نشانه‌ای از نارسایی عملکردی در سیستم وریدی بدن است. زمانی که دریچه‌های یک‌طرفهٔ وریدها ضعیف می‌شوند، خون در پاها تجمع پیدا می‌کند و فشار داخل رگ‌ها بالا می‌رود. نتیجهٔ این فرایند، رگ‌های برجسته، درد مزمن، تورم، تغییر رنگ پوست و در موارد پیشرفته، زخم‌های دیردرمان است. یک <strong>کلینیک واریس</strong> تخصصی، با رویکردی چندبعدی به این بیماری نگاه می‌کند؛ از تصویربرداری دقیق با سونوگرافی داپلر گرفته تا انتخاب روش درمانی متناسب با شدت بیماری و سبک زندگی بیمار.</p>
<p>در کلینیک فوق تخصصی همراه، تشخیص و درمان بیماری‌های وریدی و شریانی در محیطی آرام، حرفه‌ای و کاملاً مجهز انجام می‌شود. هدف ما بازگرداندن کیفیت زندگی، کاهش درد و جلوگیری از عوارض طولانی‌مدت است؛ به‌طوری‌که بیمار در کوتاه‌ترین زمان ممکن به فعالیت روزمره بازگردد.</p>
<p>
<a>
</a>
</p>
<h2>چه علائمی شما را به کلینیک واریس می‌رساند؟</h2>
<p>🦵</p>
<h3>درد و سنگینی پاها</h3>
<p>احساس خستگی و سنگینی به‌ویژه در پایان روز، علامت کلاسیک نارسایی وریدی است.</p>
<p>💧</p>
<h3>تورم مچ و ساق پا</h3>
<p>ادم مزمن اندام تحتانی، به‌خصوص پس از ایستادن طولانی، نشانهٔ مهمی از تجمع مایع میان‌بافتی است.</p>
<p>🕸️</p>
<h3>رگ‌های عنکبوتی و برجسته</h3>
<p>تلانژکتازی‌ها و واریس‌های سطحی هم جنبهٔ زیبایی و هم جنبهٔ درمانی دارند.</p>
<p>⚡</p>
<h3>گرفتگی‌های شبانه</h3>
<p>اسپاسم‌های مکرر عضلات ساق در شب، اغلب با نارسایی وریدی ارتباط مستقیم دارد.</p>
<p>🩹</p>
<h3>تغییر رنگ پوست و زخم</h3>
<p>تیره شدن پوست اطراف مچ و بروز زخم‌های وریدی، نشان‌دهندهٔ مرحلهٔ پیشرفتهٔ بیماری است.</p>
<p>🔥</p>
<h3>احساس گرما و خارش</h3>
<p>التهاب موضعی روی رگ‌های واریسی می‌تواند با خارش و احساس حرارت همراه باشد.</p>
<h2>خدمات تخصصی در کلینیک واریس همراه</h2>
<p>مجموعهٔ کاملی از خدمات تشخیصی و درمانی، از ارزیابی اولیه تا مداخلات پیشرفتهٔ عروقی، در این مرکز ارائه می‌شود.</p>
<p>
<strong>✓ ویزیت و ارزیابی تخصصی</strong>
</p>
<p>بررسی دقیق سابقه، معاینهٔ بالینی و تعیین مسیر درمانی.</p>
<p>
<strong>✓ سونوگرافی داپلر عروق</strong>
</p>
<p>تصویربرداری دقیق از جریان خون و تشخیص نارسایی دریچه‌ها.</p>
<p>
<strong>✓ بررسی بیماری‌های شریانی محیطی</strong>
</p>
<p>تشخیص تنگی و انسداد عروق اندام‌ها با روش‌های غیرتهاجمی.</p>
<p>
<strong>✓ اسکلروتراپی</strong>
</p>
<p>درمان رگ‌های عنکبوتی و واریس‌های کوچک با تزریق داروی مخصوص.</p>
<p>
<strong>✓ لیزر داخل وریدی (EVLA)</strong>
</p>
<p>درمان وریدهای محوری و نارسایی‌های وریدی با تکنیک کم‌تهاجمی.</p>
<p>
<strong>✓ VeinGogh (RF Surface)</strong>
</p>
<p>درمان تلانژکتازی‌ها و رگ‌های ظریف با انرژی رادیوفرکوئنسی سطحی.</p>
<p>
<strong>✓ میکروفلبکتومی سرپایی</strong>
</p>
<p>خارج کردن رگ‌های واریسی برجسته از طریق سوراخ‌های بسیار ریز.</p>
<p>
<strong>✓ تعبیه Port-a-Cath</strong>
</p>
<p>برای بیماران انکولوژی نیازمند شیمی‌درمانی طولانی‌مدت.</p>
<p>
<strong>✓ درمان زخم‌های وریدی و دیابتی</strong>
</p>
<p>ارزیابی چندتخصصی و بازتوانی عروقی برای زخم‌های مزمن.</p>
<h2>مقایسهٔ روش‌های درمان واریس در کلینیک</h2>
<table>
<thead>
<tr>
<th>روش درمان</th>
<th>کاربرد</th>
<th>تهاجم</th>
<th>بازگشت به فعالیت</th>
</tr>
</thead>
<tbody>
<tr>
<td>
<strong>اسکلروتراپی</strong>
</td>
<td>رگ‌های عنکبوتی و واریس کوچک</td>
<td>بسیار کم</td>
<td>همان روز</td>
</tr>
<tr>
<td>
<strong>لیزر EVLA</strong>
</td>
<td>نارسایی وریدهای ساپنوس و محوری</td>
<td>کم‌تهاجمی</td>
<td>۱ تا ۲ روز</td>
</tr>
<tr>
<td>
<strong>VeinGogh (RF)</strong>
</td>
<td>تلانژکتازی‌های ظریف</td>
<td>بسیار کم</td>
<td>بلافاصله</td>
</tr>
<tr>
<td>
<strong>میکروفلبکتومی</strong>
</td>
<td>رگ‌های واریسی برجسته</td>
<td>کم‌تهاجمی</td>
<td>۲ تا ۳ روز</td>
</tr>
<tr>
<td>
<strong>آنژیوپلاستی و استنت</strong>
</td>
<td>تنگی و انسداد شریانی</td>
<td>اندوواسکولار</td>
<td>بسته به شرایط</td>
</tr>
</tbody>
</table>
<h2>مسیر مراجعه به کلینیک واریس همراه</h2>
<p>۱</p>
<h3>تماس و دریافت نوبت</h3>
<p>هماهنگی اولیه برای ویزیت توسط کادر پذیرش و انتخاب زمان مناسب.</p>
<p>۲</p>
<h3>ویزیت و معاینهٔ تخصصی</h3>
<p>بررسی سابقه، معاینهٔ بالینی و تعیین نیاز به تصویربرداری تکمیلی.</p>
<p>۳</p>
<h3>سونوگرافی داپلر عروق</h3>
<p>نقشه‌برداری دقیق از وریدها و شریان‌ها برای انتخاب بهترین روش درمان.</p>
<p>۴</p>
<h3>طراحی برنامهٔ درمانی</h3>
<p>تعیین روش مناسب (اسکلروتراپی، لیزر، میکروفلبکتومی یا ترکیبی).</p>
<p>۵</p>
<h3>انجام درمان و پیگیری</h3>
<p>اجرای درمان سرپایی و پیگیری دوره‌ای تا حصول نتیجهٔ پایدار.</p>
<h2>چرا کلینیک فوق تخصصی همراه؟</h2>
<p>👨‍⚕️</p>
<h3>پزشکان شناخته‌شده</h3>
<p>همکاری با فوق‌تخصص‌های باتجربه و صاحب‌نام در حوزهٔ بیماری‌های عروقی.</p>
<p>🔬</p>
<h3>تجهیزات پیشرفته</h3>
<p>دستگاه‌های سونوگرافی داپلر، لیزر EVLA و VeinGofday نسل جدید.</p>
<p>🎯</p>
<h3>رویکرد بیمارمحور</h3>
<p>تصمیم‌گیری درمانی بر اساس شرایط اختصاصی هر بیمار، نه پروتکل‌های یکسان.</p>
<p>📍</p>
<h3>دسترسی آسان</h3>
<p>واقع در قلب تجریش با دسترسی راحت از نقاط مختلف تهران.</p>
<p>🛡️</p>
<h3>استانداردهای علمی و اخلاقی</h3>
<p>رعایت کامل اصول حرفه‌ای، شفافیت در هزینه‌ها و احترام به حقوق بیمار.</p>
<p>⏱️</p>
<h3>درمان سرپایی</h3>
<p>اکثر مداخلات بدون نیاز به بستری و با بازگشت سریع به زندگی روزمره.</p>
<h2>چه بیمارانی می‌توانند به کلینیک ورید و جراحی عروق ارجاع داده شوند؟</h2>
<p>همکاران محترم پزشک می‌توانند بیماران زیر را جهت ارزیابی و درمان تخصصی معرفی کنند:</p>
<p>🔹 واریس علامت‌دار و مزمن اندام تحتانی</p>
<p>🔹 تلانژکتازی‌ها و مشکلات زیبایی عروقی</p>
<p>🔹 ادم مزمن، لنف‌ادم و فلبولنف‌ادم</p>
<p>🔹 زخم‌های وریدی مقاوم به درمان</p>
<p>🔹 زخم پای دیابتی</p>
<p>🔹 ایسکمی اندام و بیماری شریانی محیطی</p>
<p>🔹 ترومبوز وریدی و عوارض پس از DVT</p>
<p>🔹 بیماران انکولوژی نیازمند Port-a-Cath</p>
<p>🔹 ارزیابی عروقی پیش از اعمال جراحی</p>
<h2>هشدار: چه زمانی باید سریعاً به کلینیک واریس مراجعه کنید؟</h2>
<ul>
<li>تورم ناگهانی و یک‌طرفهٔ پا همراه با درد شدید (احتمال DVT)</li>
<li>قرمزی، گرمی و سفتی روی مسیر یک ورید (فلبیت سطحی)</li>
<li>خونریزی از رگ‌های واریسی که با فشار بند نمی‌آید</li>
<li>زخم باز روی مچ پا که رو به گسترش است</li>
<li>تغییر ناگهانی رنگ پا به رنگ پریده یا آبی همراه با سردی (ایسکمی حاد)</li>
</ul>
<h2>نگاهی به اهمیت بیماری‌های وریدی</h2>
<p>۳۰٪</p>
<p>از بزرگسالان دچار واریس هستند</p>
<p>۲×</p>
<p>شیوع بیشتر در زنان نسبت به مردان</p>
<p>۷۲h</p>
<p>زمان طلایی درمان DVT</p>
<p>۹۵٪</p>
<p>موفقیت درمان‌های کم‌تهاجمی</p>
<h2>راهکارهای پیشگیری و مراقبت در منزل</h2>
<p>علاوه بر درمان تخصصی در کلینیک، رعایت این نکات ساده می‌تواند پیشرفت بیماری را کند و کیفیت زندگی را بهبود بخشد:</p>
<p>
<strong>۱. تحرک منظم</strong>
</p>
<p>پیاده‌روی روزانه، پمپ عضلانی ساق را فعال و بازگشت وریدی را تقویت می‌کند.</p>
<p>
<strong>۲. پرهیز از ایستادن طولانی</strong>
</p>
<p>در مشاغل ایستاده، هر ۳۰ دقیقه چند قدم راه بروید یا پنجهٔ پا را حرکت دهید.</p>
<p>
<strong>۳. استفاده از جوراب واریس</strong>
</p>
<p>جوراب فشاردرمانی با تجویز پزشک، از تجمع خون در پاها جلوگیری می‌کند.</p>
<p>
<strong>۴. بالا نگه‌داشتن پاها</strong>
</p>
<p>در زمان استراحت، پاها را ۱۵ تا ۲۰ دقیقه بالاتر از سطح قلب قرار دهید.</p>
<p>
<strong>۵. کنترل وزن</strong>
</p>
<p>کاهش وزن اضافی، فشار روی وریدهای اندام تحتانی را به‌طور معناداری کم می‌کند.</p>
<p>
<strong>۶. مصرف آب و فیبر</strong>
</p>
<p>پیشگیری از یبوست، فشار داخل شکمی و در نتیجه فشار روی وریدها را کاهش می‌دهد.</p>
<h2>پرسش‌های متداول دربارهٔ کلینیک واریس</h2>
<p>آیا درمان واریس دردناک است؟<br></p>
<p>+</p>
<p>اکثر روش‌های نوین مانند اسکلروتراپی، لیزر EVLA و VeinGofday با بی‌حسی موضعی انجام می‌شوند و بیمار در حین و پس از عمل درد قابل‌توجهی تجربه نمی‌کند. ناراحتی خفیف در روزهای اول طبیعی است و با مسکن‌های ساده کنترل می‌شود.</p>
<p>آیا پس از درمان نیاز به بستری هست؟<br></p>
<p>+</p>
<p>خیر. بیشتر مداخلات در کلینیک واریس همراه به‌صورت سرپایی انجام می‌شود و بیمار همان روز به منزل بازمی‌گردد. فعالیت سبک روز بعد از درمان معمولاً امکان‌پذیر است.</p>
<p>سونوگرافی داپلر چه کمکی می‌کند؟<br></p>
<p>+</p>
<p>این تصویربرداری بدون اشعه و درد، نقشهٔ دقیقی از وریدها، وضعیت دریچه‌ها و جهت جریان خون ارائه می‌دهد و پایهٔ انتخاب بهترین روش درمان است.</p>
<p>تفاوت واریس و تلانژکتازی چیست؟<br></p>
<p>+</p>
<p>تلانژکتازی‌ها رگ‌های بسیار ظریف و سطحی با قطر کمتر از ۱ میلی‌متر هستند که بیشتر جنبهٔ زیبایی دارند. واریس‌ها رگ‌های برجسته، پیچ‌خورده و با قطر بیشتر از ۳ میلی‌مترند که می‌توانند علائم بالینی ایجاد کنند.</p>
<p>آیا واریس دوباره برمی‌گردد؟<br></p>
<p>+</p>
<p>رگ‌های درمان‌شده معمولاً برنمی‌گردند، اما زمینهٔ ژنتیکی و سبک زندگی می‌تواند باعث ایجاد رگ‌های جدید شود. رعایت توصیه‌های پیشگیری و پیگیری دوره‌ای، این احتمال را به حداقل می‌رساند.</p>
<p>Port-a-Cath چیست و چه کاربردی دارد؟<br></p>
<p>+</p>
<p>پورت وریدی کاشتنی، دسترسی طولانی‌مدت و ایمن به جریان خون را برای بیماران انکولوژی فراهم می‌کند تا شیمی‌درمانی، نمونه‌گیری و تزریقات مکرر با راحتی بیشتری انجام شود.</p>
<h2>جمع‌بندی</h2>
<p>واریس و بیماری‌های عروقی، اگر به‌موقع تشخیص داده شوند، با روش‌های نوین و کم‌تهاجمی قابل درمان هستند. کلینیک فوق تخصصی همراه با تکیه بر دانش روز، تجهیزات پیشرفته و تیمی از پزشکان باتجربه، مسیری امن، دقیق و بیمارمحور را برای بازگرداندن سلامتی به پاها فراهم می‌کند. از ارزیابی اولیه با سونوگرافی داپلر تا درمان‌های تخصصی مانند اسکلروتراپی، لیزر EVLA، VeinGofday و میکروفلبکتومی، همه در یک مرکز و با هماهنگی کامل انجام می‌شود.</p>
<p>درمان واریس تنها یک اقدام زیبایی نیست؛ سرمایه‌گذاری روی کیفیت زندگی، پیشگیری از عوارض جدی و بازگشت به فعالیت روزمره بدون درد است. اگر علائمی مانند سنگینی، تورم، گرفتگی شبانه یا رگ‌های برجسته دارید، زمان مناسب برای اقدام، همین امروز است.</p>
<p>📞</p>
<h2>همین امروز مسیر درمان را آغاز کنید</h2>
<p>برای دریافت نوبت ویزیت، مشاورهٔ اولیه و انجام سونوگرافی داپلر در کلینیک فوق تخصصی همراه، با ما تماس بگیرید.</p>
<p>🩺 مرکز تخصصی درمان واریس و ارزیابی عروق محیطی</p>
<p>تشخیص دقیق • درمان مؤثر • همراهی ماندگار</p>' WHERE path = '/service/کلینیک-واریس/';

UPDATE pages SET body = '<h2>دپارتمان فوق تخصصی قلب کودکان همراه کلینیک</h2>
<p>دپارتمان قلب کودکان همراه کلینیک، با بهره‌گیری از فلوشیپ‌های فوق تخصصی قلب کودکان و پیشرفته‌ترین تجهیزات تصویربرداری، آماده ارائه خدمات جامع از دوران جنینی تا نوجوانی است. رویکرد ما در این بخش، تشخیص زودهنگام، مدیریت دقیق درمان و حمایت همه‌جانبه از کودک و خانواده در فضایی آرام و اطمینان‌بخش است.</p>
<h2>ساختار و رویکرد مراقبتی در بخش قلب کودکان</h2>
<p>این دپارتمان فراتر از یک معاینه روتین عمل می‌کند. ما با ایجاد هماهنگی کامل بین متخصصان قلب کودکان، متخصصان اطفال، نوزادان، جراحان قلب و مشاوران تغذیه، زنجیره‌ای پیوسته از مراقبت را فراهم می‌آوریم. بسیاری از ناهنجاری‌های قلبی کودکان نیازمند پیگیری طولانی‌مدت و توجه همزمان به رشد و تکامل کودک هستند.</p>
<p>تمرکز اصلی ما بر تشخیص دقیق با کمترین استرس برای کودک است. فضای معاینه با رنگ‌بندی و طراحی کودک‌پسند آماده شده تا اضطراب ناشی از محیط پزشکی کاهش یابد و کودک بتواند با آرامش بیشتری فرآیند ارزیابی را طی کند. این رویکرد همدلانه، به ویژه برای نوزادان و کودکان خردسال، کیفیت ارزیابی بالینی را به شکل چشمگیری افزایش می‌دهد.</p>
<h2>طیف خدمات تخصصی ارائه‌شده</h2>
<p>خدمات این بخش در سه محور اصلی طراحی شده است:</p>
<ul>
<li>
<strong>خدمات تشخیصی پیشرفته:</strong> اکوکاردیوگرافی جنینی (Fetal Echo)، اکوکاردیوگرافی تخصصی کودکان، نوار قلب (ECG)، هولتر ریتم و فشار خون ۲۴ ساعته، و تست ورزش (برای سنین بالاتر).</li>
<li>
<strong>خدمات درمانی و مدیریتی:</strong> مدیریت دارویی نارسایی قلب، آریتمی‌های کودکان، بیماری کاوازاکی، تب روماتیسمی و مراقبت‌های جامع قبل و بعد از عمل‌های جراحی قلب.</li>
<li>
<strong>خدمات پیشگیرانه و مشاوره‌ای:</strong> غربالگری نوزادان پرخطر، مشاوره تغذیه برای رشد بهینه، و راهنمایی والدین درباره سطح فعالیت‌های فیزیکی ایمن برای کودک.</li>
</ul>
<h2>ویژگی‌های کلیدی دپارتمان قلب کودکان ما</h2>
<p>🧸</p>
<h3>محیط کودک‌پسند</h3>
<p>طراحی فضای معاینه برای کاهش ترس و ایجاد حس امنیت در کودکان</p>
<p>📡</p>
<h3>تجهیزات پیشرفته</h3>
<p>دستگاه‌های اکوکاردیوگرافی با دقت بالا برای تشخیص جزئی‌ترین ناهنجاری‌ها</p>
<p>🤝</p>
<h3>شبکه ارجاع مطمئن</h3>
<p>هماهنگی سریع و مستقیم با برترین مراکز جراحی قلب کودکان در صورت نیاز</p>
<p>👨‍👩‍👧</p>
<h3>آموزش به خانواده</h3>
<p>توانمندسازی والدین با دانش لازم برای مراقبت‌های روزمره و علائم هشدار</p>
<h3>توصیه تخصصی</h3>
<p>بهترین زمان برای بررسی بسیاری از ناهنجاری‌های قلبی، دوران بارداری (با اکوی جنینی) یا اولین روزهای تولد است. غربالگری به‌موقع در نوزادان پرخطر، مسیر درمان را هموارتر کرده و از عوارض بعدی جلوگیری می‌کند.</p>
<h3>نکته مهم برای والدین</h3>
<p>علائمی مانند کبودی لب‌ها و ناخن‌ها (سیانوز) به ویژه هنگام گریه یا شیر خوردن، تعریق غیرعادی و زیاد روی پیشانی کودک هنگام تغذیه، یا تنفس سریع و دشوار، هرگز نباید به حساب &#8220;ضعف معمولی&#8221; گذاشته شده و نادیده گرفته شوند.</p>
<h2>چک‌لیست انتخاب کلینیک قلب کودکان مناسب</h2>
<p>✓<br></p>
<p>معاینه توسط پزشک دارای فلوشیپ فوق تخصصی قلب کودکان (نه فقط متخصص اطفال یا قلب بزرگسالان)</p>
<p>✓<br></p>
<p>دسترسی درون‌کلینیکی به دستگاه اکوکاردیوگرافی پیشرفته</p>
<p>✓<br></p>
<p>وجود پرونده رشد و تکامل یکپارچه برای پایش همزمان سلامت قلب و رشد کودک</p>
<p>✓<br></p>
<p>برنامه‌ریزی منظم برای ویزیت‌های پیگیری و ارزیابی مجدد داروها</p>
<h2>اشتباهات رایج والدین در مراقبت قلبی کودکان</h2>
<h3>اشتباهات در شروع و تشخیص</h3>
<ul>
<li>نادیده گرفتن سوفل‌های قلبی بدون انجام اکوکاردیوگرافی تکمیلی.</li>
<li>مقایسه وضعیت رشد یا علائم کودک با خواهر/برادر یا کودکان فامیل.</li>
<li>تاخیر در مراجعه به بهانه &#8220;بزرگ شدن کودک و رفع خودبه‌خودی مشکل&#8221;.</li>
</ul>
<h3>اشتباهات در ادامه مراقبت</h3>
<ul>
<li>قطع خودسرانه داروها به بهانه &#8220;خوب شدن ظاهر کودک&#8221; یا ترس از عوارض دارو.</li>
<li>محدود کردن بی‌دلیل و شدید فعالیت‌های فیزیکی کودک بدون مشورت مستقیم پزشک.</li>
<li>عدم توجه جدی به بهداشت دهان و دندان (که در پیشگیری از اندوکاردیت عفونی در کودکان مبتلا به بیماری قلبی حیاتی است).</li>
</ul>
<h3>هشدار ایمنی فوری</h3>
<p>در صورت مشاهده کبودی ناگهانی و شدید (به ویژه در زبان و لب‌ها)، غش کردن (سنکوپ)، یا تنگی نفس حاد و ناتوانی در شیر خوردن، فوراً با اورژانس پزشکی (۱۱۵) تماس بگیرید. این شرایط نیازمند مداخله فوری بیمارستانی هستند و نباید منتظر نوبت کلینیک بمانید.</p>
<blockquote>
<p>«قلب کوچک کودکان، موتور تپنده آینده آن‌هاست. مراقبت دقیق، به‌موقع و تخصصی از این موتور، ضامن یک عمر زندگی سالم، پویا و بدون محدودیت خواهد بود.»</p>
</blockquote>
<h2>جمع‌بندی نهایی</h2>
<p>دپارتمان قلب کودکان همراه کلینیک، با ترکیب دانش روز پزشکی، تجهیزات تشخیصی پیشرفته و محیطی همدلانه و کودک‌محور، در کنار شماست تا سلامت قلب فرزندتان تضمین شود. ما معتقدیم که تشخیص به‌موقع و مدیریت صحیح، می‌تواند مسیر زندگی کودک را به طور کامل تغییر دهد و او را به سمت یک بزرگسالی سالم هدایت کند.</p>
<p>به‌یاد داشته باشید که مراجعه به متخصص قلب کودکان برای بررسی علائم مشکوک، نشانه وسواس نیست، بلکه نشان‌دهنده مسئولیت‌پذیری و هوشمندی شما در قبال سلامت آینده فرزندتان است.</p>
<h3>همین امروز برای اطمینان از سلامت قلب فرزندتان اقدام کنید</h3>
<p>
<a>📞 ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/کلینیک-قلب-کودکان/';

UPDATE pages SET body = '<h2>اکوکاردیوگرافی قلب جنین (Fetal Echocardiography)</h2>
<p>اکوکاردیوگرافی قلب جنین، یک روش تصویربرداری تخصصی، غیرتهاجمی و کاملاً ایمن است که با استفاده از امواج صوتی، ساختار، عملکرد و ریتم قلب جنین را در دوران بارداری بررسی می‌کند. این خدمت در همراه کلینیک با پیشرفته‌ترین تجهیزات و توسط متخصصین مجرب انجام می‌شود تا با تشخیص زودهنگام ناهنجاری‌های قلبی، زمینه‌ساز مراقبت‌های به‌موقع و برنامه‌ریزی درمانی مناسب پس از تولد باشد.</p>
<h2>اکوکاردیوگرافی جنینی چیست و چرا اهمیت دارد؟</h2>
<p>اکوکاردیوگرافی قلب جنین نوعی سونوگرافی تخصصی است که به‌طور خاص بر ارزیابی قلب در حال رشد جنین تمرکز دارد. این روش به پزشکان اجازه می‌دهد تا موقعیت، اندازه، ساختار آناتومیک، عملکرد دریچه‌ها، جریان خون و ریتم قلب جنین را با دقت بالا بررسی کنند.</p>
<p>اهمیت این خدمت در این است که بسیاری از ناهنجاری‌های مادرزادی قلب را می‌توان قبل از تولد تشخیص داد. این تشخیص زودهنگام به تیم پزشکی امکان می‌دهد تا برنامه‌ریزی دقیقی برای مراقبت‌های دوران بارداری، زمان و مکان زایمان، و اقدامات درمانی فوری پس از تولد انجام دهند.</p>
<h2>بهترین زمان انجام اکوکاردیوگرافی جنین</h2>
<p>بهترین زمان برای انجام اکوکاردیوگرافی قلب جنین، سه‌ماهه دوم بارداری و به‌طور خاص بین هفته‌های ۱۸ تا ۲۴ بارداری است. در این بازه زمانی، قلب جنین به اندازه کافی رشد کرده و ساختارهای آناتومیک آن به‌وضوح قابل مشاهده هستند.</p>
<p>با این حال، بسته به شرایط خاص و نظر پزشک معالج، این آزمایش می‌تواند از هفته ۱۴ بارداری تا انتهای دوران حاملگی نیز انجام شود. در مواردی که نیاز به تصمیم‌گیری‌های مهم پزشکی وجود دارد، انجام آزمایش قبل از هفته ۲۲ توصیه می‌شود.</p>
<h3>زمان‌بندی طلایی</h3>
<p>هفته ۱۸ تا ۲۲ بارداری، دوره طلایی برای اکوکاردیوگرافی جنین است. در این زمان، آناتومی قلب به‌طور کامل شکل گرفته و هنوز فضای کافی برای تصویربرداری واضح وجود دارد.</p>
<h2>چه کسانی باید اکوکاردیوگرافی جنین انجام دهند؟</h2>
<p>اگرچه این آزمایش برای تمام زنان باردار مفید است، اما برای گروه‌های زیر انجام آن <strong>ضروری</strong> توصیه می‌شود:</p>
<h3>عوامل مربوط به سابقه خانوادگی</h3>
<ul>
<li>سابقه بیماری‌های مادرزادی قلبی در والدین، خواهر و برادرها یا فرزندان قبلی.</li>
<li>وجود سندرم‌های ژنتیکی در خانواده (مانند سندرم داون)</li>
<li>سابقه مرگ ناگهانی قلبی در خویشاوندان درجه یک</li>
</ul>
<h3>عوامل مربوط به سلامت مادر</h3>
<ul>
<li>دیابت نوع ۱ یا ۲ (به‌ویژه اگر کنترل‌نشده باشد)</li>
<li>بیماری‌های خودایمنی (لوپوس، سندرم آنتی‌فسفولیپید)</li>
<li>فنیل‌کتونوری (PKU)</li>
<li>مصرف داروهای خاص در بارداری (داروهای ضدتشنج، لیتیوم، رتینوئیدها)</li>
<li>عفونت‌های دوران بارداری (سرخجه، CMV، توکسوپلاسموز)</li>
</ul>
<h3>یافته‌های غیرطبیعی در سونوگرافی‌های روتین</h3>
<ul>
<li>مشکوک بودن به ناهنجاری قلبی در سونوگرافی آنومالی</li>
<li>آریتمی جنینی (ضربان نامنظم قلب)</li>
<li>افزایش یا کاهش مایع آمنیوتیک</li>
<li>هیدروپس جنینی (تجمع مایع در بافت‌های جنین)</li>
<li>وجود ناهنجاری‌های دیگر در اندام‌های جنین</li>
</ul>
<h3>سایر موارد</h3>
<ul>
<li>بارداری‌های چندقلو (به‌ویژه دوقلوهای هم‌جفت)</li>
<li>بارداری با روش‌های کمک‌باروری (IVF/ICSI)</li>
<li>سن مادر بالای ۳۵ سال</li>
</ul>
<h2>تفاوت اکوکاردیوگرافی جنین با سونوگرافی معمولی</h2>
<h3>سونوگرافی آنومالی معمولی</h3>
<ul>
<li>بررسی کلی تمام اندام‌ها</li>
<li>نگاه کلی به چهار حفره قلب</li>
<li>زمان: ۳۰-۴۵ دقیقه</li>
<li>توسط متخصص رادیولوژی یا سونوگرافیست</li>
<li>غربالگری عمومی</li>
</ul>
<h3>اکوکاردیوگرافی تخصصی</h3>
<ul>
<li>تمرکز انحصاری بر قلب و عروق بزرگ</li>
<li>بررسی دقیق تمام ساختارهای قلبی</li>
<li>زمان: ۴۵-۹۰ دقیقه</li>
<li>توسط فلوشیپ قلب کودکان یا رادیولوژیست متخصص</li>
<li>تشخیص تخصصی و دقیق</li>
</ul>
<h2>روش انجام اکوکاردیوگرافی جنین</h2>
<p>این آزمایش یک روش <strong>کاملاً غیرتهاجمی، بدون درد و بدون اشعه</strong> است که از فناوری اولتراسوند (امواج صوتی) استفاده می‌کند، فرآیند انجام آن به شرح زیر است:</p>
<p>۱</p>
<h4>آمادگی قبل از آزمایش</h4>
<p>نیاز به آمادگی خاصی نیست. بهتر است ۳۰ دقیقه تا ۲ ساعت زمان در نظر بگیرید.</p>
<p>۲</p>
<h4>وضعیت قرارگیری</h4>
<p>مادر به پشت دراز می‌کشد و شکم در معرض دید قرار می‌گیرد.</p>
<p>۳</p>
<h4>استفاده از ژل و پروب</h4>
<p>ژل مخصوص روی شکم مالیده شده و پروب اولتراسوند حرکت داده می‌شود.</p>
<p>۴</p>
<h4>تصویربرداری تخصصی</h4>
<p>تصاویر دقیق از تمام بخش‌های قلب ثبت و تحلیل می‌شود.</p>
<p>در موارد خاص (مانند چاقی مادر یا وضعیت نامناسب جنین)، ممکن است از روش <strong>واژینال</strong> نیز استفاده شود که در هفته‌های نخستین بارداری دقت بالاتری دارد.</p>
<h2>مزایای اکوکاردیوگرافی جنین در همراه کلینیک</h2>
<p>🛡️</p>
<h3>کاملاً ایمن</h3>
<p>بدون اشعه و بدون خطر برای مادر و جنین</p>
<p>🎯</p>
<h3>تشخیص زودهنگام</h3>
<p>شناسایی ناهنجاری‌ها قبل از تولد برای برنامه‌ریزی بهتر</p>
<p>👨‍⚕️</p>
<h3>تیم متخصص</h3>
<p>انجام توسط فلوشیپ‌های فوق تخصصی قلب کودکان</p>
<p>📊</p>
<h3>تجهیزات پیشرفته</h3>
<p>دستگاه‌های اکوکاردیوگرافی با رزولوشن بالا</p>
<h3>توصیه تخصصی</h3>
<p>حتی اگر در گروه پرخطر قرار ندارید، در صورت داشتن هرگونه نگرانی درباره سلامت قلب جنین یا مشاهده علائم غیرعادی در سونوگرافی‌های روتین، با پزشک خود درباره انجام اکوکاردیوگرافی مشورت کنید. تشخیص زودهنگام می‌تواند تفاوت بزرگی در نتیجه درمان ایجاد کند.</p>
<h3>نکته مهم</h3>
<p>اکوکاردیوگرافی جنین یک روش <strong>غربالگری و تشخیصی</strong> است، نه درمانی. در صورت تشخیص ناهنجاری، این به معنای پایان راه نیست. بسیاری از ناهنجاری‌های قلبی با درمان مناسب پس از تولد، قابل اصلاح هستند و کودک می‌تواند زندگی طبیعی داشته باشد.</p>
<h2>جمع‌بندی نهایی</h2>
<p>اکوکاردیوگرافی قلب جنین، پنجره‌ای به سوی اطمینان از سلامت قلب کوچک‌ترین عضو خانواده شماست. این روش ایمن و دقیق، به شما و تیم پزشکی‌تان این امکان را می‌دهد که با آگاهی کامل، بهترین مراقبت‌ها را برای جنین برنامه‌ریزی کنید.</p>
<p>در همراه کلینیک ما با بهره‌گیری از پیشرفته‌ترین تجهیزات تصویربرداری و تیم متخصصین مجرب، متعهد هستیم که با دقت و همدلی، سلامت قلب جنین شما را ارزیابی کنیم. به‌یاد داشته باشید که تشخیص به‌موقع، کلید مدیریت موفق هرگونه ناهنجاری قلبی است.</p>
<h3>برای اطمینان از سلامت قلب جنین، همین حالا اقدام کنید و با <a href="/service/کلینیک-قلب-کودکان/">کلینیک قلب کودکان</a> تماس حاصل فرمایید</h3>
<p>
<a>📞 ۰۲۱۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';

UPDATE pages SET body = '<p>● کلینیک تخصصی همراه</p>
<h2>خدمات پزشکی و درمانی ما برای شما</h2>
<p>با بهره‌گیری از تیم متخصص و تجهیزات پیشرفته، همه خدمات درمانی مورد نیاز شما در یک مجموعه</p>
<table>
<tbody>
<tr>
<td>
۷
دپارتمان تخصصی
</td>
<td>
+۲۵
خدمت تخصصی
</td>
<td>
۲۴
ساعت پذیرش
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
🎗️
</td>
<td>
دپارتمان آنکولوژی
تشخیص و درمان انواع سرطان
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
<a href="/service/آنکولوژی/">آنکولوژی</a>
<br>
◄
<p>تشخیص، درمان و پیگیری انواع سرطان توسط متخصص آنکولوژی</p>
<p>
</td>
<td>
<a href="/service/هماتولوژی/">هماتولوژی</a>
<br>
◄
<p>تخصص در بیماری‌های خون و اختلالات سیستم خون‌ساز</p>
<p>
</td>
<td>
<a href="/service/شیمی-درمانی/">شیمی‌درمانی</a>
<br>
◄
<p>انجام دوره‌های شیمی‌درمانی تحت نظر تیم تخصصی آنکولوژی</p>
<p>
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
❤️
</td>
<td>
دپارتمان قلب و عروق
تشخیص و درمان بیماری‌های قلبی-عروقی
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
<a href="/service/قلب-و-عروق/">قلب و عروق</a>
<br>
◄
<p>ویزیت متخصص قلب، نوار قلب، اکو و مانیتورینگ عروقی</p>
<p>
</td>
<td>
<a href="/service/کلینیک-واریس/">کلینیک واریس</a>
<br>
◄
<p>درمان تخصصی واریس با جدیدترین متدهای غیرجراحی و لیزر</p>
<p>
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
🧠
</td>
<td>
دپارتمان اعصاب و روان
روان‌پزشکی و روان‌شناسی بالینی
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
<a href="/service/روان-پزشکی/">روان‌پزشکی</a>
<br>
◄
<p>تشخیص و درمان دارویی اختلالات روانپزشکی توسط متخصص</p>
<p>
</td>
<td>
<a href="/service/روان-شناسی/">روان‌شناسی</a>
<br>
◄
<p>مشاوره، روان‌درمانی فردی، زوج‌درمانی و خانواده‌درمانی</p>
<p>
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
🥗
</td>
<td>
دپارتمان تغذیه
برنامه‌ریزی تغذیه و رژیم درمانی تخصصی
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
<a href="/service/تغذیه/">تغذیه</a>
<br>
◄
<p>مشاوره تغذیه و برنامه غذایی شخصی‌سازی‌شده</p>
<p>
</td>
<td>
رژیم درمانی<br>
◄
<p>رژیم تخصصی برای کاهش وزن، دیابت، کلیه و بیماری‌های متابولیک</p>
<p>
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
🌿
</td>
<td>
دپارتمان طب ایرانی
طب سنتی و سبک زندگی سالم
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
<a href="/service/طب-ایرانی/">طب ایرانی (سبک زندگی)</a>
<br>
◄
<p>مشاوره طب سنتی ایرانی، اصلاح سبک زندگی و درمان‌های طبیعی</p>
<p>
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
🩹
</td>
<td>
کلینیک زخم
درمان تخصصی انواع زخم‌های حاد و مزمن
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
<a href="/service/diabetic-foot/">زخم پای دیابتی</a>◄
<p>درمان تخصصی زخم‌های ناشی از دیابت</p>
<p>
</td>
<td>
<a href="/service/pressure-ulcer/">زخم بستر (فشاری)</a>◄
<p>درمان و پیشگیری از زخم‌های فشاری در بیماران بستری</p>
<p>
</td>
<td>
<a href="/service/surgical-wound/">زخم بعد از جراحی</a>◄
<p>مراقبت و درمان زخم‌های پس از عمل‌های جراحی</p>
<p>
</td>
</tr>
<tr>
<td>
<a href="/service/burn-wound/">زخم سوختگی</a>◄
<p>درمان سوختگی‌های سطحی و عمیق با روش‌های نوین</p>
<p>
</td>
<td>
<a href="/service/infected-wound/">زخم عفونی</a>◄
<p>کنترل عفونت و درمان زخم‌های آلوده به میکروارگانیسم</p>
<p>
</td>
<td>
<a href="/service/venous-ulcer/">زخم وریدی</a>◄
<p>درمان زخم‌های ناشی از نارسایی وریدی پا</p>
<p>
</td>
</tr>
<tr>
<td>
<a href="/service/arterial-ulcer/">زخم شریانی</a>◄
<p>درمان زخم‌های ایسکمیک ناشی از بیماری‌های شریانی</p>
<p>
</td>
<td>
<a href="/service/chronic-wound/">زخم مزمن غیرملتئم</a>◄
<p>مدیریت زخم‌هایی که به روش‌های معمول پاسخ نمی‌دهند</p>
<p>
</td>
<td>
<a href="/service/traumatic-wound/">زخم ضربه‌ای (تروماتیک)</a>◄
<p>درمان زخم‌های ناشی از تروما و آسیب‌های فیزیکی</p>
<p>
</td>
</tr>
<tr>
<td>
<a href="/service/malignant-wound/">زخم سرطانی</a>◄
<p>مراقبت از زخم‌های ناشی از سرطان یا درمان‌های آن</p>
<p>
</td>
<td>
همه خدمات کلینیک زخم ←◄
<p>مشاهده کامل خدمات کلینیک زخم</p>
<p>
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
🦠
</td>
<td>
کلینیک عفونی
تشخیص و درمان بیماری‌های عفونی
</td>
</tr>
</tbody>
</table>
<table>
<tbody>
<tr>
<td>
<a href="/service/viral-hepatitis/">هپاتیت ویروسی (B و C)</a>◄
<p>درمان انواع هپاتیت ویروسی با پروتکل‌های به‌روز</p>
<p>
</td>
<td>
<a href="/service/sti/">عفونت‌های مقاربتی (STI)</a>◄
<p>تشخیص محرمانه و درمان تخصصی بیماری‌های مقاربتی</p>
<p>
</td>
<td>
<a href="/service/tuberculosis/">سل (TB)</a>◄
<p>تشخیص زودهنگام و درمان بیماری سل ریوی و خارج ریوی</p>
<p>
</td>
</tr>
<tr>
<td>
<a href="/service/gi-infection/">عفونت‌های گوارشی</a>◄
<p>درمان عفونت‌های دستگاه گوارش، هلیکوباکتر و سایر موارد</p>
<p>
</td>
<td>
<a href="/service/brucellosis/">تب مالت (بروسلوز)</a>◄
<p>تشخیص و درمان تخصصی بروسلوز و عوارض مزمن آن</p>
<p>
</td>
<td>
<a href="/service/respiratory-infection/">عفونت تنفسی</a>◄
<p>درمان پنومونی، برونشیت و سایر عفونت‌های دستگاه تنفسی</p>
<p>
</td>
</tr>
<tr>
<td>
<a href="/service/fungal-infection/">عفونت‌های قارچی</a>◄
<p>تشخیص و درمان انواع عفونت‌های قارچی سطحی و سیستمیک</p>
<p>
</td>
<td>
<a href="/service/skin-infection/">عفونت پوست و بافت نرم</a>◄
<p>درمان سلولیت، آبسه و عفونت‌های بافت نرم</p>
<p>
</td>
<td>
<a href="/service/urinary-tract-infection/">عفونت ادراری (UTI)</a>◄
<p>تشخیص و درمان عفونت‌های دستگاه ادراری حاد و مکرر</p>
<p>
</td>
</tr>
<tr>
<td>
<a href="/service/fever-unknown-origin/">تب با علت نامشخص (FUO)</a>◄
<p>بررسی و ریشه‌یابی تب‌های طولانی‌مدت بدون علت مشخص</p>
<p>
</td>
<td>
همه خدمات کلینیک عفونی ←◄
<p>مشاهده کامل خدمات کلینیک عفونی</p>
<p>
</td>
</tr>
</tbody>
</table>
<h2>برای دریافت نوبت آماده‌اید؟</h2>
<p>همین الان با ما تماس بگیرید یا به صورت آنلاین نوبت رزرو کنید</p>
<p>
<a href="/contact-us/">📅 رزرو نوبت آنلاین</a>
</p>' WHERE path = '/service/لیست-خدمات-کلینیک-همراه/';

UPDATE pages SET body = '<h2>درمان اختلالات غده فوق کلیه (آدرنال)</h2>
<p>غدد فوق کلیه (آدرنال) دو غده‌ی کوچک روی کلیه‌ها هستند که هورمون‌های حیاتی مانند کورتیزول، آلدوسترون و آدرنالین تولید می‌کنند. اختلال در این غدد می‌تواند فشار خون، وزن، قند خون و حتی تعادل نمک بدن را بر هم بزند. <strong>کلینیک غدد همراه</strong> با آزمایش‌های هورمونی تخصصی و تست‌های تحریکی و سرکوبی، این اختلالات کمتر‌شناخته‌شده اما مهم را تشخیص و درمان می‌کند.</p>
<h2>هورمون‌های غده فوق کلیه</h2>
<ul>
<li>
<strong>کورتیزول:</strong> هورمون استرس و تنظیم متابولیسم</li>
<li>
<strong>آلدوسترون:</strong> تنظیم فشار خون و تعادل نمک و آب</li>
<li>
<strong>آدرنالین و نورآدرنالین:</strong> پاسخ به استرس</li>
<li>
<strong>آندروژن‌ها:</strong> هورمون‌های جنسی</li>
</ul>
<h2>انواع اختلالات آدرنال</h2>
<ul>
<li>
<strong>سندرم کوشینگ:</strong> کورتیزول بیش از حد — چاقی مرکزی، صورت گرد، ترک‌های پوستی، فشار خون و دیابت</li>
<li>
<strong>نارسایی آدرنال (بیماری آدیسون):</strong> کمبود کورتیزول — خستگی شدید، کاهش وزن، تیرگی پوست، افت فشار</li>
<li>
<strong>هیپرآلدوسترونیسم (سندرم کان):</strong> آلدوسترون زیاد — فشار خون مقاوم و کاهش پتاسیم</li>
<li>
<strong>فئوکروموسیتوما:</strong> تومور ترشح‌کننده‌ی آدرنالین — حملات فشار خون، تپش قلب و تعریق</li>
<li>
<strong>توده‌ی اتفاقی آدرنال:</strong> توده‌ای که در تصویربرداری کشف می‌شود و نیاز به ارزیابی دارد</li>
</ul>
<h2>تشخیص در کلینیک همراه</h2>
<ul>
<li>اندازه‌گیری کورتیزول خون، ادرار و بزاق</li>
<li>تست سرکوب با دگزامتازون</li>
<li>اندازه‌گیری ACTH</li>
<li>نسبت آلدوسترون به رنین</li>
<li>متانفرین‌های ادرار و خون (برای فئوکروموسیتوما)</li>
<li>تصویربرداری CT یا MRI غدد فوق کلیه</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>نارسایی آدرنال:</strong> جایگزینی هورمون کورتیزول (و در صورت نیاز آلدوسترون)</li>
<li>
<strong>سندرم کوشینگ:</strong> درمان علت (دارو، جراحی تومور — با ارجاع)</li>
<li>
<strong>هیپرآلدوسترونیسم:</strong> داروهای مسدودکننده‌ی آلدوسترون یا جراحی</li>
<li>
<strong>فئوکروموسیتوما:</strong> آماده‌سازی دارویی و ارجاع برای جراحی</li>
<li>
<strong>پایش بلندمدت:</strong> تنظیم دوز و کنترل عوارض</li>
</ul>
<h2>پزشکان بخش درمان اختلالات غده فوق کلیه (آدرنال) همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان اختلالات غده فوق کلیه (آدرنال) متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/adrenal/';

UPDATE pages SET body = '<h2>درمان زخم شریانی</h2>
<p>زخم شریانی (Arterial Ulcer) ناشی از کاهش جریان خون شریانی به اندام‌های انتهایی است و معمولاً در انگشتان پا، پاشنه و نواحی فشاری ظاهر می‌شود. این زخم‌ها بسیار دردناک و خطرناک هستند و نیاز به ارزیابی فوری عروقی دارند.</p>
<h2>زخم شریانی چیست؟</h2>
<p>زمانی که شریان‌های اندام تحتانی به دلیل آترواسکلروز، لخته یا فشار خارجی تنگ یا مسدود شوند، اکسیژن کافی به بافت نمی‌رسد و در نهایت بافت می‌میرد. این زخم‌ها معمولاً علامت بیماری شریان محیطی (PAD) هستند.</p>
<h2>علائم مشخصه</h2>
<ul>
<li>زخم‌های کوچک با لبه‌های مشخص (&#8220;Punched-out&#8221;)</li>
<li>محل: انگشتان پا، پاشنه، نقاط استخوانی</li>
<li>درد شدید — به‌خصوص شب‌ها و در حالت دراز کشیدن</li>
<li>کاهش درد با آویزان کردن پا از تخت</li>
<li>پوست سرد، رنگ‌پریده یا کبود</li>
<li>کاهش یا فقدان نبض پا (دورسالیس پدیس، پشت قوزک)</li>
<li>ریزش موهای پا</li>
<li>ضخیم شدن ناخن‌ها</li>
</ul>
<h2>تشخیص دقیق</h2>
<ul>
<li>معاینه‌ی نبض‌های محیطی</li>
<li>ABI (Ankle-Brachial Index) — کمتر از ۰.۹ غیرطبیعی است</li>
<li>سونوگرافی داپلر شریانی</li>
<li>CT آنژیوگرافی یا MRA در موارد مشکوک</li>
<li>آنژیوگرافی تشخیصی</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>ارجاع فوری به متخصص عروق:</strong> اولین قدم در هر زخم شریانی</li>
<li>
<strong>درمان revascularization:</strong> آنژیوپلاستی، استنت‌گذاری یا بای‌پس عروقی</li>
<li>
<strong>اکسیژن درمانی فشار بالا (HBOT):</strong> به‌خصوص در زخم‌های ایسکمیک</li>
<li>
<strong>کنترل عوامل خطر:</strong> سیگار، فشار خون، کلسترول، دیابت</li>
<li>
<strong>پانسمان مناسب:</strong> با اجتناب از پانسمان‌های occlusive</li>
<li>
<strong>درمان درد:</strong> پروتکل اختصاصی کنترل درد ایسکمیک</li>
<li>
<strong>اجتناب از فشار:</strong> کفش طبی، تخت مخصوص</li>
<li>
<strong>دبریدمان محتاطانه:</strong> فقط پس از تأیید جریان خون کافی</li>
</ul>
<strong>⚠️ هشدار مهم:</strong> در زخم شریانی، درمان فشاری (مثل بانداژ یا جوراب واریس) ممنوع است و می‌تواند زخم را بدتر کند. تشخیص افتراقی با زخم وریدی حیاتی است.
<h2>پیشگیری</h2>
<ul>
<li>ترک سیگار (مهم‌ترین اقدام)</li>
<li>کنترل فشار خون، کلسترول و قند خون</li>
<li>ورزش منظم — به‌خصوص پیاده‌روی</li>
<li>رژیم غذایی سالم (مدیترانه‌ای)</li>
<li>کفش مناسب و معاینه‌ی روزانه‌ی پاها</li>
<li>ویزیت سالانه‌ی عروقی در بیماران پرخطر</li>
</ul>' WHERE path = '/service/arterial-ulcer/';

UPDATE pages SET body = '<h2>درمان تب مالت (بروسلوز)</h2>
<p>تب مالت (بروسلوز) یکی از شایع‌ترین عفونت‌های مشترک بین انسان و حیوان (زئونوز) در ایران است. مصرف لبنیات غیرپاستوریزه و کار با دام، اصلی‌ترین راه ابتلا است. <strong>کلینیک عفونی همراه</strong> با تجربه‌ی بالا در تشخیص و درمان بروسلوز، نتایج بسیار خوبی در درمان ارائه می‌دهد.</p>
<h2>راه‌های ابتلا</h2>
<ul>
<li>مصرف شیر، پنیر، خامه‌ی غیرپاستوریزه</li>
<li>تماس مستقیم با دام آلوده</li>
<li>تماس با ترشحات زایمان دام</li>
<li>کار در دامداری، کشتارگاه، آزمایشگاه</li>
<li>استنشاق در محیط آلوده</li>
</ul>
<h2>علائم تب مالت</h2>
<ul>
<li>
<strong>تب موج‌دار (Undulant Fever):</strong> الگوی کلاسیک</li>
<li>تعریق شدید شبانه</li>
<li>درد مفاصل و عضلات</li>
<li>کمردرد (در بروسلوز ستون فقرات)</li>
<li>خستگی مفرط</li>
<li>کاهش وزن</li>
<li>بزرگی طحال و کبد</li>
<li>سردرد و افسردگی</li>
</ul>
<h2>تشخیص</h2>
<ul>
<li>
<strong>تست رایت (Wright):</strong> آنتی‌بادی کلاسیک — تیتر بالای ۱:۱۶۰ تشخیصی</li>
<li>
<strong>۲ME:</strong> برای تشخیص افتراقی فاز حاد و مزمن</li>
<li>
<strong>کومبس رایت:</strong> در موارد مزمن</li>
<li>
<strong>کشت خون:</strong> Gold Standard (۲-۴ هفته رشد)</li>
<li>
<strong>PCR:</strong> سریع‌تر، در آزمایشگاه‌های تخصصی</li>
<li>
<strong>تصویربرداری:</strong> برای بررسی عوارض</li>
</ul>
<h2>عوارض احتمالی</h2>
<ul>
<li>اسپوندیلیت (سل ستون فقرات شکل)</li>
<li>آرتریت</li>
<li>اندوکاردیت (خطرناک‌ترین — ۸۰٪ مرگ‌و‌میر اگر درمان نشود)</li>
<li>مننژیت</li>
<li>اورکیت</li>
<li>هپاتیت</li>
</ul>
<h2>درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>رژیم استاندارد بزرگسال:</strong> داکسی‌سیکلین + ریفامپین به مدت ۶ هفته</li>
<li>
<strong>رژیم جایگزین:</strong> داکسی‌سیکلین + استرپتومایسین</li>
<li>
<strong>اسپوندیلیت:</strong> ۳ ماه یا بیشتر</li>
<li>
<strong>اندوکاردیت:</strong> ۶+ ماه + جراحی</li>
<li>
<strong>کودکان:</strong> کوتریموکسازول + ریفامپین</li>
<li>
<strong>باردار:</strong> ریفامپین + کوتریموکسازول</li>
<li>
<strong>پایش:</strong> ماهانه — آنزیم کبد و CBC</li>
</ul>
<h2>پیشگیری</h2>
<ul>
<li>پاستوریزه کردن یا جوشاندن شیر</li>
<li>اجتناب از پنیر تازه‌ی غیرپاستوریزه</li>
<li>استفاده از دستکش و ماسک در کار با دام</li>
<li>واکسیناسیون دام‌ها</li>
</ul>
<h3>تشخیص و درمان تب مالت</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/brucellosis/';

UPDATE pages SET body = '<h2>درمان زخم سوختگی</h2>
<p>زخم سوختگی یکی از پیچیده‌ترین انواع زخم است که نیاز به مراقبت تخصصی برای کاهش عوارض، اسکار و عفونت دارد. <strong>کلینیک زخم همراه</strong> با پروتکل‌های مدرن، درمان سوختگی‌های درجه ۱ تا ۳ سرپایی و پیگیری پس از ترخیص بیماران بستری را ارائه می‌دهد.</p>
<h2>درجه‌بندی سوختگی</h2>
<ul>
<li>
<strong>درجه ۱ (سطحی):</strong> فقط اپیدرم — قرمزی، درد، بدون تاول</li>
<li>
<strong>درجه ۲ سطحی:</strong> اپیدرم و درم سطحی — تاول، درد شدید</li>
<li>
<strong>درجه ۲ عمقی:</strong> درم عمیق‌تر — درد کمتر، تاول، خطر اسکار</li>
<li>
<strong>درجه ۳:</strong> تمام لایه‌های پوست — بدون درد در محل سوختگی، نیاز به پیوند پوست</li>
<li>
<strong>درجه ۴:</strong> آسیب به عضله، استخوان — اورژانسی</li>
</ul>
<h2>چه زمانی به اورژانس مراجعه کنیم؟</h2>
<ul>
<li>سوختگی بیش از ۱۰٪ سطح بدن</li>
<li>سوختگی صورت، دست، پا، تناسلی</li>
<li>سوختگی الکتریکی یا شیمیایی</li>
<li>سوختگی استنشاقی</li>
<li>سوختگی در کودکان یا سالمندان با وسعت قابل توجه</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<p>کلینیک همراه برای موارد سوختگی <strong>سرپایی</strong> و پیگیری پس از ترخیص بیمارستانی فعالیت می‌کند. موارد حاد و وسیع باید ابتدا در مرکز سوختگی تخصصی بستری شوند.</p>
<ul>
<li>
<strong>پانسمان‌های تخصصی سوختگی:</strong> سیلور سولفادیازین، Acticoat، Mepitel</li>
<li>
<strong>درمان درد:</strong> پروتکل کنترل درد در تعویض پانسمان</li>
<li>
<strong>پیشگیری از عفونت:</strong> پانسمان آنتی‌میکروبیال</li>
<li>
<strong>درمان اسکار:</strong> سیلیکون شیت، فشار، لیزر</li>
<li>
<strong>فیزیوتراپی و توان‌بخشی:</strong> برای جلوگیری از کنتراکچر</li>
<li>
<strong>مشاوره تغذیه:</strong> افزایش پروتئین و کالری</li>
<li>
<strong>درمان روان‌شناختی:</strong> برای بیمارانی با اسکار قابل مشاهده</li>
</ul>
<h2>پیشگیری از اسکار</h2>
<ul>
<li>محافظت از آفتاب با کرم ضدآفتاب SPF 50+</li>
<li>استفاده از شیت سیلیکون از هفته‌ی ۲ به بعد</li>
<li>ماساژ پوست با کرم مرطوب‌کننده</li>
<li>پوشش الاستیک فشاری</li>
<li>لیزر فرکشنال در صورت نیاز</li>
</ul>' WHERE path = '/service/burn-wound/';

UPDATE pages SET body = '<h2>درمان زخم مزمن غیرملتئم</h2>
<p>زخم مزمن (Chronic Wound) هر زخمی است که در عرض ۶ هفته با درمان‌های متداول بهبود نیافته باشد. این زخم‌ها معمولاً علامت یک بیماری زمینه‌ای هستند و نیازمند ارزیابی جامع و چندتخصصی هستند. <strong>کلینیک زخم همراه</strong> با رویکرد MDT و ارزیابی ریشه‌ای، علت اصلی زخم را شناسایی و درمان می‌کند.</p>
<h2>چرا زخم‌ها مزمن می‌شوند؟</h2>
<p>زخم زمانی مزمن می‌شود که فرآیند طبیعی بهبود در یکی از فازها (التهاب، تکثیر، بازسازی) متوقف می‌شود. علل اصلی:</p>
<ul>
<li>کاهش جریان خون (شریانی یا وریدی)</li>
<li>عفونت مزمن (Biofilm)</li>
<li>سوءتغذیه و کمبود پروتئین</li>
<li>دیابت و بیماری‌های متابولیک</li>
<li>فشار مداوم (در بیماران بستری)</li>
<li>مصرف کورتیکواستروئید یا داروهای سرکوب‌کننده ایمنی</li>
<li>سن بالا</li>
<li>سیگار کشیدن</li>
<li>سوءتغذیه</li>
<li>زخم‌های مرتبط با بیماری‌های پوستی نادر (Pyoderma Gangrenosum، Vasculitis)</li>
</ul>
<h2>تأثیر زخم مزمن بر زندگی بیمار</h2>
<ul>
<li>درد مزمن</li>
<li>کاهش کیفیت زندگی</li>
<li>محدودیت تحرک</li>
<li>افسردگی و اضطراب</li>
<li>هزینه‌های بالای درمان</li>
<li>خطر قطع عضو در زخم‌های پای دیابتی</li>
<li>تأثیر بر فعالیت‌های اجتماعی و کاری</li>
</ul>
<h2>ارزیابی جامع در کلینیک همراه</h2>
<p>قبل از شروع هر درمانی، یک ارزیابی کامل برای شناسایی علت ریشه‌ای انجام می‌شود:</p>
<ul>
<li>تاریخچه‌ی کامل پزشکی و بیماری‌های زمینه‌ای</li>
<li>معاینه‌ی فیزیکی و عروقی</li>
<li>سونوگرافی داپلر شریانی و وریدی</li>
<li>تست‌های آزمایشگاهی (HbA1c، CBC، آلبومین، CRP)</li>
<li>کشت میکروبی زخم</li>
<li>بیوپسی در موارد مشکوک</li>
<li>ارزیابی تغذیه‌ای</li>
<li>ارزیابی روانی</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>درمان علت زمینه‌ای:</strong> کنترل دیابت، اصلاح نارسایی وریدی، revascularization در زخم شریانی</li>
<li>
<strong>دبریدمان منظم:</strong> برداشتن بافت مرده و Biofilm</li>
<li>
<strong>NPWT:</strong> به‌ویژه برای زخم‌های عمیق و وسیع</li>
<li>
<strong>HBOT:</strong> برای زخم‌های ایسکمیک و دیابتی پیشرفته</li>
<li>
<strong>پانسمان‌های پیشرفته:</strong> Bioactive، Growth Factors</li>
<li>
<strong>پیوند پوست یا فاکتورهای رشد:</strong> در زخم‌های وسیع</li>
<li>
<strong>PRP (Platelet-Rich Plasma):</strong> در موارد منتخب</li>
<li>
<strong>کنترل عفونت:</strong> آنتی‌بیوتیک هدفمند، Antiseptic مناسب</li>
<li>
<strong>مشاوره تغذیه:</strong> برای تأمین پروتئین و میکرونوترینت‌ها</li>
<li>
<strong>درمان درد:</strong> پروتکل اختصاصی</li>
<li>
<strong>مراقبت روانی:</strong> در صورت افسردگی همراه</li>
</ul>' WHERE path = '/service/chronic-wound/';

UPDATE pages SET body = '<h2>درمان دیابت</h2>
<p>دیابت شایع‌ترین بیماری غدد درون‌ریز است و میلیون‌ها ایرانی را درگیر کرده است. این بیماری اگر کنترل نشود، به‌تدریج به چشم، کلیه، اعصاب، قلب و پاها آسیب می‌زند؛ اما با تشخیص به‌موقع و مدیریت درست، می‌توان زندگی کاملاً سالمی داشت. <strong>کلینیک غدد همراه</strong> با فوق‌تخصص غدد، پایش دقیق HbA1c، مشاوره‌ی تغذیه و درمان‌های به‌روز، کنترل پایدار قند خون را هدف قرار می‌دهد.</p>
<h2>دیابت چیست؟</h2>
<p>دیابت زمانی رخ می‌دهد که بدن نتواند قند خون (گلوکز) را به‌درستی تنظیم کند — یا به دلیل کمبود انسولین، یا به دلیل مقاومت بدن نسبت به انسولین. در نتیجه قند خون بالا می‌ماند و به مرور به بافت‌های مختلف آسیب می‌رساند.</p>
<h2>انواع دیابت</h2>
<ul>
<li>
<strong>دیابت نوع ۱:</strong> سیستم ایمنی سلول‌های تولیدکننده‌ی انسولین را تخریب می‌کند؛ معمولاً در کودکان و جوانان، نیازمند انسولین.</li>
<li>
<strong>دیابت نوع ۲:</strong> شایع‌ترین نوع (بیش از ۹۰٪)؛ مقاومت به انسولین همراه با سبک زندگی و ژنتیک.</li>
<li>
<strong>دیابت بارداری:</strong> در دوران حاملگی بروز می‌کند و نیاز به کنترل دقیق برای سلامت مادر و جنین دارد.</li>
<li>
<strong>پیش‌دیابت:</strong> قند خون بالاتر از نرمال اما نه در حد دیابت — مرحله‌ی طلایی برای پیشگیری.</li>
</ul>
<h2>علائم دیابت</h2>
<ul>
<li>تشنگی و خشکی دهان بیش از حد (پرنوشی)</li>
<li>تکرر ادرار، به‌ویژه شب‌ها (پرادراری)</li>
<li>گرسنگی زیاد (پرخوری)</li>
<li>کاهش وزن بی‌دلیل (به‌ویژه نوع ۱)</li>
<li>خستگی و بی‌حالی مزمن</li>
<li>تاری دید</li>
<li>کندی بهبود زخم‌ها</li>
<li>عفونت‌های مکرر (پوستی، ادراری، قارچی)</li>
<li>بی‌حسی یا گزگز دست و پا</li>
</ul>
<h2>تشخیص دیابت</h2>
<ul>
<li>
<strong>قند خون ناشتا (FBS):</strong> ۱۲۶ یا بالاتر = دیابت</li>
<li>
<strong>HbA1c (هموگلوبین A1c):</strong> ۶.۵٪ یا بالاتر = دیابت (نشان‌دهنده‌ی میانگین قند ۳ ماه اخیر)</li>
<li>
<strong>تست تحمل گلوکز (OGTT):</strong> قند ۲ ساعته ۲۰۰ یا بالاتر</li>
<li>
<strong>قند خون تصادفی:</strong> ۲۰۰ یا بالاتر همراه با علائم</li>
</ul>
<h2>عوارض دیابت کنترل‌نشده</h2>
<ul>
<li>
<strong>چشم (رتینوپاتی):</strong> آسیب شبکیه، خطر کوری</li>
<li>
<strong>کلیه (نفروپاتی):</strong> نارسایی کلیه</li>
<li>
<strong>اعصاب (نوروپاتی):</strong> بی‌حسی و درد دست و پا</li>
<li>
<strong>پای دیابتی:</strong> زخم‌های دیربهبود که نیاز به مراقبت تخصصی دارند</li>
<li>
<strong>قلب و عروق:</strong> سکته‌ی قلبی و مغزی</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>آموزش و مشاوره‌ی تغذیه:</strong> برنامه‌ی غذایی فردی برای کنترل قند و وزن</li>
<li>
<strong>تغییر سبک زندگی:</strong> ورزش منظم و کاهش وزن</li>
<li>
<strong>داروهای خوراکی:</strong> متفورمین و سایر داروهای کاهنده‌ی قند</li>
<li>
<strong>داروهای جدید:</strong> مهارکننده‌های SGLT2 و آگونیست‌های GLP-1 (با مزیت قلبی و کاهش وزن)</li>
<li>
<strong>انسولین‌درمانی:</strong> تنظیم دقیق دوز در نوع ۱ و نوع ۲ پیشرفته</li>
<li>
<strong>پایش منظم:</strong> HbA1c هر ۳ ماه، کنترل فشار خون و چربی</li>
<li>
<strong>غربالگری عوارض:</strong> چشم، کلیه و معاینه‌ی پا</li>
</ul>
<h2>پیشگیری و کنترل</h2>
<ul>
<li>کنترل وزن و دور کمر</li>
<li>رژیم کم‌قند و پرفیبر</li>
<li>۱۵۰ دقیقه ورزش هوازی در هفته</li>
<li>ترک سیگار</li>
<li>کنترل فشار خون و چربی خون</li>
<li>پایش منظم قند و آزمایش دوره‌ای</li>
</ul>
<h2>پزشکان بخش درمان دیابت همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان دیابت متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/diabetes/';

UPDATE pages SET body = '<h2>درمان زخم پای دیابتی</h2>
<p>زخم پای دیابتی شایع‌ترین عارضه‌ی مزمن دیابت است که در ۱۵ تا ۲۵ درصد بیماران دیابتی در طول عمرشان رخ می‌دهد. این زخم اگر به‌موقع و توسط تیم تخصصی درمان نشود، می‌تواند منجر به عفونت شدید، گانگرن و حتی قطع عضو شود. در <strong>کلینیک زخم همراه</strong> با ترکیب تخصص‌های عروق، غدد، تغذیه و طب ایرانی، و استفاده از پیشرفته‌ترین روش‌های روز دنیا، نرخ بهبودی بالایی را ارائه می‌دهیم.</p>
<h2>زخم پای دیابتی چیست و چرا خطرناک است؟</h2>
<p>زخم پای دیابتی به زخم باز یا ضایعه‌ای گفته می‌شود که در پای فرد مبتلا به دیابت ایجاد می‌شود و معمولاً در کف پا، انگشتان یا قسمت‌های فشاری دیده می‌شود. سه عامل اصلی در ایجاد این زخم نقش دارند:</p>
<ul>
<li>
<strong>نوروپاتی دیابتی:</strong> آسیب به اعصاب محیطی که باعث می‌شود بیمار درد یا فشار غیرعادی را احساس نکند.</li>
<li>
<strong>بیماری شریان محیطی:</strong> کاهش جریان خون به پاها که اکسیژن‌رسانی به بافت را مختل می‌کند.</li>
<li>
<strong>اختلال در سیستم ایمنی:</strong> دیابت کنترل‌نشده پاسخ ایمنی بدن را ضعیف می‌کند و خطر عفونت را افزایش می‌دهد.</li>
</ul>
<h2>علل و عوامل خطر</h2>
<ul>
<li>قند خون کنترل‌نشده (HbA1c بالای ۷)</li>
<li>سابقه‌ی زخم قبلی پا</li>
<li>بدشکلی پا (مانند پای شارکو)</li>
<li>کفش نامناسب و فشار غیرعادی</li>
<li>سیگار کشیدن</li>
<li>چاقی و فشار خون بالا</li>
<li>عدم معاینه‌ی منظم پاها</li>
</ul>
<h2>علائم هشدار — چه زمانی به پزشک مراجعه کنم؟</h2>
<ul>
<li>هر زخم باز در پا، حتی کوچک، که در عرض ۲ هفته بهبود نیافته باشد</li>
<li>قرمزی، گرمی یا تورم اطراف زخم</li>
<li>ترشح چرکی یا بدبویی از زخم</li>
<li>سیاه شدن بافت اطراف زخم (گانگرن)</li>
<li>درد شدید یا بی‌حسی فزاینده‌ی پا</li>
<li>تب همراه با هر یک از موارد بالا</li>
</ul>
<h2>درجه‌بندی زخم پای دیابتی (Wagner Classification)</h2>
<ul>
<li>
<strong>درجه ۰:</strong> پای پرخطر بدون زخم</li>
<li>
<strong>درجه ۱:</strong> زخم سطحی</li>
<li>
<strong>درجه ۲:</strong> زخم عمقی تا تاندون یا کپسول مفصل</li>
<li>
<strong>درجه ۳:</strong> زخم همراه با عفونت عمقی، آبسه یا استئومیلیت</li>
<li>
<strong>درجه ۴:</strong> گانگرن موضعی (انگشتان یا قسمتی از پا)</li>
<li>
<strong>درجه ۵:</strong> گانگرن گسترده (نیازمند جراحی فوری)</li>
</ul>
<h2>روش‌های درمان در کلینیک زخم همراه</h2>
<p>درمان زخم پای دیابتی نیازمند رویکرد چندبعدی است که در کلینیک همراه به این صورت اجرا می‌شود:</p>
<ul>
<li>
<strong>کنترل قند خون:</strong> همکاری با متخصص غدد برای تنظیم دقیق درمان دیابت</li>
<li>
<strong>دبریدمان (Debridement):</strong> پاک‌سازی بافت‌های مرده و عفونی به روش جراحی، آنزیمی یا اتولیتیک</li>
<li>
<strong>وکیوم تراپی (NPWT):</strong> استفاده از دستگاه فشار منفی برای تسریع بافت‌سازی</li>
<li>
<strong>اکسیژن درمانی فشار بالا (HBOT):</strong> برای زخم‌های عمیق و ایسکمیک</li>
<li>
<strong>پانسمان‌های نوین:</strong> هیدروکلوئید، آلژینات، فوم، نقره — متناسب با مرحله‌ی زخم</li>
<li>
<strong>آنتی‌بیوتیک هدفمند:</strong> پس از کشت میکروبی</li>
<li>
<strong>کفش طبی و کاهش فشار (Offloading):</strong> با Total Contact Cast یا کفش‌های اختصاصی</li>
<li>
<strong>مشاوره تغذیه:</strong> برای کنترل قند و تأمین پروتئین و ویتامین‌های لازم</li>
<li>
<strong>درمان مکمل طب ایرانی:</strong> در موارد منتخب و با تأیید پزشک معالج</li>
</ul>
<h2>پیشگیری از زخم پای دیابتی</h2>
<ul>
<li>کنترل دقیق قند خون (HbA1c زیر ۷)</li>
<li>معاینه‌ی روزانه‌ی پاها (به‌ویژه کف و بین انگشتان)</li>
<li>استفاده از کفش طبی مناسب — هرگز پابرهنه راه نروید</li>
<li>کوتاه کردن صاف ناخن‌ها (نه گرد)</li>
<li>حفظ خشکی فضای بین انگشتان</li>
<li>مرطوب کردن پوست پا (به جز بین انگشتان)</li>
<li>ترک سیگار</li>
<li>ویزیت سالانه‌ی متخصص پای دیابتی</li>
</ul>
<h2>چقدر طول می‌کشد زخم پای دیابتی خوب شود؟</h2>
<p>زمان بهبود بستگی به عمق زخم، کنترل قند، وضعیت عروقی و تبعیت بیمار دارد. زخم‌های درجه ۱ ممکن است ۴-۶ هفته، اما زخم‌های عمیق‌تر یا با عفونت ممکن است ۳ تا ۶ ماه نیاز داشته باشند. در طول این مدت، ویزیت‌های منظم هر ۱-۲ هفته ضروری است.</p>' WHERE path = '/service/diabetic-foot/';

UPDATE pages SET body = '<h2>مرکز تخصصی غدد درون‌ریز و متابولیسم</h2>
<p>بخش غدد کلینیک همراه، مرجعی تخصصی برای تشخیص و درمان بیماری‌های هورمونی شامل دیابت، تیروئید، چاقی، پوکی استخوان و اختلالات متابولیک است. این مرکز با بهره‌گیری از <strong>فوق تخصصین غدد و متابولیسم</strong>، پنل کامل آزمایشگاهی، سونوگرافی تیروئید و مشاوره تغذیه، رویکردی جامع و مبتنی بر شواهد روز دنیا را برای سلامت هورمونی شما ارائه می‌دهد.</p>
<p>ما در کلینیک غدد همراه معتقدیم که &#8220;هورمون‌ها فرماندهان بدن هستند&#8221;. اختلال در آن‌ها تنها یک عدد آزمایش نیست، بلکه بر انرژی، خلق‌وخو و کیفیت زندگی تأثیر می‌گذارد. رویکرد ما مدیریت دقیق و بلندمدت بیماری‌های مزمن مانند دیابت و تیروئید برای پیشگیری از عوارض آینده است.</p>
<h2>چرا کلینیک غدد همراه؟</h2>
<p>👨‍⚕️</p>
<h3>فوق تخصص غدد</h3>
<p>مدیریت پیچیده‌ترین اختلالات هورمونی</p>
<p>🧪</p>
<h3>پنل هورمونی کامل</h3>
<p>دسترسی سریع به تست‌های تخصصی</p>
<p>🔬</p>
<h3>سونوگرافی تیروئید</h3>
<p>انجام در محل کلینیک با دقت بالا</p>
<h2>طیف خدمات تخصصی غدد</h2>
<p>💉</p>
<h3>دیابت و قند خون</h3>
<p>کنترل دقیق دیابت نوع ۱ و ۲، پیش‌دیابت و دیابت بارداری با پایش HbA1c و آموزش سبک زندگی.</p>
<p>🦋</p>
<h3>بیماری‌های تیروئید</h3>
<p>درمان کم‌کاری و پرکاری تیروئید، گواتر و بررسی ندول‌ها با سونوگرافی و نمونه‌برداری (FNA).</p>
<p>⚖️</p>
<h3>چاقی و متابولیسم</h3>
<p>بررسی علل هورمونی چاقی، سندرم متابولیک و ارائه برنامه کاهش وزن علمی با همکاری متخصص تغذیه.</p>
<p>🦴</p>
<h3>پوکی استخوان</h3>
<p>سنجش تراکم استخوان (DEXA)، پیشگیری از شکستگی و درمان پوکی استخوان به‌ویژه در دوران یائسگی.</p>
<p>👩</p>
<h3>تخمدان پلی‌کیستیک (PCOS)</h3>
<p>درمان بی‌نظمی قاعدگی، پرمویی، آکنه و ناباروری ناشی از تنبلی تخمدان با رویکرد متابولیک.</p>
<p>🧠</p>
<h3>غده هیپوفیز و فوق کلیه</h3>
<p>تشخیص و درمان تومورهای هیپوفیز، سندرم کوشینگ، آدیسون و فشار خون‌های با منشأ هورمونی.</p>
<h2>مقایسه روش‌های کنترل دیابت</h2>
<table>
<thead>
<tr>
<th>روش کنترل</th>
<th>کاربرد اصلی</th>
<th>مزیت کلیدی</th>
<th>پایش</th>
</tr>
</thead>
<tbody>
<tr>
<td>قرص‌های خوراکی (متفورمین و&#8230;)</td>
<td>دیابت نوع ۲ اولیه</td>
<td>استفاده آسان و غیرتهاجمی</td>
<td>روزانه (قند ناشتا)</td>
</tr>
<tr>
<td>تزریق انسولین</td>
<td>دیابت نوع ۱ و نوع ۲ پیشرفته</td>
<td>کنترل دقیق و سریع قند خون</td>
<td>چند بار در روز</td>
</tr>
<tr>
<td>پمپ انسولین</td>
<td>دیابت‌های ناپایدار و حساس</td>
<td>شبیه‌سازی ترشح طبیعی لوزالمعده</td>
<td>مستمر (CGM)</td>
</tr>
<tr>
<td>اصلاح سبک زندگی</td>
<td>پیش‌دیابت و تمام مراحل دیابت</td>
<td>کاهش نیاز به دارو و بهبود سلامت عمومی</td>
<td>هر ۳ ماه (HbA1c)</td>
</tr>
</tbody>
</table>
<h3>توصیه تخصصی</h3>
<p>دیابت فقط قند خون بالا نیست؛ بلکه دشمن خاموش عروق و اعصاب است. کنترل منظم قند خون نه تنها از زخم پای دیابتی جلوگیری می‌کند، بلکه خطر سکته قلبی و مغزی را به شدت کاهش می‌دهد. پایش سه ماهه (HbA1c) را جدی بگیرید.</p>
<h2>تکنولوژی‌های تشخیصی و درمانی</h2>
<h3>۱. سونوگرافی و نمونه‌برداری تیروئید</h3>
<p>استفاده از دستگاه‌های سونوگرافی دقیق برای بررسی گره‌های تیروئید و انجام نمونه‌برداری سوزنی ظریف (FNA) در همان جلسه برای رد یا تایید بدخیمی بدون نیاز به جراحی باز.</p>
<h3>۲. سنجش تراکم استخوان (DEXA)</h3>
<p>تشخیص زودهنگام پوکی استخوان قبل از وقوع شکستگی. این روش استاندارد طلایی برای ارزیابی سلامت استخوان‌ها در زنان یائسه و افراد مسن است.</p>
<h3>۳. مدیریت نوین چاقی (GLP-1 Agonists)</h3>
<p>استفاده از داروهای جدید تزریقی که علاوه بر کنترل قند، با مکانیسم‌های هورمونی باعث کاهش اشتها و کاهش وزن قابل توجه در بیماران چاق می‌شوند.</p>
<h3>نکته مهم</h3>
<p>مصرف خودسرانه مکمل‌های کلسیم یا ویتامین D بدون آزمایش خون می‌تواند منجر به رسوب کلسیم در کلیه شود. همیشه دوز مصرفی را تحت نظر پزشک و بر اساس سطح سرمی ویتامین‌های بدن تنظیم کنید.</p>
<h2>چک‌لیست سلامت غدد</h2>
<p>✓<br></p>
<p>چکاپ سالانه قند خون ناشتا و TSH (تیروئید) برای افراد بالای ۳۵ سال</p>
<p>✓<br></p>
<p>مصرف کافی کلسیم و ویتامین D و انجام فعالیت ورزشی منظم برای استحکام استخوان</p>
<p>✓<br></p>
<p>حفظ وزن ایده‌آل برای پیشگیری از مقاومت به انسولین و کبد چرب</p>
<p>✓<br></p>
<p>بررسی دوره‌ای پاها در بیماران دیابتی برای پیشگیری از زخم و عفونت</p>
<p>✓<br></p>
<p>مدیریت استرس و خواب کافی (کورتیزول بالا دشمن تعادل هورمونی است)</p>' WHERE path = '/service/endocrine-clinic/';

UPDATE pages SET body = '<h2>بررسی تب با علت نامشخص (FUO)</h2>
<p>تب با علت نامشخص (FUO) به تب بیش از ۳۸.۳ که حداقل ۳ هفته طول کشیده و پس از بررسی‌های اولیه علت آن مشخص نشده، گفته می‌شود. <strong>کلینیک عفونی همراه</strong> با رویکرد سیستماتیک و بررسی جامع، علل پنهان تب را شناسایی می‌کند.</p>
<h2>تعریف FUO</h2>
<ul>
<li>تب بیش از ۳۸.۳ درجه</li>
<li>مدت بیش از ۳ هفته</li>
<li>عدم تشخیص پس از بررسی اولیه</li>
</ul>
<h2>دسته‌بندی علل (FUO کلاسیک)</h2>
<ul>
<li>
<strong>عفونی (۲۰-۳۰٪):</strong> سل، آبسه‌ی پنهان، اندوکاردیت، بروسلوز، HIV</li>
<li>
<strong>بدخیمی (۲۰٪):</strong> لنفوم، سرطان کلیه، لوسمی</li>
<li>
<strong>التهابی غیرعفونی (۲۰٪):</strong> آرتریت روماتوئید، لوپوس، Still’s disease، آرتریت تمپورال</li>
<li>
<strong>متفرقه:</strong> داروها، تب فاکتیشن، آمبولی ریه</li>
<li>
<strong>تشخیص نهایی نامشخص (۳۰٪)</strong>
</li>
</ul>
<h2>روند بررسی در کلینیک همراه</h2>
<ol>
<li>
<strong>تاریخچه‌ی دقیق:</strong> مسافرت، تماس با حیوان، شغل، داروها، رابطه‌ی جنسی</li>
<li>
<strong>معاینه‌ی فیزیکی کامل:</strong> هر چند روز تکرار شود</li>
<li>
<strong>آزمایش‌های پایه:</strong> CBC، ESR، CRP، آنزیم‌های کبد، ادرار، کشت خون چندگانه</li>
<li>
<strong>سرولوژی:</strong> HIV، هپاتیت، رایت، VDRL، EBV، CMV</li>
<li>
<strong>تصویربرداری:</strong> CT شکم و قفسه سینه</li>
<li>
<strong>اکوکاردیوگرافی:</strong> برای اندوکاردیت</li>
<li>
<strong>PET-CT:</strong> در موارد پیچیده — می‌تواند منبع التهاب را پیدا کند</li>
<li>
<strong>بیوپسی:</strong> از غدد لنفاوی، مغز استخوان، کبد در موارد منتخب</li>
<li>
<strong>مشاوره‌ی روماتولوژی و هماتولوژی</strong>
</li>
</ol>
<h2>چه زمانی به متخصص عفونی مراجعه کنیم؟</h2>
<ul>
<li>تب بیش از ۲ هفته بدون تشخیص</li>
<li>کاهش وزن همراه با تب</li>
<li>عرق شبانه شدید</li>
<li>سابقه‌ی مسافرت به مناطق پرخطر</li>
<li>تماس با دام</li>
<li>سابقه‌ی بیماری زمینه‌ای (HIV، شیمی‌درمانی)</li>
<li>تب پس از بازگشت از سفر</li>
</ul>
<h2>درمان</h2>
<p>درمان به علت تب بستگی دارد. هرگز آنتی‌بیوتیک یا کورتیکواستروئید کور تجویز نمی‌شود زیرا تشخیص اصلی را پنهان می‌کند. صبر و بررسی سیستماتیک، کلید درمان FUO است.</p>
<h3>ارزیابی جامع FUO</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/fever-unknown-origin/';

UPDATE pages SET body = '<h2>درمان عفونت‌های قارچی</h2>
<p>عفونت‌های قارچی از موارد سطحی پوست تا عفونت‌های مهاجم تهدیدکننده‌ی جان متفاوت‌اند. <strong>کلینیک عفونی همراه</strong> با هم‌کاری بخش انکولوژی و بیماری‌های مزمن، عفونت‌های قارچی در بیماران ایمنوساپرس را به‌صورت تخصصی مدیریت می‌کند.</p>
<h2>انواع عفونت قارچی</h2>
<ul>
<li>
<strong>سطحی پوست:</strong> تینه‌آ (پای ورزشکار، رینگ‌ورم)</li>
<li>
<strong>کاندیدیازیس:</strong> دهان، مهبل، پوست</li>
<li>
<strong>اونیکومایکوزیس:</strong> قارچ ناخن</li>
<li>
<strong>پیتیریازیس ورسیکالر:</strong> لک‌های قارچی پوست</li>
<li>
<strong>آسپرژیلوزیس:</strong> در ایمنوساپرس‌ها</li>
<li>
<strong>کاندیدمی:</strong> قارچ در خون — اورژانس</li>
<li>
<strong>کریپتوکوکوزیس:</strong> در HIV</li>
<li>
<strong>موکورمایکوزیس:</strong> قارچ سیاه (پس از COVID مشهور شد)</li>
</ul>
<h2>عوامل خطر عفونت قارچی مهاجم</h2>
<ul>
<li>دیابت کنترل‌نشده</li>
<li>شیمی‌درمانی و نوتروپنی</li>
<li>پیوند عضو</li>
<li>HIV</li>
<li>کورتیکواستروئید طولانی‌مدت</li>
<li>کاتتر مرکزی</li>
<li>تغذیه‌ی وریدی</li>
</ul>
<h2>تشخیص</h2>
<ul>
<li>اسمیر و کشت قارچ</li>
<li>تست‌های اختصاصی (Galactomannan برای آسپرژیلوس، Beta-D-glucan)</li>
<li>PCR قارچی</li>
<li>تصویربرداری (CT ریه برای آسپرژیلوزیس)</li>
<li>بیوپسی در موارد عمقی</li>
</ul>
<h2>درمان</h2>
<ul>
<li>
<strong>سطحی:</strong> ضدقارچ موضعی (کلوتریمازول، تربینافین)</li>
<li>
<strong>کاندیدیازیس واژینال:</strong> فلوکونازول تک‌دوز</li>
<li>
<strong>قارچ ناخن:</strong> تربینافین یا ایتراکونازول خوراکی ۳-۶ ماه</li>
<li>
<strong>کاندیدمی:</strong> اکینوکاندین یا فلوکونازول وریدی</li>
<li>
<strong>آسپرژیلوزیس:</strong> ووریکونازول، ایزاووکونازول</li>
<li>
<strong>موکورمایکوزیس:</strong> آمفوتریسین B + جراحی فوری</li>
<li>
<strong>کریپتوکوکوزیس:</strong> آمفوتریسین + فلوسیتوزین + فلوکونازول</li>
</ul>
<h3>تشخیص قارچ‌های مهاجم</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/fungal-infection/';

UPDATE pages SET body = '<h2>درمان عفونت‌های گوارشی</h2>
<p>عفونت‌های گوارشی از علل اصلی اسهال حاد و مزمن هستند. <strong>کلینیک عفونی همراه</strong> با تشخیص دقیق پاتوژن (باکتری، انگل، ویروس) و درمان هدفمند، از تجویز کور آنتی‌بیوتیک جلوگیری می‌کند.</p>
<h2>انواع عفونت گوارشی</h2>
<ul>
<li>
<strong>باکتریایی:</strong> سالمونلا، شیگلا، کامپیلوباکتر، اشریشیا کلی</li>
<li>
<strong>ویروسی:</strong> روتاویروس، نوروویروس (شایع‌ترین در بزرگسالان)</li>
<li>
<strong>انگلی:</strong> ژیاردیا، آمیب، کریپتوسپوریدیوم</li>
<li>
<strong>قارچی:</strong> در بیماران ایمنوساپرس</li>
<li>
<strong>پسا آنتی‌بیوتیک:</strong> C. difficile</li>
<li>
<strong>عفونت H. pylori:</strong> در زخم معده</li>
</ul>
<h2>علائم اخطاردهنده</h2>
<ul>
<li>اسهال بیش از ۳ روز</li>
<li>تب بالای ۳۸.۵</li>
<li>اسهال خونی</li>
<li>کم‌آبی شدید (کاهش ادرار، ضعف)</li>
<li>درد شدید شکم</li>
<li>اسهال در سفر یا پس از آنتی‌بیوتیک</li>
<li>در سالمندان، کودکان و باردار: مراجعه‌ی سریع‌تر</li>
</ul>
<h2>تشخیص</h2>
<ul>
<li>کشت مدفوع</li>
<li>تست انگل (آزمایش مستقیم + غنی‌سازی)</li>
<li>PCR مدفوع برای پاتوژن‌های متعدد (FilmArray GI)</li>
<li>تست تنفسی H. pylori</li>
<li>کولونوسکوپی در موارد مزمن</li>
<li>تست C. difficile (در اسهال پس از آنتی‌بیوتیک)</li>
</ul>
<h2>درمان</h2>
<ul>
<li>
<strong>ویروسی:</strong> فقط مایع‌درمانی، نیاز به آنتی‌بیوتیک نیست</li>
<li>
<strong>باکتریایی شدید:</strong> آنتی‌بیوتیک بر اساس کشت</li>
<li>
<strong>اسهال مسافرتی:</strong> سیپروفلوکساسین یا آزیترومایسین</li>
<li>
<strong>ژیاردیا و آمیب:</strong> مترونیدازول</li>
<li>
<strong>C. difficile:</strong> ونکومایسین خوراکی یا فیداکسومایسین</li>
<li>
<strong>H. pylori:</strong> رژیم سه‌گانه یا چهارگانه</li>
</ul>
<h2>پیشگیری</h2>
<ul>
<li>بهداشت دست</li>
<li>پختن کامل غذا</li>
<li>اجتناب از آب آلوده در سفر</li>
<li>پاستوریزه‌سازی شیر</li>
<li>واکسن روتاویروس برای کودکان</li>
</ul>
<h3>ارزیابی اسهال مزمن</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/gi-infection/';

UPDATE pages SET body = '<h2>درمان اختلالات رشد و بلوغ کودکان در کلینیک غدد همراه تهران</h2>
<p>رشد قد و بلوغ کودک، آینه‌ی سلامت هورمونی اوست. وقتی کودکی نسبت به هم‌سن‌وسالان خود خیلی کوتاه‌تر است، یا بلوغ او خیلی زود یا خیلی دیر آغاز می‌شود، ممکن است یک اختلال هورمونی قابل‌درمان در میان باشد. <strong>کلینیک غدد همراه</strong> با ارزیابی منحنی رشد، سن استخوانی و هورمون‌ها، اختلالات رشد و بلوغ را در زمان طلایی تشخیص و درمان می‌کند.</p>
<h2>اختلالات شایع رشد و بلوغ</h2>
<ul>
<li>
<strong>کوتاهی قد:</strong> قد به‌طور قابل‌توجه کمتر از حد انتظار سن و خانواده</li>
<li>
<strong>کمبود هورمون رشد:</strong> یکی از علل قابل‌درمان کوتاهی قد</li>
<li>
<strong>بلوغ زودرس:</strong> شروع بلوغ پیش از ۸ سالگی در دختران و ۹ سالگی در پسران</li>
<li>
<strong>بلوغ دیررس:</strong> نبود نشانه‌های بلوغ تا سنین ۱۳-۱۴ سالگی</li>
<li>
<strong>اختلال رشد ناشی از تیروئید:</strong> کم‌کاری تیروئید می‌تواند رشد را کند کند</li>
</ul>
<h2>چه زمانی کودک را نزد پزشک غدد ببریم؟</h2>
<ul>
<li>کودک از منحنی رشد طبیعی فاصله گرفته است</li>
<li>سرعت رشد قد سالانه کم است (کمتر از حد انتظار)</li>
<li>کودک نسبت به هم‌کلاسی‌ها بسیار کوتاه‌تر است</li>
<li>نشانه‌های بلوغ خیلی زود ظاهر شده‌اند</li>
<li>بلوغ با تأخیر زیاد آغاز شده است</li>
</ul>
<h2>تشخیص در کلینیک همراه</h2>
<ul>
<li>رسم و تحلیل دقیق منحنی رشد</li>
<li>تعیین سن استخوانی با رادیوگرافی مچ دست</li>
<li>اندازه‌گیری هورمون رشد و IGF-1</li>
<li>بررسی تیروئید و سایر هورمون‌ها</li>
<li>تست‌های تحریکی هورمون رشد در موارد لازم</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>هورمون رشد:</strong> در موارد تأیید‌شده‌ی کمبود، با تزریق و پایش منظم</li>
<li>
<strong>درمان بلوغ زودرس:</strong> داروهای متوقف‌کننده‌ی موقت بلوغ برای حفظ قد نهایی</li>
<li>
<strong>درمان علل زمینه‌ای:</strong> تنظیم تیروئید یا سایر اختلالات هورمونی</li>
<li>
<strong>پیگیری منظم رشد:</strong> پایش پاسخ به درمان و تنظیم برنامه</li>
</ul>
<h2>پزشکان بخش درمان اختلالات رشد و بلوغ کودکان در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان اختلالات رشد و بلوغ کودکان در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/growth-puberty/';

UPDATE pages SET body = '<h2>درمان زخم عفونی</h2>
<p>زخم عفونی هر زخمی است که علائم آلودگی میکروبی نشان می‌دهد. عفونت می‌تواند هر زخمی را که در حال بهبود است متوقف کرده و در موارد شدید جان بیمار را تهدید کند. <strong>کلینیک زخم همراه</strong> با کشت میکروبی، آنتی‌بیوتیک هدفمند و پانسمان‌های آنتی‌میکروبیال، عفونت زخم را به‌سرعت کنترل می‌کند.</p>
<h2>علائم عفونت زخم</h2>
<ul>
<li>
<strong>قرمزی:</strong> فزاینده، فراتر از ۲ سانتی‌متر اطراف زخم</li>
<li>
<strong>گرمی:</strong> پوست اطراف زخم گرم‌تر از نواحی دیگر</li>
<li>
<strong>تورم:</strong> ادم اطراف زخم</li>
<li>
<strong>درد:</strong> فزاینده و غیرمتناسب با اندازه‌ی زخم</li>
<li>
<strong>ترشح:</strong> چرکی، زرد، سبز یا خونابه‌ای زیاد</li>
<li>
<strong>بوی نامطبوع</strong>
</li>
<li>
<strong>تب و لرز</strong>
</li>
<li>
<strong>تأخیر در بهبود:</strong> بدون پیشرفت در ۲ هفته</li>
</ul>
<h2>انواع عفونت زخم</h2>
<ul>
<li>
<strong>Colonization:</strong> وجود میکروب بدون علامت — درمان آنتی‌بیوتیک لازم نیست</li>
<li>
<strong>Local Infection:</strong> عفونت موضعی با علائم بالا</li>
<li>
<strong>Spreading Infection:</strong> پخش به بافت اطراف (سلولیت)</li>
<li>
<strong>Systemic Infection:</strong> ورود به جریان خون (سپسیس) — اورژانسی</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>کشت میکروبی:</strong> تشخیص دقیق نوع باکتری و حساسیت به آنتی‌بیوتیک</li>
<li>
<strong>دبریدمان فوری:</strong> برداشتن بافت عفونی و مرده</li>
<li>
<strong>آنتی‌بیوتیک هدفمند:</strong> سیستمیک یا موضعی بسته به شدت</li>
<li>
<strong>پانسمان آنتی‌میکروبیال:</strong> نقره، یُد، هانی (عسل پزشکی)</li>
<li>
<strong>NPWT:</strong> در زخم‌های عفونی کنترل شده، می‌تواند ترشحات را خارج کند</li>
<li>
<strong>درمان ریشه‌ای:</strong> اگر زخم دیابتی، وریدی یا شریانی است، علت زمینه‌ای درمان شود</li>
<li>
<strong>ارجاع به بیمارستان:</strong> در عفونت‌های شدید یا سپسیس</li>
</ul>
<h2>میکروب‌های شایع زخم</h2>
<ul>
<li>Staphylococcus aureus (شامل MRSA)</li>
<li>Streptococcus</li>
<li>Pseudomonas aeruginosa</li>
<li>E. coli</li>
<li>Enterococcus</li>
<li>Anaerobic bacteria (در زخم‌های عمیق)</li>
</ul>
<h2>پیشگیری</h2>
<ul>
<li>شست‌وشوی صحیح زخم با سرم نمکی</li>
<li>پانسمان مناسب و به‌موقع</li>
<li>عدم خاراندن زخم</li>
<li>کنترل دیابت در بیماران دیابتی</li>
<li>تقویت سیستم ایمنی با تغذیه و خواب کافی</li>
<li>اجتناب از مصرف خودسرانه‌ی آنتی‌بیوتیک</li>
</ul>' WHERE path = '/service/infected-wound/';

UPDATE pages SET body = '<h2>مرکز تخصصی بیماری‌های عفونی و گرمسیری</h2>
<p>بخش عفونی کلینیک همراه، مرجعی تخصصی برای تشخیص و درمان انواع عفونت‌های باکتریایی، ویروسی، قارچی و انگلی است. این مرکز با بهره‌گیری از <strong>فوق تخصصین بیماری‌های عفونی </strong> و رویکرد مدیریت مصرف آنتی‌بیوتیک (Stewardship)، خدماتی دقیق و علمی را ارائه می‌دهد.</p>
<p>ما در کلینیک عفونی همراه معتقدیم که &#8220;تشخیص دقیق، نیمی از درمان است&#8221;. رویکرد ما پرهیز از تجویز کورکورانه آنتی‌بیوتیک و تمرکز بر شناسایی عامل بیماری‌زا از طریق کشت و تست‌های مولکولی برای جلوگیری از مقاومت دارویی است.</p>
<h2>مزایای درمان در کلینیک عفونی همراه</h2>
<p>💊</p>
<h3>درمان هدفمند</h3>
<p>بر اساس نتیجه کشت و آنتی‌بیوگرام</p>
<p>💉</p>
<h3>تزریق سرپایی (OPAT)</h3>
<p>بدون نیاز به بستری در بیمارستان</p>
<h2>طیف خدمات و بیماری‌های تحت پوشش</h2>
<p>🦠</p>
<h3>عفونت‌های ادراری (UTI)</h3>
<p>درمان عفونت‌های مکرر و مقاوم کلیه و مثانه با تکیه بر کشت ادرار دقیق و انتخاب آنتی‌بیوتیک مناسب.</p>
<p>🫁</p>
<h3>عفونت‌های تنفسی</h3>
<p>تشخیص و درمان پنومونی، برونشیت، سل ریوی (TB) و عوارض تنفسی پس از ویروس‌ها.</p>
<p>🛡️</p>
<h3>هپاتیت‌های ویروسی</h3>
<p>غربالگری، واکسیناسیون هپاتیت B و درمان قطعی هپاتیت C با داروهای جدید (DAA) بدون عوارض.</p>
<p>🔒</p>
<h3>عفونت‌های مقاربتی (STI)</h3>
<p>مشاوره محرمانه، تست‌های دقیق و درمان HIV، سیفلیس، گنوره و زگیل تناسلی در محیطی امن.</p>
<p>🐄</p>
<h3>تب مالت (بروسلوز)</h3>
<p>تشخیص سرولوژیک و درمان طولانی‌مدت تب مالت که از لبنیات غیرپاستوریزه یا تماس دام منتقل می‌شود.</p>
<p>🌡️</p>
<h3>تب‌های ناشناخته (FUO)</h3>
<p>بررسی جامع و تخصصی تب‌های طولانی‌مدت که علت آن‌ها در مراکز دیگر مشخص نشده است.</p>
<h2>مقایسه روش‌های تشخیص عفونت</h2>
<table>
<thead>
<tr>
<th>روش تشخیص</th>
<th>کاربرد اصلی</th>
<th>سرعت جواب‌دهی</th>
<th>دقت</th>
</tr>
</thead>
<tbody>
<tr>
<td>آزمایش خون روتین (CBC/CRP)</td>
<td>بررسی کلی وجود التهاب</td>
<td>چند ساعت</td>
<td>کم (غیر اختصاصی)</td>
</tr>
<tr>
<td>کشت میکروبی (Culture)</td>
<td>شناسایی نوع باکتری و حساسیت دارویی</td>
<td>۳ تا ۵ روز</td>
<td>بسیار بالا (استاندارد طلایی)</td>
</tr>
<tr>
<td>تست مولکولی (PCR)</td>
<td>تشخیص ویروس‌ها و باکتری‌های خاص</td>
<td>۲۴ تا ۴۸ ساعت</td>
<td>عالی (حتی در مقادیر کم)</td>
</tr>
<tr>
<td>سرولوژی (آنتی‌بادی)</td>
<td>بررسی سابقه برخورد با میکروب (مثل تب مالت)</td>
<td>۱ روز</td>
<td>متوسط (نیاز به تفسیر پزشک)</td>
</tr>
</tbody>
</table>
<h3>توصیه تخصصی</h3>
<p>مصرف خودسرانه آنتی‌بیوتیک‌ها (مثل آموکسی‌سیلین یا آزیترومایسین) نه تنها باعث بهبودی نمی‌شود، بلکه با ایجاد مقاومت میکروبی، درمان عفونت‌های بعدی را بسیار دشوار و پرهزینه می‌کند. همیشه قبل از مصرف دارو با متخصص عفونی مشورت کنید.</p>
<h2>تکنولوژی‌های درمانی و پیشگیرانه</h2>
<h3>۱. برنامه OPAT (تزریق سرپایی)</h3>
<p>برای بیمارانی که نیاز به آنتی‌بیوتیک وریدی طولانی‌مدت دارند (مانند عفونت استخوان یا دریچه قلب)، به جای بستری شدن در بیمارستان، در کلینیک تحت نظارت پرستار تزریق دریافت می‌کنند.</p>
<h3>۲. واکسیناسیون بزرگسالان</h3>
<p>ارائه واکسن‌های ضروری شامل هپاتیت B، آنفلوآنزا، پنوموکوک (ذات‌الریه)، زونا و واکسن‌های مسافرتی برای افراد بالای ۵۰ سال یا دارای بیماری زمینه‌ای.</p>
<h3>۳. مدیریت عفونت‌های بیمارستانی</h3>
<p>مشاوره تخصصی برای بیمارانی که پس از جراحی یا بستری در ICU دچار عفونت‌های مقاوم شده‌اند و نیاز به رژیم‌های دارویی ترکیبی دارند.</p>
<h3>نکته مهم</h3>
<p>اگر تب شما بیش از ۳ هفته طول کشیده و با آزمایش‌های معمولی علت آن مشخص نشده است، حتماً به متخصص عفونی مراجعه کنید. تب‌های طولانی (FUO) نیازمند بررسی‌های سیستماتیک و دقیق هستند.</p>
<h2>چک‌لیست پیشگیری از عفونت</h2>
<p>✓<br></p>
<p>شستن مرتب دست‌ها با آب و صابون (بهترین راه پیشگیری)</p>
<p>✓<br></p>
<p>دریافت واکسن‌های فصلی (آنفلوآنزا) و دوره‌ای (کزاز، هپاتیت)</p>
<p>✓<br></p>
<p>پرهیز از مصرف لبنیات غیرپاستوریزه و گوشت نیم‌پز (پیشگیری از تب مالت)</p>
<p>✓<br></p>
<p>استفاده از وسایل محافظت فردی در روابط جنسی (پیشگیری از STI)</p>
<p>✓<br></p>
<p>مراجعه سریع به پزشک در صورت مشاهده علائم عفونت زخم یا تب ناگهانی</p>' WHERE path = '/service/infectious-clinic/';

UPDATE pages SET body = '<h2>درمان زخم سرطانی و ناشی از درمان سرطان(مراقبت تخصصی)</h2>
<p>زخم‌های سرطانی یا زخم‌های ناشی از درمان سرطان (شیمی‌درمانی، رادیوتراپی) از پیچیده‌ترین موارد در درمان زخم هستند. این زخم‌ها نیاز به مراقبت چندتخصصی با همکاری انکولوژیست، متخصص درد و تیم زخم دارند. کلینیک زخم همراه با هماهنگی مستقیم با بخش انکولوژی کلینیک، خدمات کامل به این بیماران ارائه می‌دهد. هدف اصلی، افزایش کیفیت زندگی بیمار است، نه لزوماً بهبود کامل زخم در موارد پیشرفته.</p>
<p>۵-۱۰٪</p>
<p>از بیماران سرطانی دچار زخم‌های سرطانی می‌شوند</p>
<p>۹۵٪</p>
<p>اثربخشی HBOT در درمان زخم‌های رادیوتراپی</p>
<p>۷۰٪</p>
<p>کاهش بوی نامطبوع با پانسمان‌های کربن فعال</p>
<p>۲۴ ساعته</p>
<p>پشتیبانی و مشاوره تیم زخم برای بیماران سرطانی</p>
<h2>انواع زخم‌های سرطانی و ناشی از درمان</h2>
<p>زخم‌های سرطانی طیف وسیعی از ضایعات پوستی را شامل می‌شوند که هر کدام ویژگی‌ها و چالش‌های منحصربه‌فردی دارند. شناخت دقیق نوع زخم، اولین گام در طراحی پروتکل درمانی مناسب است. در بیماران سرطانی، زخم‌ها می‌توانند ناشی از خود تومور، عوارض درمان‌های مدرن، یا عوامل ثانویه مانند بستری طولانی‌مدت باشند.</p>
<p>
<strong>Fungating Wound (زخم قارچی):</strong> این نوع زخم ناشی از تومور پوستی یا تومور پیشرفته است که از پوست خارج شده و ظاهری شبیه قارچ یا گل‌کلم دارد. این زخم‌ها معمولاً بدبو، خونریزی‌دهنده و با ترشح زیاد همراه هستند. شایع‌ترین علل آن سرطان پستان پیشرفته، سرطان سر و گردن، و ملانوما هستند. مدیریت این زخم‌ها یکی از چالش‌برانگیزترین جنبه‌های مراقبت از بیماران سرطانی است.</p>
<p>
<strong>زخم رادیوتراپی (Radiation Wound):</strong> آسیب پوستی ناشی از پرتودرمانی که می‌تواند به‌صورت درماتیت حاد (قرمزی، پوسته‌ریزی) یا زخم باز مزمن ظاهر شود. این زخم‌ها معمولاً در محدوده میدان تابش قرار دارند و به دلیل آسیب عروقی و فیبروز بافتی، بهبود آن‌ها بسیار کند و دشوار است. Late Radiation Tissue Injury (LRTI) می‌تواند ماه‌ها یا سال‌ها پس از اتمام رادیوتراپی ظاهر شود.</p>
<p>
<strong>Extravasation (نشت داروی شیمی‌درمانی):</strong> زمانی رخ می‌دهد که داروی شیمی‌درمانی از رگ به بافت اطراف نشت کند. این عارضه می‌تواند منجر به نکروز بافتی شدید، تاول‌های دردناک و در موارد شدید، آسیب به تاندون‌ها و اعصاب شود. داروهای وزیکانت (مانند دوکسوروبیسین، وینکریستین) بیشترین خطر را دارند و نیاز به مداخله فوری دارند.</p>
<p>
<strong>زخم فشاری در بیمار سرطانی:</strong> به دلیل بستری طولانی، سوءتغذیه، و ضعف عمومی، بیماران سرطانی در معرض خطر بالای زخم فشاری قرار دارند. این زخم‌ها معمولاً در نواحی استخوانی مانند ساکروم، پاشنه پا، و شانه‌ها ایجاد می‌شوند و به دلیل ضعف سیستم ایمنی، مستعد عفونت هستند.</p>
<p>
<strong>زخم پس از جراحی سرطان:</strong> شامل زخم‌های ناشی از ماستکتومی (برداشتن پستان)، تومور بزرگ‌برداری، و جراحی‌های بازساختی. این زخم‌ها ممکن است به دلیل رادیوتراپی پس از جراحی، دچار تأخیر در بهبود شوند یا دچار dehiscence (باز شدن لبه‌های زخم) شوند.</p>
<h2>چالش‌های منحصر به فرد در درمان زخم‌های سرطانی</h2>
<p>درمان زخم در بیماران سرطانی با چالش‌های پیچیده‌ای مواجه است که آن را از درمان زخم‌های معمولی متمایز می‌کند. این چالش‌ها نه‌تنها بر فرآیند بهبود تأثیر می‌گذارند، بلکه نیاز به رویکردی چندبعدی و هماهنگ با تیم انکولوژی دارند.</p>
<p>
<strong>سیستم ایمنی ضعیف:</strong> شیمی‌درمانی باعث سرکوب مغز استخوان و کاهش گلبول‌های سفید (نوتروپنی) می‌شود. این وضعیت خطر عفونت زخم را به‌شدت افزایش می‌دهد و حتی عفونت‌های معمولی می‌توانند به سپسیس و تهدید حیات تبدیل شوند. انتخاب آنتی‌بیوتیک‌ها و زمان‌بندی تعویض پانسمان باید با دقت فراوان انجام شود.</p>
<p>
<strong>بافت ضعیف ناشی از رادیوتراپی:</strong> پرتودرمانی باعث آسیب عروق خونی کوچک، فیبروز بافتی، و کاهش اکسیژن‌رسانی می‌شود. این بافت &#8220;هیپوکسیک&#8221; توانایی محدودی برای ترمیم دارد و حتی زخم‌های کوچک می‌توانند به‌صورت مزمن باقی بمانند. درمان این زخم‌ها نیازمند تکنیک‌های ویژه مانند HBOT است.</p>
<p>
<strong>کاهش گلبول سفید و پلاکت:</strong> ترومبوسیتوپنی (کاهش پلاکت) خطر خونریزی را افزایش می‌دهد و تعویض پانسمان را به یک چالش تبدیل می‌کند. حتی پاک‌کردن ملایم زخم می‌تواند منجر به خونریزی شود. استفاده از پانسمان‌های غیرچسبنده و تکنیک‌های هموستاتیک ضروری است.</p>
<p>
<strong>سوءتغذیه و کاهش وزن:</strong> بیماران سرطانی اغلب دچار کاککسی (cachexia) و سوءتغذیه پروتئینی-انرژی هستند. کمبود پروتئین، ویتامین C، روی، و آهن، فرآیند ترمیم زخم را مختل می‌کند. حمایت تغذیه‌ای بخشی جدایی‌ناپذیر از درمان زخم است.</p>
<p>
<strong>خونریزی و ترشح زیاد:</strong> زخم‌های سرطانی، به‌ویژه Fungating Wound، مستعد خونریزی‌های مکرر و ترشح شدید هستند. این موضوع نه‌تنها تعویض پانسمان را دشوار می‌کند، بلکه خطر کم‌خونی و عفونت را افزایش می‌دهد.</p>
<p>
<strong>بوی نامطبوع شدید:</strong> در زخم‌های Fungating، باکتری‌های بی‌هوازی (مانند باکتروئیدس و کلستریدیوم) با تجزیه بافت نکروتیک، ترکیبات گوگردی تولید می‌کنند که بوی بسیار تند و نامطبوعی ایجاد می‌کند. این بو می‌تواند برای بیمار و خانواده بسیار آزاردهنده باشد و بر کیفیت زندگی و روابط اجتماعی تأثیر منفی بگذارد.</p>
<p>
<strong>تأثیر روانی و کاهش کیفیت زندگی:</strong> زخم‌های سرطانی، به‌ویژه آن‌هایی که قابل رؤیت هستند، می‌توانند منجر به افسردگی، اضطراب، انزوا اجتماعی، و کاهش اعتمادبه‌نفس شوند. حمایت روان‌شناختی بخشی ضروری از مراقبت جامع است.</p>
<h2>ویژگی‌های کلیدی درمان زخم سرطانی در کلینیک همراه</h2>
<p>🤝</p>
<h3>هماهنگی با تیم انکولوژی</h3>
<p>ارتباط مستقیم با پزشک معالج سرطان برای تصمیم‌گیری یکپارچه</p>
<p>🌬️</p>
<h3>کنترل بو</h3>
<p>پانسمان‌های کربن فعال، مترونیدازول موضعی، و تکنیک‌های ضدباکتریایی</p>
<p>🩸</p>
<h3>کنترل خونریزی</h3>
<p>پانسمان‌های هموستاتیک، آلژینات، و تکنیک‌های فشاری</p>
<p>💧</p>
<h3>کنترل ترشح</h3>
<p>پانسمان‌های جذبی پیشرفته مانند فوم‌ها و هیدروفایبر</p>
<p>💊</p>
<h3>کنترل درد</h3>
<p>پانسمان با لیدوکائین، مورفین موضعی در موارد خاص، و مدیریت دارویی</p>
<p>🫁</p>
<h3>HBOT (اکسیژن درمانی)</h3>
<p>برای زخم‌های رادیوتراپی با شواهد علمی قوی</p>
<h2>مقایسه انواع زخم‌های سرطانی و رویکردهای درمانی</h2>
<table>
<thead>
<tr>
<th>نوع زخم</th>
<th>علت اصلی</th>
<th>ویژگی‌های بالینی</th>
<th>چالش اصلی</th>
<th>رویکرد درمانی</th>
</tr>
</thead>
<tbody>
<tr>
<td>Fungating Wound</td>
<td>تومور پیشرفته</td>
<td>ظاهر قارچی، بدبو، خونریزی</td>
<td>بو، خونریزی، ترشح</td>
<td>کنترل علائم، کربن فعال</td>
</tr>
<tr>
<td>زخم رادیوتراپی</td>
<td>آسیب پرتو</td>
<td>بافت فیبروتیک، هیپوکسی</td>
<td>بهبود کند، عود مکرر</td>
<td>HBOT، پانسمان مرطوب</td>
</tr>
<tr>
<td>Extravasation</td>
<td>نشت داروی شیمی‌درمانی</td>
<td>نکروز، تاول، درد شدید</td>
<td>پیشرفت سریع، آسیب عمقی</td>
<td>مداخله فوری، پادزهر</td>
</tr>
<tr>
<td>زخم فشاری</td>
<td>فشار طولانی‌مدت</td>
<td>نواحی استخوانی، نکروز</td>
<td>عفونت، سوءتغذیه</td>
<td>تغییر پوزیشن، حمایت تغذیه‌ای</td>
</tr>
<tr>
<td>زخم پس از جراحی</td>
<td>ماستکتومی، توموربرداری</td>
<td>dehiscence، تأخیر در بهبود</td>
<td>رادیوتراپی پس از جراحی</td>
<td>پانسمان مرطوب، NPWT</td>
</tr>
<tr>
<td>درماتیت رادیواکتیو</td>
<td>پرتودرمانی حاد</td>
<td>قرمزی، پوسته‌ریزی، خارش</td>
<td>درد، حساسیت</td>
<td>کرم‌های مرطوب‌کننده، پانسمان غیرچسبنده</td>
</tr>
</tbody>
</table>
<h3>توصیه تخصصی</h3>
<p>در بیماران سرطانی، هدف اصلی درمان زخم، افزایش کیفیت زندگی است، نه لزوماً بهبود کامل زخم در موارد پیشرفته. این رویکرد &#8220;palliative wound care&#8221; بر کنترل علائم آزاردهنده مانند درد، بو، خونریزی، و ترشح تمرکز دارد. ارتباط مستمر با تیم انکولوژی برای هماهنگی زمان‌بندی تعویض پانسمان با جلسات شیمی‌درمانی و پایش شمارش خونی ضروری است.</p>
<h2>جدیدترین رویکردها در درمان زخم‌های سرطانی</h2>
<h3>۱. پانسمان‌های هوشمند و نانوتکنولوژی</h3>
<p>پانسمان‌های نسل جدید با قابلیت‌های پیشرفته، انقلابی در مراقبت از زخم‌های سرطانی ایجاد کرده‌اند. پانسمان‌های حاوی نانوذرات نقره، خاصیت ضدباکتریایی قوی دارند و برای زخم‌های عفونی مناسب هستند. پانسمان‌های هیدروژلی با قابلیت آزادسازی تدریجی دارو، درد را کاهش می‌دهند. همچنین، پانسمان‌های حسگردار می‌توانند pH زخم، دما، و وجود عفونت را پایش کنند و اطلاعات را به تیم درمان ارسال نمایند.</p>
<h3>۲. درمان منفی فشار زخم (NPWT) در زخم‌های سرطانی</h3>
<p>استفاده از NPWT (مانند VAC Therapy) در زخم‌های پس از جراحی سرطان و زخم‌های باز وسیع، رشد بافت گرانوله را تسریع می‌کند و ترشح را به‌طور مؤثر مدیریت می‌نماید. این تکنیک با ایجاد فشار منفی متناوب، گردش خون را بهبود بخشیده و ادم بافتی را کاهش می‌دهد. با این حال، در زخم‌های Fungating و موارد با خونریزی فعال، باید با احتیاط فراوان استفاده شود.</p>
<h3>۳. رویکرد چندوجهی کنترل بو</h3>
<p>کنترل بوی نامطبوع در زخم‌های Fungating، یکی از مهم‌ترین جنبه‌های مراقبت است. رویکردهای نوین شامل ترکیب پانسمان‌های کربن فعال (برای جذب بو)، مترونیدازول موضعی (برای کشتن باکتری‌های بی‌هوازی)، شستشو با محلول‌های ضدعفونی‌کننده ملایم، و استفاده از خوشبوکننده‌های محیطی طبیعی است. برخی کلینیک‌ها از تکنیک‌های &#8220;aromatherapy&#8221; با روغن‌های ضروری مانند اسطوخودوس برای کاهش ادراک بوی نامطبوع استفاده می‌کنند.</p>
<h3>نکته مهم</h3>
<p>هرگز از پانسمان‌های چسبنده قوی در بیماران سرطانی با ترومبوسیتوپنی استفاده نکنید. تعویض این پانسمان‌ها می‌تواند منجر به خونریزی شدید و آسیب به بافت اطراف شود. همیشه از پانسمان‌های غیرچسبنده مانند سیلیکون یا پانسمان‌های روغنی استفاده کنید و در صورت نیاز، از تکنیک &#8220;soak off&#8221; (خیساندن پانسمان قبل از برداشتن) بهره ببرید.</p>
<h2>چک‌لیست انتخاب مرکز درمان زخم سرطانی مناسب</h2>
<p>✓<br></p>
<p>هماهنگی مستقیم با بخش انکولوژی</p>
<p>✓<br></p>
<p>تیم چندتخصصی شامل متخصص زخم، انکولوژیست، و متخصص درد</p>
<p>✓<br></p>
<p>دسترسی به پانسمان‌های پیشرفته (کربن فعال، آلژینات، فوم)</p>
<p>✓<br></p>
<p>امکان انجام HBOT برای زخم‌های رادیوتراپی</p>
<p>✓<br></p>
<p>پروتکل‌های مدیریت درد و خونریزی</p>
<p>✓<br></p>
<p>خدمات مراقبت روان‌شناختی و ارجاع به روان‌پزشکی</p>
<p>✓<br></p>
<p>آموزش خانواده برای مراقبت در منزل</p>
<p>✓<br></p>
<p>پشتیبانی ۲۴ ساعته برای موارد اورژانسی</p>
<p>✓<br></p>
<p>هماهنگی با بیمه برای پوشش هزینه‌ها</p>
<p>✓<br></p>
<p>رویکرد palliative care با تمرکز بر کیفیت زندگی</p>
<h2>اشتباهات رایج در مراقبت از زخم‌های سرطانی</h2>
<h3>اشتباهات در انتخاب و شروع درمان</h3>
<ul>
<li>مراجعه به مراکز غیرتخصصی بدون هماهنگی با تیم انکولوژی.</li>
<li>استفاده از پانسمان‌های چسبنده قوی در بیماران با ترومبوسیتوپنی.</li>
<li>نادیده‌گرفتن کنترل درد قبل از تعویض پانسمان.</li>
<li>انتظار بهبود کامل زخم در موارد Fungating پیشرفته.</li>
<li>عدم توجه به حمایت تغذیه‌ای و مکمل‌های ضروری.</li>
</ul>
<h3>اشتباهات در ادامه و نگهداری مراقبت</h3>
<ul>
<li>تعویض مکرر و غیرضروری پانسمان که به بافت آسیب می‌زند.</li>
<li>استفاده از محلول‌های ضدعفونی‌کننده قوی مانند بتادین در زخم‌های رادیوتراپی.</li>
<li>نادیده‌گرفتن علائم عفونت مانند تب، قرمزی پیش‌رونده، یا ترشح بدبو.</li>
<li>عدم آموزش کافی به خانواده برای مراقبت در منزل.</li>
<li>تمرکز صرف بر زخم و نادیده‌گرفتن جنبه‌های روانی و اجتماعی.</li>
<li>عدم هماهنگی زمان‌بندی تعویض پانسمان با جلسات شیمی‌درمانی.</li>
</ul>
<h3>مشاوره‌ی تخصصی زخم سرطانی</h3>
<p>
<a> ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/malignant-wound/';

UPDATE pages SET body = '<h2>درمان چربی خون و سندرم متابولیک در کلینیک غدد همراه تهران</h2>
<p>سندرم متابولیک مجموعه‌ای از عوامل خطر است که با هم، ریسک دیابت و بیماری قلبی-عروقی را چند برابر می‌کنند. چربی خون بالا نیز یکی از خاموش‌ترین اما مهم‌ترین عوامل سکته‌ی قلبی و مغزی است. <strong>کلینیک غدد همراه</strong> با ارزیابی جامع متابولیک و درمان مبتنی بر کاهش ریسک، از عوارض جدی قلبی پیشگیری می‌کند.</p>
<h2>سندرم متابولیک چیست؟</h2>
<p>سندرم متابولیک زمانی تشخیص داده می‌شود که فرد حداقل سه مورد از پنج عامل زیر را داشته باشد:</p>
<ul>
<li>دور کمر بالا (چاقی شکمی)</li>
<li>تری‌گلیسیرید بالا</li>
<li>کلسترول خوب (HDL) پایین</li>
<li>فشار خون بالا</li>
<li>قند خون ناشتای بالا</li>
</ul>
<h2>انواع اختلالات چربی خون</h2>
<ul>
<li>
<strong>کلسترول LDL بالا:</strong> «کلسترول بد» — عامل اصلی گرفتگی عروق</li>
<li>
<strong>تری‌گلیسیرید بالا:</strong> اغلب همراه با چاقی و دیابت</li>
<li>
<strong>کلسترول HDL پایین:</strong> «کلسترول خوب» محافظ قلب</li>
</ul>
<h2>چرا مهم است؟</h2>
<ul>
<li>افزایش خطر سکته‌ی قلبی و مغزی</li>
<li>افزایش خطر دیابت نوع ۲</li>
<li>کبد چرب</li>
<li>اغلب بدون علامت — تشخیص فقط با آزمایش</li>
</ul>
<h2>تشخیص در کلینیک همراه</h2>
<ul>
<li>پروفایل کامل چربی خون (کلسترول، LDL، HDL، تری‌گلیسیرید)</li>
<li>قند خون ناشتا و HbA1c</li>
<li>اندازه‌گیری دور کمر و فشار خون</li>
<li>بررسی کبد چرب و عملکرد کبد</li>
<li>ارزیابی ریسک قلبی-عروقی کلی</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>تغذیه‌ی تخصصی:</strong> رژیم کاهنده‌ی چربی و قند، کم‌نمک</li>
<li>
<strong>فعالیت بدنی منظم:</strong> ۱۵۰ دقیقه ورزش هوازی در هفته</li>
<li>
<strong>کاهش وزن:</strong> به‌ویژه کاهش چربی شکمی</li>
<li>
<strong>استاتین‌ها:</strong> برای کاهش کلسترول و ریسک قلبی</li>
<li>
<strong>فیبرات‌ها:</strong> در تری‌گلیسیرید بسیار بالا</li>
<li>
<strong>کنترل همزمان فشار خون و قند</strong>
</li>
</ul>
<h2>پزشکان بخش درمان چربی خون و سندرم متابولیک در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان چربی خون و سندرم متابولیک در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/metabolic-syndrome/';

UPDATE pages SET body = '<h2>درمان چاقی و کنترل وزن در کلینیک غدد همراه تهران</h2>
<p>چاقی صرفاً یک مسئله‌ی ظاهری نیست — یک بیماری مزمن متابولیک است که با دیابت، فشار خون، چربی خون، کبد چرب و بیماری‌های قلبی پیوند مستقیم دارد. گاهی نیز ریشه‌ی چاقی در یک اختلال هورمونی نهفته است. <strong>کلینیک غدد همراه</strong> با ارزیابی علل هورمونی و متابولیک چاقی و برنامه‌ی کاهش وزن علمی و پایدار، به شما کمک می‌کند به وزن سالم برسید.</p>
<h2>چه زمانی اضافه وزن بیماری محسوب می‌شود؟</h2>
<ul>
<li>
<strong>شاخص توده‌ی بدنی (BMI) ۲۵ تا ۳۰:</strong> اضافه وزن</li>
<li>
<strong>BMI بالای ۳۰:</strong> چاقی</li>
<li>
<strong>دور کمر بالا:</strong> بیش از ۱۰۲ سانتی‌متر در مردان و ۸۸ در زنان — نشانه‌ی چاقی شکمی پرخطر</li>
</ul>
<h2>علل چاقی</h2>
<ul>
<li>عدم تعادل بین کالری دریافتی و مصرفی</li>
<li>عوامل ژنتیکی و خانوادگی</li>
<li>علل هورمونی: کم‌کاری تیروئید، سندرم کوشینگ، تخمدان پلی‌کیستیک</li>
<li>مقاومت به انسولین</li>
<li>برخی داروها (کورتون، برخی داروهای روان‌پزشکی)</li>
<li>کم‌تحرکی و کم‌خوابی</li>
<li>استرس و پرخوری احساسی</li>
</ul>
<h2>عوارض چاقی</h2>
<ul>
<li>دیابت نوع ۲</li>
<li>فشار خون بالا</li>
<li>چربی خون و سندرم متابولیک</li>
<li>کبد چرب</li>
<li>آپنه‌ی خواب</li>
<li>آرتروز و درد مفاصل</li>
<li>بیماری‌های قلبی-عروقی</li>
<li>برخی سرطان‌ها</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>ارزیابی هورمونی:</strong> رد علل قابل‌درمان چاقی (تیروئید، کورتیزول، PCOS)</li>
<li>
<strong>مشاوره‌ی تغذیه‌ی تخصصی:</strong> رژیم غذایی فردی و پایدار، نه رژیم‌های افراطی</li>
<li>
<strong>برنامه‌ی فعالیت بدنی:</strong> متناسب با شرایط جسمانی</li>
<li>
<strong>دارودرمانی:</strong> داروهای کاهش وزن مانند آگونیست‌های GLP-1 در موارد دارای اندیکاسیون</li>
<li>
<strong>رفتاردرمانی:</strong> اصلاح عادات غذایی و مدیریت پرخوری احساسی</li>
<li>
<strong>ارجاع برای جراحی متابولیک:</strong> در چاقی شدید و مقاوم</li>
</ul>
<h2>پزشکان بخش درمان چاقی و کنترل وزن در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان چاقی و کنترل وزن در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/obesity/';

UPDATE pages SET body = '<h2>درمان پوکی استخوان در کلینیک غدد همراه تهران</h2>
<p>پوکی استخوان «بیماری خاموش» نامیده می‌شود، چون اغلب تا زمان شکستگی هیچ علامتی ندارد. در این بیماری تراکم و استحکام استخوان کاهش می‌یابد و خطر شکستگی — به‌ویژه در لگن، مهره‌ها و مچ دست — بالا می‌رود. <strong>کلینیک غدد همراه</strong> با سنجش تراکم استخوان (DEXA)، ارزیابی هورمونی و درمان دارویی، از شکستگی‌های ناتوان‌کننده پیشگیری می‌کند.</p>
<h2>پوکی استخوان چیست؟</h2>
<p>استخوان بافتی زنده است که دائماً بازسازی می‌شود. وقتی سرعت تخریب استخوان از بازسازی پیشی بگیرد، استخوان متخلخل و شکننده می‌شود. این روند به‌ویژه پس از یائسگی به دلیل کاهش استروژن تسریع می‌شود.</p>
<h2>عوامل خطر</h2>
<ul>
<li>یائسگی و کاهش استروژن</li>
<li>افزایش سن</li>
<li>جنسیت زن</li>
<li>کمبود کلسیم و ویتامین D</li>
<li>مصرف طولانی‌مدت کورتون</li>
<li>کم‌تحرکی</li>
<li>سیگار و الکل</li>
<li>سابقه‌ی خانوادگی</li>
<li>پرکاری تیروئید یا پاراتیروئید</li>
<li>لاغری بیش از حد</li>
</ul>
<h2>علائم</h2>
<ul>
<li>اغلب بدون علامت تا زمان شکستگی</li>
<li>کاهش قد به مرور زمان</li>
<li>قوز پشت</li>
<li>کمردرد ناشی از شکستگی مهره</li>
<li>شکستگی با ضربه‌ی خفیف</li>
</ul>
<h2>تشخیص در کلینیک همراه</h2>
<ul>
<li>
<strong>سنجش تراکم استخوان (DEXA / BMD):</strong> آزمایش طلایی تشخیص</li>
<li>
<strong>T-score:</strong> کمتر از ۲.۵- = پوکی استخوان؛ بین ۱- و ۲.۵- = استئوپنی (کاهش جزئی)</li>
<li>
<strong>آزمایش‌ها:</strong> کلسیم، ویتامین D، فسفر، هورمون پاراتیروئید (PTH) و تیروئید</li>
<li>
<strong>رد علل ثانویه:</strong> بررسی بیماری‌های هورمونی زمینه‌ای</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>کلسیم و ویتامین D:</strong> پایه‌ی درمان و پیشگیری</li>
<li>
<strong>بیس‌فسفونات‌ها:</strong> مانند آلندرونات — کاهش تخریب استخوان</li>
<li>
<strong>دنوزوماب:</strong> داروی تزریقی مؤثر در موارد پیشرفته</li>
<li>
<strong>درمان علل زمینه‌ای:</strong> تنظیم تیروئید، پاراتیروئید یا هورمون‌های جنسی</li>
<li>
<strong>ورزش مقاومتی و تعادلی:</strong> تقویت استخوان و پیشگیری از زمین خوردن</li>
<li>
<strong>اصلاح سبک زندگی:</strong> ترک سیگار، تغذیه‌ی غنی از کلسیم</li>
</ul>
<h2>پیشگیری</h2>
<ul>
<li>دریافت کافی کلسیم و ویتامین D</li>
<li>ورزش منظم به‌ویژه پیاده‌روی و تمرین با وزنه</li>
<li>قرار گرفتن در معرض نور آفتاب</li>
<li>ترک سیگار</li>
<li>سنجش تراکم استخوان در زنان پس از یائسگی</li>
</ul>
<h2>پزشکان بخش درمان پوکی استخوان در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان پوکی استخوان در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/osteoporosis/';

UPDATE pages SET body = '<h2>درمان سندرم تخمدان پلی‌کیستیک (PCOS) در کلینیک غدد همراه تهران</h2>
<p>سندرم تخمدان پلی‌کیستیک (PCOS) شایع‌ترین اختلال هورمونی در زنان سن باروری است و حدود یک از هر ده زن را درگیر می‌کند. این سندرم فراتر از یک مشکل قاعدگی است — با مقاومت به انسولین، چاقی، دیابت و ناباروری ارتباط دارد. <strong>کلینیک غدد همراه</strong> با رویکرد متابولیک و هورمونی، PCOS را به‌صورت ریشه‌ای مدیریت می‌کند.</p>
<h2>PCOS چیست؟</h2>
<p>در این سندرم، عدم تعادل هورمونی باعث اختلال در تخمک‌گذاری و افزایش هورمون‌های مردانه (آندروژن) می‌شود. این موضوع منجر به بی‌نظمی قاعدگی، علائم پوستی و گاهی ناباروری می‌گردد. مقاومت به انسولین نقش کلیدی در این بیماری دارد.</p>
<h2>علائم</h2>
<ul>
<li>قاعدگی نامنظم یا قطع قاعدگی</li>
<li>پرمویی صورت و بدن (هیرسوتیسم)</li>
<li>آکنه و چربی پوست</li>
<li>ریزش مو با الگوی مردانه</li>
<li>افزایش وزن و دشواری در کاهش آن</li>
<li>ناباروری و دشواری در بارداری</li>
<li>تیرگی پوست در چین‌های بدن (آکانتوزیس)</li>
</ul>
<h2>تشخیص (معیار روتردام)</h2>
<p>تشخیص با وجود حداقل دو مورد از سه معیار زیر گذاشته می‌شود:</p>
<ul>
<li>اختلال یا فقدان تخمک‌گذاری (قاعدگی نامنظم)</li>
<li>علائم بالینی یا آزمایشگاهی افزایش آندروژن</li>
<li>تخمدان پلی‌کیستیک در سونوگرافی</li>
</ul>
<p>آزمایش‌ها شامل LH، FSH، تستوسترون، پرولاکتین، قند و انسولین ناشتا و پروفایل چربی است. بررسی مقاومت به انسولین و رد سایر علل (تیروئید، آدرنال) نیز ضروری است.</p>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>کاهش وزن و تغذیه:</strong> حتی ۵ تا ۱۰٪ کاهش وزن می‌تواند قاعدگی و باروری را بهبود دهد</li>
<li>
<strong>متفورمین:</strong> برای بهبود مقاومت به انسولین</li>
<li>
<strong>قرص‌های ترکیبی (OCP):</strong> تنظیم قاعدگی و کاهش آندروژن</li>
<li>
<strong>داروهای ضدآندروژن:</strong> برای پرمویی و آکنه</li>
<li>
<strong>القای تخمک‌گذاری:</strong> با لتروزول یا کلومیفن برای زنانی که قصد بارداری دارند</li>
<li>
<strong>کنترل عوارض بلندمدت:</strong> پیشگیری از دیابت و بیماری قلبی</li>
</ul>
<h2>پزشکان بخش درمان سندرم تخمدان پلی‌کیستیک (PCOS) در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان سندرم تخمدان پلی‌کیستیک (PCOS) در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/pcos/';

UPDATE pages SET body = '<h2>درمان اختلالات غده هیپوفیز در کلینیک غدد همراه تهران</h2>
<p>غده‌ی هیپوفیز با اینکه به اندازه‌ی یک نخود است، «غده‌ی فرمانده» نام دارد؛ چون سایر غدد بدن (تیروئید، آدرنال، غدد جنسی) را کنترل می‌کند. اختلال در هیپوفیز می‌تواند آبشاری از مشکلات هورمونی ایجاد کند. <strong>کلینیک غدد همراه</strong> با ارزیابی دقیق هورمونی و هماهنگی برای تصویربرداری MRI، اختلالات هیپوفیز را تشخیص و مدیریت می‌کند.</p>
<h2>هیپوفیز چه می‌کند؟</h2>
<p>هیپوفیز هورمون‌هایی ترشح می‌کند که غدد دیگر را فرمان می‌دهند: TSH (تیروئید)، ACTH (آدرنال)، FSH و LH (غدد جنسی)، هورمون رشد (GH)، پرولاکتین و هورمون ضدادراری.</p>
<h2>انواع اختلالات هیپوفیز</h2>
<ul>
<li>
<strong>پرولاکتینوما:</strong> شایع‌ترین تومور خوش‌خیم هیپوفیز — ترشح شیر غیرطبیعی، بی‌نظمی قاعدگی و ناباروری</li>
<li>
<strong>آکرومگالی:</strong> هورمون رشد بیش از حد در بزرگسالان — بزرگ شدن دست، پا و اجزای صورت</li>
<li>
<strong>کم‌کاری هیپوفیز:</strong> کمبود یک یا چند هورمون هیپوفیز</li>
<li>
<strong>دیابت بی‌مزه:</strong> کمبود هورمون ضدادراری — تشنگی و ادرار فراوان (متفاوت از دیابت قند)</li>
<li>
<strong>آدنوم غیرفعال:</strong> توده‌ی هیپوفیز بدون ترشح هورمون اضافی</li>
</ul>
<h2>علائم هشدار</h2>
<ul>
<li>سردرد مداوم</li>
<li>اختلال میدان بینایی</li>
<li>ترشح شیر بدون بارداری</li>
<li>بی‌نظمی یا قطع قاعدگی</li>
<li>کاهش میل جنسی و ناباروری</li>
<li>تغییر اندازه‌ی دست، پا یا اجزای صورت</li>
<li>خستگی شدید بدون علت</li>
</ul>
<h2>تشخیص در کلینیک همراه</h2>
<ul>
<li>پنل کامل هورمونی هیپوفیز (پرولاکتین، IGF-1، کورتیزول، تیروئید، هورمون‌های جنسی)</li>
<li>تست‌های تحریکی و سرکوبی اختصاصی</li>
<li>MRI غده‌ی هیپوفیز (با هماهنگی)</li>
<li>بررسی میدان بینایی در صورت توده‌ی بزرگ</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>پرولاکتینوما:</strong> داروهای کابرگولین یا بروموکریپتین (معمولاً بدون نیاز به جراحی)</li>
<li>
<strong>آکرومگالی:</strong> دارو، و در موارد لازم ارجاع برای جراحی</li>
<li>
<strong>کم‌کاری هیپوفیز:</strong> جایگزینی هورمون‌های کمبود</li>
<li>
<strong>دیابت بی‌مزه:</strong> داروی دسموپرسین</li>
<li>
<strong>پایش منظم:</strong> کنترل سطح هورمون و اندازه‌ی توده</li>
</ul>
<h2>پزشکان بخش درمان اختلالات غده هیپوفیز در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان اختلالات غده هیپوفیز در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/pituitary/';

UPDATE pages SET body = '<h2>درمان زخم بستر (فشاری)</h2>
<p>زخم بستر یا زخم فشاری (Pressure Ulcer) آسیبی است که در پوست و بافت‌های زیرین آن به دلیل فشار طولانی‌مدت ایجاد می‌شود. این زخم‌ها معمولاً در بیماران سالمند، فلج، بیماران در کما، یا کسانی که برای مدت طولانی در یک وضعیت قرار دارند، رخ می‌دهد. <strong>کلینیک زخم همراه</strong> با تیم تخصصی و تجهیزات روز، درمان جامع زخم بستر را در محل کلینیک و در منزل ارائه می‌دهد.</p>
<h2>زخم بستر چیست؟</h2>
<p>زخم بستر زمانی ایجاد می‌شود که فشار مداوم روی یک نقطه از بدن، جریان خون به آن ناحیه را قطع کند. در نتیجه‌ی کمبود اکسیژن و مواد مغذی، بافت آن قسمت از بین می‌رود. شایع‌ترین محل‌های زخم بستر عبارت‌اند از: ساکروم (انتهای ستون فقرات)، پاشنه‌ی پا، باسن، شانه‌ها، آرنج و پشت سر.</p>
<h2>درجه‌بندی زخم بستر (NPUAP)</h2>
<ul>
<li>
<strong>مرحله ۱:</strong> قرمزی پایدار پوست بدون زخم باز</li>
<li>
<strong>مرحله ۲:</strong> آسیب جزئی پوست — تاول یا زخم سطحی</li>
<li>
<strong>مرحله ۳:</strong> آسیب کامل پوست تا چربی زیرپوستی</li>
<li>
<strong>مرحله ۴:</strong> آسیب گسترده تا عضله، تاندون یا استخوان</li>
<li>
<strong>غیرقابل‌مرحله‌بندی:</strong> پوشیده شده با بافت مرده — نیازمند دبریدمان</li>
<li>
<strong>آسیب عمقی مشکوک:</strong> پوست ارغوانی/تیره بدون شکستگی پوست</li>
</ul>
<h2>عوامل خطر</h2>
<ul>
<li>بستری طولانی‌مدت (بیش از ۲ ساعت در یک وضعیت)</li>
<li>سن بالای ۶۵ سال</li>
<li>سوءتغذیه و کمبود پروتئین</li>
<li>دیابت و بیماری‌های عروقی</li>
<li>اختلالات حسی (نوروپاتی، فلج، کما)</li>
<li>بی‌اختیاری ادرار/مدفوع — رطوبت بیش از حد پوست</li>
<li>اصطکاک و کشش پوست هنگام جابجایی</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>کاهش فشار:</strong> تشک ضد زخم بستر (Pressure Redistribution Mattress) و تغییر وضعیت هر ۲ ساعت</li>
<li>
<strong>دبریدمان تخصصی:</strong> پاک‌سازی بافت مرده با روش‌های جراحی، آنزیمی، اتولیتیک یا مکانیکی</li>
<li>
<strong>پانسمان‌های نوین:</strong> هیدروکلوئید، آلژینات، فوم، نقره — بسته به مرحله‌ی زخم</li>
<li>
<strong>وکیوم تراپی (NPWT):</strong> به‌خصوص برای زخم‌های مرحله ۳ و ۴</li>
<li>
<strong>کنترل عفونت:</strong> کشت زخم و آنتی‌بیوتیک هدفمند</li>
<li>
<strong>مشاوره تغذیه:</strong> افزایش پروتئین، ویتامین C، روی</li>
<li>
<strong>درمان درد:</strong> پروتکل تخصصی کنترل درد در حین تعویض پانسمان</li>
<li>
<strong>خدمات در منزل:</strong> برای بیماران غیرقابل انتقال، تیم ما به منزل اعزام می‌شود</li>
</ul>
<h2>پیشگیری از زخم بستر</h2>
<ul>
<li>تغییر وضعیت بیمار هر ۲ ساعت</li>
<li>استفاده از تشک هوای متناوب یا فوم پزشکی</li>
<li>حفظ خشکی و تمیزی پوست</li>
<li>تغذیه‌ی غنی از پروتئین و ویتامین</li>
<li>هیدراتاسیون کافی</li>
<li>ماساژ ملایم اطراف نواحی پرفشار (نه روی نقاط قرمز)</li>
<li>آموزش خانواده و پرستار خانگی</li>
</ul>' WHERE path = '/service/pressure-ulcer/';

UPDATE pages SET body = '<h2>درمان عفونت تنفسی</h2>
<p>عفونت‌های تنفسی از علل اصلی مراجعه به پزشک هستند. <strong>کلینیک عفونی همراه</strong> با ارزیابی دقیق، تصویربرداری مناسب و تشخیص افتراقی بین عفونت‌های ویروسی و باکتریایی، از تجویز بی‌مورد آنتی‌بیوتیک جلوگیری و درمان هدفمند را ارائه می‌دهد.</p>
<h2>انواع عفونت تنفسی</h2>
<ul>
<li>
<strong>سرماخوردگی و آنفلوآنزا:</strong> ویروسی — نیاز به آنتی‌بیوتیک ندارد</li>
<li>
<strong>برونشیت حاد:</strong> اکثراً ویروسی</li>
<li>
<strong>پنومونی اکتسابی جامعه (CAP):</strong> باکتریایی، نیاز به آنتی‌بیوتیک</li>
<li>
<strong>پنومونی بیمارستانی (HAP):</strong> با باکتری‌های مقاوم</li>
<li>
<strong>COVID-19:</strong> پیگیری، long COVID</li>
<li>
<strong>عفونت‌های تنفسی مزمن:</strong> در COPD، برونشکتازی</li>
</ul>
<h2>علائم هشدار</h2>
<ul>
<li>تب بالا (بیش از ۳۸.۵)</li>
<li>تنگی نفس فزاینده</li>
<li>درد قفسه سینه</li>
<li>خلط چرکی، خونی یا تیره</li>
<li>کاهش اشباع اکسیژن</li>
<li>گیجی (در سالمندان نشانه‌ی پنومونی)</li>
</ul>
<h2>تشخیص</h2>
<ul>
<li>معاینه‌ی فیزیکی و سمع ریه</li>
<li>رادیوگرافی قفسه سینه</li>
<li>CT اسکن در موارد پیچیده</li>
<li>PCR ویروسی (آنفلوآنزا، COVID، RSV)</li>
<li>کشت خلط و آنتی‌بیوگرام</li>
<li>پاکس آکسی‌متری</li>
</ul>
<h2>درمان</h2>
<ul>
<li>
<strong>ویروسی:</strong> داروی ضدویروس (تامیفلو در آنفلوآنزا، پاکس‌لووید در COVID)</li>
<li>
<strong>باکتریایی:</strong> آنتی‌بیوتیک هدفمند بر اساس کشت</li>
<li>
<strong>اکسیژن‌درمانی</strong> در صورت کاهش SpO2</li>
<li>
<strong>OPAT:</strong> برای پنومونی شدید سرپایی</li>
<li>
<strong>توان‌بخشی ریوی</strong> پس از COVID شدید</li>
</ul>
<h2>پیشگیری</h2>
<ul>
<li>واکسن آنفلوآنزای سالانه</li>
<li>واکسن پنوموکوک در بالای ۶۵ سال و گروه‌های پرخطر</li>
<li>واکسن COVID و بوستر</li>
<li>ترک سیگار</li>
<li>شست‌وشوی مرتب دست‌ها</li>
</ul>
<h3>ارزیابی عفونت تنفسی</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/respiratory-infection/';

UPDATE pages SET body = '<h2>اختلالات هورمون‌های جنسی و یائسگی در کلینیک غدد همراه تهران</h2>
<p>هورمون‌های جنسی فراتر از باروری، بر خلق‌وخو، انرژی، استخوان، عضله و سلامت قلب اثر می‌گذارند. کاهش یا عدم تعادل این هورمون‌ها — چه در یائسگی زنان و چه در افت تستوسترون مردان — می‌تواند کیفیت زندگی را به‌شدت کاهش دهد. <strong>کلینیک غدد همراه</strong> با ارزیابی دقیق هورمونی و هورمون‌درمانی اصولی و ایمن، به تعادل و کیفیت زندگی شما کمک می‌کند.</p>
<h2>یائسگی و دوران گذار</h2>
<p>یائسگی مرحله‌ای طبیعی است که با کاهش استروژن همراه می‌شود، اما علائم آن گاهی آزاردهنده‌اند و نیاز به مدیریت دارند:</p>
<ul>
<li>گرگرفتگی و تعریق شبانه</li>
<li>بی‌خوابی</li>
<li>نوسانات خلقی و تحریک‌پذیری</li>
<li>خشکی و کاهش میل جنسی</li>
<li>افزایش خطر پوکی استخوان</li>
</ul>
<h2>کم‌کاری غدد جنسی مردان (افت تستوسترون)</h2>
<ul>
<li>کاهش میل و عملکرد جنسی</li>
<li>خستگی و کاهش انرژی</li>
<li>کاهش توده‌ی عضلانی و افزایش چربی</li>
<li>افسردگی و کاهش تمرکز</li>
<li>کاهش تراکم استخوان</li>
</ul>
<h2>تشخیص در کلینیک همراه</h2>
<ul>
<li>اندازه‌گیری استرادیول، FSH و LH (در زنان)</li>
<li>اندازه‌گیری تستوسترون تام و آزاد (در مردان)</li>
<li>بررسی پرولاکتین و تیروئید</li>
<li>ارزیابی تراکم استخوان در صورت لزوم</li>
<li>بررسی ریسک قلبی-عروقی پیش از هورمون‌درمانی</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>هورمون‌درمانی یائسگی (HRT):</strong> برای کنترل علائم آزاردهنده، با ارزیابی دقیق سود و خطر</li>
<li>
<strong>درمان‌های غیرهورمونی:</strong> برای کنترل گرگرفتگی در مواردی که هورمون منع مصرف دارد</li>
<li>
<strong>تستوسترون‌درمانی:</strong> در مردان دارای کمبود تأیید‌شده، با پایش منظم</li>
<li>
<strong>محافظت از استخوان:</strong> کلسیم، ویتامین D و درمان پوکی استخوان</li>
<li>
<strong>اصلاح سبک زندگی:</strong> تغذیه، ورزش و مدیریت استرس</li>
</ul>
<h2>پزشکان بخش اختلالات هورمون‌های جنسی و یائسگی در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش اختلالات هورمون‌های جنسی و یائسگی در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/sex-hormones/';

UPDATE pages SET body = '<h2>درمان عفونت پوست و بافت نرم</h2>
<p>عفونت‌های پوست و بافت نرم (SSTI) از سلولیت ساده تا عفونت‌های تهدیدکننده‌ی جان مانند نکروتیزینگ فاسئیت متفاوت‌اند. <strong>کلینیک عفونی همراه</strong> با هم‌کاری <a href="/service/wound-clinic/">کلینیک زخم</a>، درمان جامع ارائه می‌دهد.</p>
<h2>انواع SSTI</h2>
<ul>
<li>
<strong>سلولیت:</strong> عفونت پوست و بافت زیرپوست — قرمزی، گرمی، تورم</li>
<li>
<strong>اریزیپلا:</strong> سلولیت سطحی با مرز مشخص</li>
<li>
<strong>آبسه:</strong> تجمع چرک — نیاز به تخلیه</li>
<li>
<strong>ایمپتیگو:</strong> عفونت سطحی پوست در کودکان</li>
<li>
<strong>فولیکولیت و فورونکل:</strong> عفونت فولیکول مو</li>
<li>
<strong>نکروتیزینگ فاسئیت:</strong> اورژانس جراحی</li>
</ul>
<h2>میکروب‌های شایع</h2>
<ul>
<li>Staphylococcus aureus (شامل MRSA)</li>
<li>Streptococcus pyogenes</li>
<li>در دیابتی‌ها: گرم منفی، بی‌هوازی</li>
<li>در آب: Aeromonas، Vibrio</li>
</ul>
<h2>علائم اورژانس</h2>
<ul>
<li>درد غیرمتناسب با ظاهر زخم</li>
<li>تب بالا و علائم سپسیس</li>
<li>بافت ارغوانی یا سیاه</li>
<li>کریپتاسیون (احساس هوا زیر پوست)</li>
<li>پیشرفت سریع طی ساعت‌ها</li>
</ul>
<h2>درمان</h2>
<ul>
<li>
<strong>سلولیت ساده:</strong> آنتی‌بیوتیک خوراکی ۵-۷ روز</li>
<li>
<strong>سلولیت پیچیده:</strong> آنتی‌بیوتیک وریدی، احتمال OPAT</li>
<li>
<strong>آبسه:</strong> تخلیه + آنتی‌بیوتیک</li>
<li>
<strong>MRSA:</strong> آنتی‌بیوتیک‌های خاص (وانکومایسین، لینزولید)</li>
<li>
<strong>نکروتیزینگ فاسئیت:</strong> دبریدمان جراحی فوری + آنتی‌بیوتیک ترکیبی</li>
</ul>
<h2>پیشگیری</h2>
<ul>
<li>کنترل دیابت</li>
<li>مراقبت از زخم‌های کوچک</li>
<li>کنترل اگزما و بیماری‌های پوستی</li>
<li>درمان به‌موقع عفونت‌های قارچی پا</li>
</ul>
<h3>ارزیابی فوری عفونت پوست</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/skin-infection/';

UPDATE pages SET body = '<h2>تشخیص و درمان عفونت‌های مقاربتی (STI)</h2>
<p>عفونت‌های مقاربتی (STI) قابل تشخیص و درمان هستند، اما به دلیل تابو فرهنگی، اغلب دیر تشخیص داده می‌شوند. <strong>کلینیک عفونی همراه</strong> با رعایت کامل محرمانگی و حریم خصوصی، خدمات تشخیص و درمان STIها را ارائه می‌دهد.</p>
<strong>🔒 تعهد محرمانگی:</strong> تمام تست‌ها و مشاوره‌ها در محیط کاملاً محرمانه انجام می‌شود. نتایج فقط به شخص بیمار ارائه می‌گردد.
<h2>STIهای شایع و درمانی</h2>
<ul>
<li>
<strong>کلامیدیا:</strong> اغلب بی‌علامت — درمان: آزیترومایسین تک‌دوز</li>
<li>
<strong>گنوره:</strong> ترشح، سوزش — درمان: سفتریاکسون تزریقی</li>
<li>
<strong>سفلیس:</strong> پنی‌سیلین تزریقی</li>
<li>
<strong>تریکوموناس:</strong> مترونیدازول</li>
<li>
<strong>هرپس (HSV):</strong> آسیکلوویر، والاسیکلوویر — کنترل عودها</li>
<li>
<strong>HPV:</strong> واکسن پیشگیری، درمان زگیل تناسلی</li>
<li>
<strong>HIV:</strong> داروهای ضدرتروویروسی (ARV)</li>
<li>
<strong>هپاتیت B:</strong> رجوع به صفحه‌ی هپاتیت</li>
</ul>
<h2>چه زمانی تست بدهیم؟</h2>
<ul>
<li>پس از رابطه‌ی محافظت‌نشده</li>
<li>هنگام تغییر شریک جنسی</li>
<li>پیش از ازدواج</li>
<li>در صورت علائم: ترشح، زخم، تورم</li>
<li>غربالگری دوره‌ای در گروه‌های پرخطر</li>
</ul>
<h2>تست‌های موجود</h2>
<ul>
<li>تست HIV (آنتی‌بادی + PCR)</li>
<li>VDRL / RPR برای سفلیس</li>
<li>PCR کلامیدیا و گنوره</li>
<li>سرولوژی هپاتیت B و C</li>
<li>پاپ اسمیر + HPV-DNA</li>
<li>کشت برای موارد خاص</li>
</ul>
<h2>PrEP و PEP برای HIV</h2>
<ul>
<li>
<strong>PrEP (پیشگیری پیش از تماس):</strong> داروی روزانه برای افراد پرخطر</li>
<li>
<strong>PEP (پیشگیری پس از تماس):</strong> در ۷۲ ساعت اول پس از مواجهه‌ی پرخطر</li>
</ul>
<h3>مشاوره و تست محرمانه</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/sti/';

UPDATE pages SET body = '<h2>درمان زخم بعد از جراحی</h2>
<p>زخم‌های بعد از جراحی که دیر التیام می‌یابند یا دچار باز شدن (Wound Dehiscence) شده‌اند، نیازمند مراقبت تخصصی هستند. <strong>کلینیک زخم همراه</strong> با پروتکل‌های استاندارد و تجهیزات پیشرفته، روند بهبود زخم‌های جراحی پیچیده را تسریع می‌بخشد.</p>
<h2>انواع مشکلات زخم بعد از جراحی</h2>
<ul>
<li>
<strong>Dehiscence:</strong> باز شدن لبه‌های زخم بخیه شده</li>
<li>
<strong>Surgical Site Infection (SSI):</strong> عفونت محل جراحی</li>
<li>
<strong>سروما/هماتوما:</strong> تجمع مایع یا خون زیر پوست</li>
<li>
<strong>Necrosis:</strong> مرگ بافت اطراف زخم</li>
<li>
<strong>Fistula:</strong> ارتباط غیرطبیعی بین زخم و ارگان داخلی</li>
<li>
<strong>اسکار پاتولوژیک:</strong> کلوئید یا هیپرتروفیک</li>
</ul>
<h2>عوامل خطر</h2>
<ul>
<li>دیابت کنترل‌نشده</li>
<li>چاقی</li>
<li>سیگار کشیدن</li>
<li>سوءتغذیه</li>
<li>مصرف کورتیکواستروئید یا داروهای سرکوب‌کننده‌ی ایمنی</li>
<li>عفونت قبل از جراحی</li>
<li>جراحی اورژانسی یا طولانی</li>
<li>سن بالا</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>ارزیابی دقیق زخم:</strong> عمق، وسعت، عفونت، پرفیوژن</li>
<li>
<strong>دبریدمان تخصصی:</strong> برداشتن بافت مرده و سکوسترها</li>
<li>
<strong>وکیوم تراپی (NPWT):</strong> یکی از مؤثرترین درمان‌ها برای زخم‌های جراحی پیچیده</li>
<li>
<strong>پانسمان نوین:</strong> با انتخاب دقیق بر اساس فاز زخم</li>
<li>
<strong>درمان عفونت:</strong> کشت زخم و آنتی‌بیوتیک هدفمند</li>
<li>
<strong>پیوند پوست یا فلپ:</strong> در زخم‌های وسیع، با ارجاع به متخصص جراحی پلاستیک</li>
<li>
<strong>درمان اسکار:</strong> لیزر، سیلیکون، تزریق</li>
<li>
<strong>مشاوره تغذیه:</strong> برای تأمین پروتئین، ویتامین A و C، روی</li>
</ul>
<h2>پیشگیری از مشکلات زخم جراحی</h2>
<ul>
<li>کنترل قند خون قبل و بعد از جراحی</li>
<li>ترک سیگار حداقل ۴ هفته قبل از جراحی</li>
<li>تغذیه‌ی مناسب در دوره‌ی پری‌اپراتیو</li>
<li>رعایت دستورات پزشک پس از ترخیص</li>
<li>پیشگیری از فشار و کشش روی محل جراحی</li>
<li>پانسمان به‌موقع و تمیز</li>
</ul>' WHERE path = '/service/surgical-wound/';

UPDATE pages SET body = '<h2>درمان بیماری‌های تیروئید در کلینیک غدد همراه تهران</h2>
<p>تیروئید غده‌ای پروانه‌ای‌شکل در جلوی گردن است که با ترشح هورمون، سرعت متابولیسم کل بدن را تنظیم می‌کند. اختلالات تیروئید بسیار شایع‌اند — به‌ویژه در زنان — و می‌توانند انرژی، وزن، خلق‌وخو و ضربان قلب را به‌هم بریزند. <strong>کلینیک غدد همراه</strong> با هورمون‌سنجی دقیق، سونوگرافی تیروئید و در صورت نیاز نمونه‌برداری (FNA) در محل، تشخیص و درمان کامل تیروئید را ارائه می‌دهد.</p>
<h2>هورمون‌های تیروئید چه می‌کنند؟</h2>
<p>تیروئید هورمون‌های T4 و T3 را تولید می‌کند که توسط هورمون TSH (از غده هیپوفیز) تنظیم می‌شوند. این هورمون‌ها بر ضربان قلب، دمای بدن، وزن، گوارش و حتی خلق‌وخو اثر می‌گذارند.</p>
<h2>انواع بیماری‌های تیروئید</h2>
<ul>
<li>
<strong>کم‌کاری تیروئید (هیپوتیروئیدی):</strong> تولید ناکافی هورمون — شایع‌ترین علت آن بیماری هاشیموتو است.</li>
<li>
<strong>پرکاری تیروئید (هیپرتیروئیدی):</strong> تولید بیش از حد هورمون — اغلب ناشی از بیماری گریوز.</li>
<li>
<strong>گواتر:</strong> بزرگ شدن غده‌ی تیروئید.</li>
<li>
<strong>گره (ندول) تیروئید:</strong> توده‌هایی در تیروئید که اغلب خوش‌خیم‌اند اما باید بررسی شوند.</li>
<li>
<strong>تیروئیدیت:</strong> التهاب تیروئید (مانند هاشیموتو و تیروئیدیت پس از زایمان).</li>
</ul>
<h2>علائم کم‌کاری تیروئید</h2>
<ul>
<li>خستگی و خواب‌آلودگی</li>
<li>افزایش وزن بی‌دلیل</li>
<li>سرمازدگی (حساسیت به سرما)</li>
<li>یبوست</li>
<li>خشکی پوست و ریزش مو</li>
<li>افسردگی و کندی ذهن</li>
<li>بی‌نظمی قاعدگی</li>
</ul>
<h2>علائم پرکاری تیروئید</h2>
<ul>
<li>کاهش وزن با وجود اشتهای زیاد</li>
<li>تپش قلب و ضربان نامنظم</li>
<li>تعریق و گرمازدگی</li>
<li>لرزش دست</li>
<li>اضطراب و بی‌قراری</li>
<li>بی‌خوابی</li>
<li>اسهال و افزایش دفعات اجابت مزاج</li>
</ul>
<h2>تشخیص در کلینیک همراه</h2>
<ul>
<li>
<strong>آزمایش هورمونی:</strong> TSH، T4 و T3 آزاد</li>
<li>
<strong>آنتی‌بادی‌ها:</strong> Anti-TPO و Anti-Tg برای هاشیموتو و گریوز</li>
<li>
<strong>سونوگرافی تیروئید:</strong> ارزیابی اندازه، بافت و گره‌ها — در محل کلینیک</li>
<li>
<strong>نمونه‌برداری (FNA):</strong> برای گره‌های مشکوک، با راهنمایی سونوگرافی</li>
<li>
<strong>اسکن تیروئید:</strong> در موارد منتخب پرکاری</li>
</ul>
<h2>روش‌های درمان</h2>
<ul>
<li>
<strong>کم‌کاری:</strong> هورمون جایگزین لووتیروکسین با تنظیم دقیق دوز و پایش منظم TSH</li>
<li>
<strong>پرکاری:</strong> داروهای ضدتیروئید (متی‌مازول)، ید رادیواکتیو یا جراحی در موارد خاص</li>
<li>
<strong>گره‌ها:</strong> پیگیری منظم با سونوگرافی، نمونه‌برداری در صورت لزوم</li>
<li>
<strong>پایش بلندمدت:</strong> تنظیم دوز دارو بر اساس آزمایش‌های دوره‌ای</li>
</ul>
<h2>پزشکان بخش درمان بیماری‌های تیروئید در کلینیک غدد همراه تهران همراه کلینیک</h2>
<p>تیم پزشکی بخش درمان بیماری‌های تیروئید در کلینیک غدد همراه تهران متشکل از پزشکان مجرب و فعال است که با رویکردی علمی و مسئولانه به درمان می‌پردازند.</p>
<h2>دکتر احمد مافی</h2>
<p>متخصص رادیوتراپی انکولوژی | دارای بورد تخصصی</p>
<p> دانشیار دانشگاه علوم پزشکی شهید بهشتی</p>
<p>نظام پزشکی: ۷۹۰۱۸</p>
<a href="/team/دکتر-احمد-مافی/">
مشاهده جزئیات
</a>
<h2>دکتر محبوبه خلیلی</h2>
<p>متخصص قلب و عروق از دانشگاه علوم پزشکی شهید بهشتی | دارای بورد تخصصی</p>
<p>فلوشیپ کاردیو آنکولوژی از انستیتو قلب و عروق شهید رجایی</p>
<p>نظام پزشکی: ۹۴۳۶۰</p>
<a href="/team/دکتر-محبوبه-خلیلی/">
مشاهده جزئیات
</a>
<h2>دکتر حسین اصغری پور</h2>
<p>متخصص بیماریهای داخلی
فوق تخصص خون و انکولوژی
عضو انجمن سرطان اروپا
</p>
<p>دارای بورد تخصصی و فوق تخصصی</p>
<p>عضو انجمن سرطان آمریکا</p>
<p>۱۰۳۸۲۴</p>
<a href="/team/دکتر-حسین-اصغری-پور/">
مشاهده جزئیات
</a>
<h2>دکتر بهناز بهزادی</h2>
<p>متخصص رادیوانکولوژی</p>
<p>بورد تخصصی رادیوتراپی انکولوژی از دانشگاه علوم پزشکی شهید بهشتی</p>
<p>دانش اموخته پزشکی عمومی از دانشگاه علوم پزشکی تهران | عضو انجمن رادیوتراپی و انکولوژی</p>
<a href="/team/دکتر-بهناز-بهزادی/">
مشاهده جزئیات
</a>
<h2>دکتر رضا مقبولی</h2>
<p>متخصص جراحی کلیه، مجاری ادراری و تناسلی (اورولوژی)</p>
<p>نظام پزشکی 189251</p>
<a href="/team/دکتر-رضا-مقبولی/">
مشاهده جزئیات
</a>
<h2>دکتر حسام دانش آموز</h2>
<p>فوق تخصص قلب کودکان</p>
<p>متخصص کودکان و اطفال</p>
<a href="/team/دکتر-حسام-دانش-آموز/">
مشاهده جزئیات
</a>' WHERE path = '/service/thyroid/';

UPDATE pages SET body = '<h2>درمان زخم ضربه‌ای (تروماتیک)</h2>
<p>زخم‌های ضربه‌ای (Traumatic Wounds) ناشی از تصادف، سقوط، بریدگی شدید یا حادثه هستند که می‌توانند سطحی یا عمیق، تمیز یا آلوده باشند. <strong>کلینیک زخم همراه</strong> پیگیری پس از درمان اولیه‌ی اورژانس، بخیه‌های پیچیده و زخم‌های ضربه‌ای دیربهبود را پوشش می‌دهد.</p>
<h2>انواع زخم ضربه‌ای</h2>
<ul>
<li>
<strong>Abrasion:</strong> سایش — معمولاً سطحی</li>
<li>
<strong>Laceration:</strong> پارگی — لبه‌های نامنظم</li>
<li>
<strong>Puncture:</strong> سوراخ — خطر عفونت عمقی</li>
<li>
<strong>Avulsion:</strong> کندگی — قطعه‌ای از بافت کنده شده</li>
<li>
<strong>Crush:</strong> له‌شدگی — آسیب عمیق بافت</li>
<li>
<strong>Bite Wound:</strong> ناشی از گاز سگ، گربه، انسان — خطر بالای عفونت</li>
</ul>
<h2>اقدامات اولیه پس از حادثه</h2>
<ol>
<li>کنترل خونریزی با فشار مستقیم</li>
<li>شست‌وشو با آب جاری تمیز</li>
<li>پانسمان تمیز</li>
<li>مراجعه به اورژانس برای ارزیابی و بخیه</li>
<li>تزریق واکسن کزاز در صورت نیاز</li>
<li>آنتی‌بیوتیک پروفیلاکتیک در زخم‌های آلوده یا گاز حیوانات</li>
</ol>
<h2>چه زمانی به کلینیک زخم مراجعه کنیم؟</h2>
<ul>
<li>زخم ضربه‌ای که بعد از بخیه دچار عفونت شده</li>
<li>زخمی که بیش از ۲ هفته بهبود نیافته</li>
<li>زخمی با ترشح غیرعادی</li>
<li>درد فزاینده پس از بخیه</li>
<li>اسکار غیرطبیعی</li>
<li>زخم‌های وسیع که نیاز به پانسمان تخصصی دارند</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>ارزیابی دقیق:</strong> عمق، آلودگی، آسیب به ساختارهای زیرین</li>
<li>
<strong>دبریدمان:</strong> پاک‌سازی بافت مرده و اجسام خارجی</li>
<li>
<strong>بخیه‌ی ثانویه یا تأخیری:</strong> در زخم‌های آلوده پس از پاک‌سازی</li>
<li>
<strong>پانسمان نوین:</strong> هیدروژل برای زخم خشک، آلژینات برای ترشح‌دار</li>
<li>
<strong>NPWT:</strong> در زخم‌های وسیع</li>
<li>
<strong>پیشگیری از عفونت:</strong> آنتی‌بیوتیک، پانسمان آنتی‌میکروبیال</li>
<li>
<strong>کنترل اسکار:</strong> سیلیکون، فشار، لیزر در صورت نیاز</li>
<li>
<strong>توان‌بخشی:</strong> در زخم‌های مفصلی یا تاندونی</li>
</ul>' WHERE path = '/service/traumatic-wound/';

UPDATE pages SET body = '<h2>تشخیص و درمان سل (TB)</h2>
<p>سل (Tuberculosis) یکی از کشنده‌ترین عفونت‌های جهان است که هنوز سالانه میلیون‌ها نفر را در سراسر دنیا مبتلا می‌کند. <strong>کلینیک عفونی همراه</strong> با دسترسی به Gene-Xpert (تشخیص سریع در ۲ ساعت) و پروتکل‌های استاندارد WHO، درمان جامع سل را ارائه می‌دهد.</p>
<h2>انواع سل</h2>
<ul>
<li>
<strong>سل نهفته (LTBI):</strong> آلودگی بدون علامت — قابل سرایت نیست</li>
<li>
<strong>سل فعال ریوی:</strong> شایع‌ترین — سرفه طولانی، خلط خونی</li>
<li>
<strong>سل خارج‌ریوی:</strong> غدد لنفاوی، استخوان، مننژ، کلیه</li>
<li>
<strong>سل مقاوم (MDR/XDR):</strong> مقاومت به داروهای خط اول</li>
</ul>
<h2>علائم</h2>
<ul>
<li>سرفه‌ی بیش از ۳ هفته</li>
<li>خلط خونی (همپتیزی)</li>
<li>تب شبانه و تعریق شبانه</li>
<li>کاهش وزن غیرارادی</li>
<li>خستگی مفرط</li>
<li>درد قفسه سینه</li>
</ul>
<h2>تشخیص</h2>
<ul>
<li>
<strong>تست پوستی سل (TST/PPD)</strong>
</li>
<li>
<strong>IGRA (تست خون):</strong> دقیق‌تر از PPD</li>
<li>
<strong>اسمیر خلط (BK)</strong>
</li>
<li>
<strong>Gene-Xpert MTB/RIF:</strong> تشخیص ۲ ساعته + مقاومت به ریفامپین</li>
<li>
<strong>کشت خلط:</strong> Gold Standard</li>
<li>
<strong>رادیوگرافی قفسه سینه</strong>
</li>
<li>
<strong>CT اسکن در موارد خاص</strong>
</li>
</ul>
<h2>درمان</h2>
<ul>
<li>
<strong>سل نهفته:</strong> ۹ ماه ایزونیازید یا ۴ ماه ریفامپین</li>
<li>
<strong>سل فعال (پروتکل RIPE):</strong> ۲ ماه HRZE + ۴ ماه HR (مجموع ۶ ماه)</li>
<li>
<strong>سل مقاوم:</strong> ۹-۲۰ ماه با داروهای خط دوم</li>
<li>
<strong>DOTS:</strong> پایش مستقیم مصرف دارو</li>
</ul>
<h2>هشدارهای مهم</h2>
<ul>
<li>هرگز درمان نیمه‌کاره رها نشود — منجر به مقاومت می‌شود</li>
<li>تماس‌های خانگی غربالگری شوند</li>
<li>پایش ماهانه آنزیم‌های کبد</li>
<li>گزارش به سیستم بهداشت کشور (الزامی)</li>
</ul>
<h3>تشخیص سریع سل با Gene-Xpert</h3>
<p>
<a>☎ ۰۲۱-۹۱۳۰۳۱۳۲</a>
</p>' WHERE path = '/service/tuberculosis/';

UPDATE pages SET body = '<h2>درمان عفونت ادراری (UTI)</h2>
<p>عفونت ادراری (UTI) شایع‌ترین عفونت باکتریایی در جامعه است و حدود ۵۰٪ زنان حداقل یک‌بار در طول عمرشان به آن مبتلا می‌شوند. <strong>کلینیک عفونی همراه</strong> با تشخیص دقیق آزمایشگاهی، کشت ادرار و آنتی‌بیوگرام، درمان هدفمند را برای انواع UTI ساده و عودکننده ارائه می‌دهد.</p>
<h2>انواع عفونت ادراری</h2>
<ul>
<li>
<strong>سیستیت ساده:</strong> عفونت مثانه — درد سوزش هنگام ادرار</li>
<li>
<strong>پیلونفریت:</strong> عفونت کلیه — تب، درد پهلو، تهوع</li>
<li>
<strong>عفونت ادراری عودکننده:</strong> بیش از ۲ بار در ۶ ماه</li>
<li>
<strong>UTI پیچیده:</strong> در مردان، حاملگی، سنگ، کاتتر</li>
<li>
<strong>باکتریوری بدون علامت:</strong> فقط در حاملگی و قبل از جراحی ادراری درمان می‌شود</li>
</ul>
<h2>علائم شایع</h2>
<ul>
<li>سوزش هنگام ادرار (Dysuria)</li>
<li>تکرر ادرار</li>
<li>احساس فوریت ادرار</li>
<li>درد ناحیه‌ی زیر شکم</li>
<li>ادرار کدر یا بدبو</li>
<li>وجود خون در ادرار</li>
<li>تب و درد پهلو (در صورت درگیری کلیه)</li>
</ul>
<h2>تشخیص</h2>
<ul>
<li>آنالیز ادرار (Urinalysis)</li>
<li>کشت ادرار + آنتی‌بیوگرام (Gold Standard)</li>
<li>سونوگرافی کلیه و مثانه در موارد عودکننده</li>
<li>سیستوسکوپی در موارد خاص</li>
</ul>
<h2>درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>آنتی‌بیوتیک هدفمند:</strong> بر اساس کشت و حساسیت — نه آنتی‌بیوتیک کور</li>
<li>
<strong>UTI ساده:</strong> ۳-۵ روز آنتی‌بیوتیک خوراکی</li>
<li>
<strong>پیلونفریت:</strong> ۷-۱۴ روز، ممکن است نیاز به آنتی‌بیوتیک تزریقی (OPAT)</li>
<li>
<strong>UTI عودکننده:</strong> پروفیلاکسی طولانی‌مدت یا پساتماسی</li>
<li>
<strong>درمان علت زمینه‌ای:</strong> سنگ، رفلاکس، تخلیه‌ی ناقص مثانه</li>
</ul>
<h2>پیشگیری</h2>
<ul>
<li>نوشیدن آب کافی (۲ لیتر در روز)</li>
<li>ادرار پس از فعالیت جنسی</li>
<li>تخلیه‌ی کامل مثانه</li>
<li>رعایت بهداشت صحیح</li>
<li>کرنبری (شواهد محدود ولی بی‌ضرر)</li>
</ul>' WHERE path = '/service/urinary-tract-infection/';

UPDATE pages SET body = '<h2>مرکز تخصصی اورولوژی و جراحی کلیه و مجاری ادراری</h2>
<p>بخش اورولوژی کلینیک همراه، مرجعی تخصصی برای تشخیص و درمان بیماری‌های دستگاه ادراری (کلیه، حالب، مثانه و مجرا) در زنان و مردان، و همچنین بیماری‌های دستگاه تناسلی مردان است. این بخش با بهره‌گیری از <strong>متخصصین جراحی کلیه و مجاری ادراری (اورولوژیست)</strong>، تجهیزات تشخیصی پیشرفته و روش‌های درمانی کم‌تهاجمی (لیزر و آندوسکوپی)، خدماتی جامع را در محیطی کاملاً خصوصی و محرمانه ارائه می‌دهد.</p>
<p>ما در کلینیک همراه معتقدیم که مسائل اورولوژی، به‌ویژه موارد مرتبط با سلامت جنسی و باروری، نیازمند فضایی امن و بدون قضاوت هستند. رویکرد ما ترکیبی از دانش روز پزشکی، تکنولوژی‌های نوین سنگ‌شکنی و احترام کامل به حریم خصوصی بیمار است.</p>
<h2>ساختار بالینی و همکاری بین‌رشته‌ای</h2>
<p>بخش اورولوژی کلینیک همراه به صورت جزیره‌ای عمل نمی‌کند. بسیاری از بیماری‌های ادراری ریشه در مشکلات یا سرطان‌ها دارند. بنابراین، تیم اورولوژی ما در ارتباط مستقیم با سایر بخش‌های فوق تخصصی است:</p>
<ul>
<li>
<strong>همکاری با بخش انکولوژی:</strong> برای غربالگری، تشخیص و درمان سرطان‌های پروستات، بیضه، کلیه و مثانه.</li>
<li>
<strong>همکاری با بخش غدد:</strong> برای بررسی علل هورمونی ناباروری مردان، اختلال نعوظ و اختلالات بلوغ.</li>
<li>
<strong>همکاری با بخش عفونی:</strong> برای درمان عفونت‌های مقاوم ادراری، پروستاتیت‌های مزمن و ضایعات ویروسی (HPV).</li>
</ul>
<h2>طیف خدمات تخصصی اورولوژی</h2>
<p>🪨</p>
<h3>سنگ کلیه و مجاری ادراری</h3>
<p>تشخیص دقیق، درمان دارویی و ارجاع فوری به مراکز مجهز برای سنگ‌شکنی (ESWL) ، لیزر (TUL) ، PCNL و RIRS با هماهنگی کامل.</p>
<p>🚹</p>
<h3>بیماری‌های پروستات</h3>
<p>درمان بزرگی خوش‌خیم پروستات (BPH)، پروستاتیت و غربالگری سرطان پروستات با آزمایش PSA و در صورت نیاز انجام بیوپسی پروستات.</p>
<p>🎯</p>
<h3>نمونه‌برداری پروستات (بیوپسی)</h3>
<p>انجام بیوپسی دقیق پروستات تحت هدایت سونوگرافی ( TRUS-Bx) برای تشخیص قطعی و زودهنگام بدخیمی‌ها.</p>
<p>❄️</p>
<h3>درمان HPV با کرایوتراپی</h3>
<p>فریز کردن و حذف ضایعات زگیل تناسلی با نیتروژن مایع؛ روشی سریع، کم‌درد و با احتمال عود پایین.</p>
<p>💙</p>
<h3>سلامت جنسی مردان</h3>
<p>درمان اختلال نعوظ (ED)، زودانزالی و انزال دردناک در محیطی کاملاً محرمانه و تخصصی.</p>
<p>🧬</p>
<h3>ناباروری مردان</h3>
<p>بررسی اسپرموگرام، درمان واریکوسل و اختلالات هورمونی منجر به ناباروری با همکاری بخش غدد.</p>
<p>🦠</p>
<h3>عفونت‌های ادراری</h3>
<p>درمان عفونت‌های مکرر کلیه و مثانه، سوزش ادرار و هماتوری (خون در ادرار).</p>
<p>💧</p>
<h3>بی‌اختیاری ادرار</h3>
<p>درمان نشت ادرار در زنان و مردان با روش‌های دارویی، فیزیوتراپی کف لگن و جراحی‌های اسلینگ به علت افتادگی رحم یا مثانه و تعبیه پروتز آلت و کاشت اسفنکتر مصنوعی.</p>
<p>💉</p>
<h3>زیبایی مردان</h3>
<p>افزایش اعتماد به نفس و بهبود ظاهری با تزریق فیلر آلت جهت افزایش حجم و تزریق بوتاکس آلت برای درمان انزال زودرس، با استفاده از جدیدترین تکنیک‌ها و مواد معتبر جهانی.</p>
<p>🌸</p>
<h3>زیبایی زنان</h3>
<p>جراحی‌های زیبایی و ترمیمی شامل لابیاپلاستی برای اصلاح فرم و اندازه لابیا و پرینورافی جهت ترمیم و بازسازی ناحیه پرینه، با ظرافت بالا و دوران نقاهت کوتاه.</p>
<p>👶</p>
<h3>اورولوژی اطفال</h3>
<p>ارائه خدمات تخصصی شامل انجام انواع عمل‌های جراحی اطفال، درمان شب‌ادراری، ختنه با روش‌های نوین و کم‌خطر و درمان رفلاکس ادراری کودکان در محیطی آرام و تخصصی.</p>
<h2>مقایسه روش‌های درمان سنگ کلیه</h2>
<table>
<thead>
<tr>
<th>روش درمان</th>
<th>اندازه سنگ مناسب</th>
<th>نیاز به بستری</th>
<th>دوره نقاهت</th>
</tr>
</thead>
<tbody>
<tr>
<td>دارودرمانی (دفع خودبه‌خودی)</td>
<td>زیر ۵ میلی‌متر</td>
<td>خیر</td>
<td>24 تا 48 ساعت</td>
</tr>
<tr>
<td>سنگ‌شکنی برون‌اندامی (ESWL)</td>
<td>۵ تا ۲۰ میلی‌متر</td>
<td>خیر (سرپایی)</td>
<td>۱ تا ۳ روز</td>
</tr>
<tr>
<td>سنگ‌شکنی لیزری (TUL/RIRS)</td>
<td>سنگ‌های حالب و کلیه</td>
<td>کوتاه (۲۴ ساعت)</td>
<td>24 تا 48 ساعت</td>
</tr>
</tbody>
</table>
<h3>توصیه تخصصی</h3>
<p>وجود خون در ادرار (حتی اگر فقط یک بار اتفاق بیفتد و درد نداشته باشد) هرگز نباید نادیده گرفته شود. این علامت می‌تواند نشانه‌ای از سنگ، عفونت یا در موارد نادر، تومورهای دستگاه ادراری باشد. مراجعه سریع به متخصص اورولوژی برای انجام سونوگرافی و آزمایش ادرار حیاتی است.</p>
<h2>جدیدترین تکنولوژی‌های درمانی در کلینیک</h2>
<h3>۱. لیزر هولمیوم (Holmium Laser)</h3>
<p>استفاده از لیزرهای پرقدرت برای خرد کردن سنگ‌های سخت حالب و کلیه از طریق مجرای طبیعی ادرار، بدون هیچ‌گونه برش روی پوست. این روش استاندارد طلایی درمان سنگ‌های حالب است.</p>
<h3>۲. نمونه‌برداری هدفمند پروستات (TRUS-Biopsy)</h3>
<p>استفاده از پروب‌های سونوگرافی پیشرفته برای برداشتن نمونه‌های دقیق از بافت پروستات. این روش با کمترین عوارض و درد، تشخیص قطعی سرطان پروستات را ممکن می‌سازد.</p>
<h3>۳. کرایوتراپی ضایعات HPV</h3>
<p>استفاده از سرمای شدید نیتروژن مایع برای انجماد و از بین بردن زگیل‌های تناسلی. این روش سرپایی بوده و نسبت به لیزر یا الکتروکوتر، دوره نقاهت کوتاه‌تر و جای زخم کمتری دارد.</p>
<h3>۴. جراحی‌های endourology</h3>
<p>انجام جراحی‌های پروستات و تومورهای مثانه از طریق مجرای ادرار (TURP/TURBT) که باعث کاهش شدید خونریزی، درد کمتر و ترخیص سریع‌تر بیمار می‌شود.</p>
<h3>نکته مهم</h3>
<p>مصرف خودسرانه آنتی‌بیوتیک‌ها برای عفونت ادراری می‌تواند منجر به مقاومت میکروبی شود. همیشه قبل از مصرف دارو، کشت ادرار انجام دهید و تحت نظر پزشک متخصص درمان شوید.</p>
<h2>چک‌لیست انتخاب مرکز اورولوژی مناسب</h2>
<p>✓<br></p>
<p>داشتن متخصص جراحی کلیه و مجاری ادراری (اورولوژیست) با بورد تخصصی</p>
<p>✓<br></p>
<p>مجهز بودن به دستگاه‌های سنگ‌شکن، لیزر و تجهیزات کرایوتراپی</p>
<p>✓<br></p>
<p>امکان انجام سونوگرافی کلیه، پروستات و بیوپسی در همان کلینیک</p>
<p>✓<br></p>
<p>رعایت کامل اصول استریلیزاسیون و حریم خصوصی بیمار</p>
<p>✓<br></p>
<p>همکاری با بیمه‌های پایه و تکمیلی برای کاهش هزینه‌های درمان</p>
<p>✓<br></p>
<p>برخورد محترمانه و ایجاد حس آرامش برای بیمارانی که مشکلات حساس دارند</p>' WHERE path = '/service/urology-clinic/';

UPDATE pages SET body = '<h2>درمان زخم وریدی</h2>
<p>زخم وریدی شایع‌ترین نوع زخم مزمن پای انسان است و در ۸۰٪ موارد زخم‌های مزمن ساق پا را شامل می‌شود. این زخم‌ها معمولاً در نتیجه‌ی نارسایی مزمن وریدی (CVI) و واریس درمان‌نشده ایجاد می‌شوند. <strong>کلینیک زخم همراه</strong> با همکاری تیم متخصصان عروق، درمان جامع زخم وریدی شامل درمان فشاری، ابلیشن و درمان موضعی را ارائه می‌دهد.</p>
<h2>زخم وریدی چیست؟</h2>
<p>زمانی که دریچه‌های وریدی در پاها به‌خوبی کار نکنند، خون در وریدها جمع می‌شود (Venous Hypertension). فشار طولانی‌مدت باعث نشت مایع، التهاب پوست، تغییر رنگ، اگزما و در نهایت زخم می‌شود. این زخم‌ها معمولاً در ناحیه‌ی قوزک داخلی پا (Gaiter Area) ظاهر می‌شوند.</p>
<h2>علائم مشخصه</h2>
<ul>
<li>زخم در ناحیه‌ی قوزک داخلی، با لبه‌های نامنظم</li>
<li>پوست اطراف زخم قهوه‌ای، قرمز یا بنفش (Hemosiderin Staining)</li>
<li>تورم پای متأثر، به‌خصوص در پایان روز</li>
<li>درد متوسط که با بالا بردن پا کاهش می‌یابد</li>
<li>واریس قابل مشاهده در همان پا</li>
<li>اگزمای وریدی (پوسته‌پوسته شدن، خارش)</li>
<li>ترشح زرد یا چرکی از زخم</li>
</ul>
<h2>تشخیص</h2>
<ul>
<li>معاینه‌ی فیزیکی توسط متخصص عروق</li>
<li>سونوگرافی داپلر وریدی (تشخیص دقیق نقطه‌ی نارسایی)</li>
<li>ABI (Ankle-Brachial Index) برای رد بیماری شریانی همراه</li>
<li>تست‌های آزمایشگاهی پایه</li>
</ul>
<h2>روش‌های درمان در کلینیک همراه</h2>
<ul>
<li>
<strong>درمان فشاری (Compression Therapy):</strong> رکن اصلی درمان — بانداژ چندلایه (4-Layer Bandage) یا جوراب واریس درجه ۲ و ۳</li>
<li>
<strong>دبریدمان:</strong> پاک‌سازی بافت مرده</li>
<li>
<strong>پانسمان‌های جذبی:</strong> آلژینات یا فوم برای زخم‌های ترشح‌دار</li>
<li>
<strong>درمان نارسایی وریدی:</strong> ابلیشن لیزری اندوونوس (EVLA)، اسکلروتراپی، استریپینگ — با همکاری متخصص عروق</li>
<li>
<strong>وکیوم تراپی (NPWT):</strong> برای زخم‌های وسیع و مقاوم</li>
<li>
<strong>پیوند پوست:</strong> در زخم‌های بسیار وسیع</li>
<li>
<strong>درمان عفونت:</strong> در صورت وجود سلولیت یا عفونت ثانویه</li>
</ul>
<h2>نقش درمان فشاری</h2>
<p>درمان فشاری مهم‌ترین رکن درمان زخم وریدی است. بدون درمان فشاری مناسب، هیچ زخم وریدی به‌طور پایدار بهبود نمی‌یابد. در کلینیک همراه، نوع و درجه‌ی فشار به‌طور دقیق و فردی برای هر بیمار تعیین می‌شود.</p>
<h2>پیشگیری</h2>
<ul>
<li>درمان به‌موقع واریس پا</li>
<li>استفاده از جوراب واریس مناسب در ساعات طولانی ایستادن</li>
<li>ورزش منظم (پیاده‌روی، شنا)</li>
<li>کاهش وزن در افراد چاق</li>
<li>بالا گذاشتن پاها در زمان استراحت</li>
<li>اجتناب از ایستادن یا نشستن طولانی‌مدت</li>
</ul>' WHERE path = '/service/venous-ulcer/';

UPDATE pages SET body = '<h2>درمان هپاتیت ویروسی (B و C)</h2>
<p>هپاتیت‌های ویروسی B و C از مهم‌ترین عفونت‌های مزمن کبد هستند که در صورت عدم درمان به سیروز، نارسایی کبد و سرطان کبد منجر می‌شوند. <strong>کلینیک عفونی همراه</strong> با دسترسی به جدیدترین داروهای DAA، <strong>شفای کامل هپاتیت C</strong> در بیش از ۹۵٪ موارد را ممکن می‌سازد.</p>
<h2>هپاتیت B (HBV)</h2>
<ul>
<li>
<strong>راه انتقال:</strong> خون، تماس جنسی، مادر به فرزند</li>
<li>
<strong>تشخیص:</strong> HBsAg، HBeAg، HBV-DNA</li>
<li>
<strong>درمان:</strong> آنالوگ‌های نوکلئوزیدی (تنوفویر، انتکاویر) — کنترل بلندمدت، نه شفای کامل</li>
<li>
<strong>پیگیری:</strong> فیبروسکن، آنزیم‌های کبدی، AFP هر ۶ ماه</li>
<li>
<strong>پیشگیری:</strong> واکسن ۳ دوزه</li>
</ul>
<h2>هپاتیت C (HCV)</h2>
<ul>
<li>
<strong>راه انتقال:</strong> خون آلوده (تزریق، خالکوبی، اشتراک سرنگ)</li>
<li>
<strong>تشخیص:</strong> Anti-HCV + HCV-RNA</li>
<li>
<strong>درمان انقلابی:</strong> داروهای DAA (سوفوسبوویر/داکلاتاسویر) — <strong>۸-۱۲ هفته، شفای کامل ۹۵٪+</strong>
</li>
<li>
<strong>تأیید شفا:</strong> SVR (HCV-RNA منفی پس از ۱۲ هفته)</li>
<li>
<strong>واکسن:</strong> هنوز موجود نیست</li>
</ul>
<h2>چه کسانی باید تست شوند؟</h2>
<ul>
<li>سابقه‌ی تزریق دارو</li>
<li>سابقه‌ی خالکوبی، پیرسینگ</li>
<li>سابقه‌ی همودیالیز</li>
<li>سابقه‌ی دریافت خون قبل از ۱۳۷۵</li>
<li>تماس جنسی پرخطر</li>
<li>HIV مثبت</li>
<li>فرزند مادر HBV مثبت</li>
</ul>
<h2>روند درمان در کلینیک همراه</h2>
<ol>
<li>تشخیص با سرولوژی و PCR</li>
<li>ارزیابی شدت بیماری (فیبروسکن، آزمایش‌های کبد)</li>
<li>انتخاب رژیم دارویی متناسب</li>
<li>پایش ماهانه‌ی پاسخ درمانی</li>
<li>تأیید شفا (در HCV) یا کنترل بلندمدت (HBV)</li>
</ol>' WHERE path = '/service/viral-hepatitis/';

UPDATE pages SET body = '<h2>مرکز تخصصی درمان زخم‌های مزمن و دیابتی</h2>
<p>کلینیک زخم همراه، مرجعی تخصصی برای تشخیص و درمان انواع زخم‌های پیچیده (دیابتی، بستر، وریدی، شریانی و سوختگی) است. این مرکز با بهره‌گیری از <strong>تیم چندتخصصی (MDT)</strong> متشکل از جراحان عروق، متخصصان عفونی و پرستاران زخم، و استفاده از تکنولوژی‌های نوین مانند وکیوم تراپی (NPWT) و اکسیژن درمانی (HBOT)، بالاترین نرخ بهبودی را در محیطی کاملاً حرفه‌ای ارائه می‌دهد.</p>
<p>ما در کلینیک زخم همراه معتقدیم که &#8220;زخم یک بیماری نیست، بلکه علامت یک مشکل زمینه‌ای است&#8221;. رویکرد ما تنها پانسمان کردن نیست؛ بلکه ریشه‌یابی علت زخم (قند خون، گردش خون یا تغذیه) و درمان همزمان آن برای جلوگیری از عود مجدد است.</p>
<h2>چرا کلینیک زخم همراه؟</h2>
<p>🩺</p>
<h3>تیم چندتخصصی</h3>
<p>همکاری جراحان عروق، غدد و تغذیه</p>
<p>⚙️</p>
<h3>تجهیزات مدرن</h3>
<p>وکیوم تراپی (NPWT) و لیزر پزشکی</p>
<p>🏠</p>
<h3>خدمات در منزل</h3>
<p>ویزیت و پانسمان بیماران بدحال</p>
<h2>طیف خدمات و انواع زخم‌های تحت پوشش</h2>
<p>🦶</p>
<h3>زخم پای دیابتی</h3>
<p>پیشگیری از قطع عضو با مدیریت قند خون، آفلودینگ (کفش مخصوص) و دبریدمان دقیق بافت‌های مرده.</p>
<p>🛌</p>
<h3>زخم بستر (فشاری)</h3>
<p>درمان زخم‌های ناشی از بی‌حرکتی در نواحی ساکرال و پاشنه با استفاده از تشک‌های بادی و پانسمان‌های هوشمند.</p>
<p>🩸</p>
<h3>زخم‌های عروقی</h3>
<p>درمان تخصصی زخم‌های وریدی (واریسی) و شریانی با همکاری متخصصین عروق و استفاده از جوراب‌های فشاری.</p>
<p>🔥</p>
<h3>سوختگی و تروما</h3>
<p>مدیریت سوختگی‌های درجه ۲ و ۳ و زخم‌های تصادفی با هدف کاهش اسکار (جای زخم) و بازسازی پوست.</p>
<p>🧬</p>
<h3>زخم‌های سرطانی</h3>
<p>مراقبت‌های تسکینی و درمان زخم‌های ناشی از تومور یا عوارض پرتودرمانی با رویکرد انکولوژی حمایتی.</p>
<p>💉</p>
<h3>وکیوم تراپی (NPWT)</h3>
<p>استفاده از دستگاه وکیوم برای تخلیه ترشحات، افزایش خون‌رسانی و تسریع بسته شدن زخم‌های عمیق.</p>
<h2>مقایسه روش‌های پیشرفته درمان زخم</h2>
<table>
<thead>
<tr>
<th>روش درمان</th>
<th>کاربرد اصلی</th>
<th>مزیت کلیدی</th>
<th>دوره درمان</th>
</tr>
</thead>
<tbody>
<tr>
<td>پانسمان‌های نوین (هیدروکلوئید/آلژینات)</td>
<td>زخم‌های سطحی تا متوسط</td>
<td>حفظ رطوبت و کاهش درد تعویض</td>
<td>متغیر (هفتگی)</td>
</tr>
<tr>
<td>وکیوم تراپی (NPWT)</td>
<td>زخم‌های عمیق و جراحی باز</td>
<td>تخلیه سریع ترشحات و رشد بافت</td>
<td>۳ تا ۵ روز هر مرحله</td>
</tr>
<tr>
<td>اکسیژن درمانی (HBOT)</td>
<td>زخم‌های دیابتی و عفونی مقاوم</td>
<td>افزایش شدید اکسیژن‌رسانی به بافت</td>
<td>روزانه (۲۰ جلسه)</td>
</tr>
<tr>
<td>دبریدمان جراحی/آنزیمی</td>
<td>بافت‌های مرده و سیاه (نکروز)</td>
<td>پاکسازی بستر زخم برای شروع ترمیم</td>
<td>جلسات هفتگی</td>
</tr>
</tbody>
</table>
<h3>توصیه تخصصی</h3>
<p>اگر زخمی دارید که بیش از ۲ هفته هیچ بهبودی نشان نداده است، زمان را از دست ندهید. زخم‌های مزمن می‌توانند به سرعت عفونی شده و وارد بافت‌های عمقی شوند. مراجعه سریع برای ارزیابی عروقی و قند خون حیاتی است.</p>
<h2>تکنولوژی‌های درمانی در کلینیک همراه</h2>
<h3>۱. وکیوم تراپی (NPWT)</h3>
<p>استفاده از دستگاه‌های پمپ مکنده برای ایجاد فشار منفی روی زخم. این کار باعث کشیده شدن لبه‌های زخم به هم، کاهش تورم و تحریک شدید رگ‌سازی جدید می‌شود.</p>
<h3>۲. پانسمان‌های هوشمند و بیولوژیک</h3>
<p>استفاده از پانسمان‌های حاوی یون نقره (ضدعفونی کننده)، آلژینات (جذب کننده ترشحات زیاد) و هیدروژل‌ها که محیط ایده‌آل را برای ترمیم سلول‌ها فراهم می‌کنند.</p>
<h3>۳. لیزر درمانی کم‌توان (LLLT)</h3>
<p>استفاده از لیزرهای خاص برای کاهش التهاب، کنترل درد و افزایش متابولیسم سلولی در ناحیه زخم که سرعت ترمیم را تا دو برابر افزایش می‌دهد.</p>
<h3>نکته مهم</h3>
<p>هرگز روی زخم‌های باز از پمادهای گیاهی ناشناخته، خمیر دندان یا مواد خانگی استفاده نکنید. این کار نه تنها باعث عفونت قارچی می‌شود، بلکه روند درمان تخصصی را ماه‌ها به تأخیر می‌اندازد.</p>
<h2>چک‌لیست مراقبت از زخم در منزل</h2>
<p>✓<br></p>
<p>کنترل دقیق قند خون (برای بیماران دیابتی) و فشار خون</p>
<p>✓<br></p>
<p>تغذیه پر پروتئین و مصرف مکمل‌های روی (Zinc) و ویتامین C</p>
<p>✓<br></p>
<p>عدم تحمل وزن روی زخم (استفاده از عصا یا ویلچر برای زخم پا)</p>
<p>✓<br></p>
<p>تعویض منظم پانسمان طبق دستور پزشک و حفظ خشکی پانسمان</p>
<p>✓<br></p>
<p>ترک سیگار و قلیان (نیکوتین دشمن اصلی خون‌رسانی به زخم است)</p>' WHERE path = '/service/wound-clinic/';

-- صفحات آرشیو متن ثابت ندارند؛ قالبشان فهرست را از دیتابیس می‌سازد.
UPDATE pages SET body = NULL WHERE path IN ('/service/', '/team/', '/blog/');

-- ##### db/seed/04-faqs.sql #####

-- ============================================================
--  همراه کلینیک — سؤالات متداول
--  تولید خودکار: perl db/seed/gen-faqs.pl
--
--  منبع اسکیمای FAQPage. هر ردیف به یک صفحه در جدول pages
--  وصل است و قالب، این بخش را جداگانه رندر می‌کند.
--
--  پیش‌نیاز: 01-pages.sql و 03-content.sql اجرا شده باشند.
-- ============================================================

-- اجرای مکرر نباید سؤال تکراری بسازد
DELETE FROM faqs;

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا کاهش علائم همیشه به معنای موفقیت درمان است؟', '<p>خیر. گاهی داروها می‌توانند برخی علائم را موقتاً کنترل کنند اما تأثیر قابل توجهی بر خود تومور نداشته باشند، و از طرف دیگر ممکن است بیمار در طول درمان با خستگی، تهوع یا سایر عوارض روبه‌رو باشد اما نتایج تصویربرداری نشان دهد که تومور در حال کوچک شدن است. به همین دلیل پزشکان معمولاً مجموعه‌ای از اطلاعات را کنار هم قرار می‌دهند تا درباره اثربخشی درمان تصمیم بگیرند.</p>', 10 FROM pages WHERE path = '/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'بعد از چند جلسه می‌توان نتیجه را فهمید؟', '<p>زمان ارزیابی به نوع سرطان، داروهای مورد استفاده و برنامه درمانی بستگی دارد و در بسیاری از موارد پس از چند دوره شیمی‌درمانی نخستین تصویربرداری کنترل انجام می‌شود. بعضی بیماران در همان ماه‌های ابتدایی نشانه‌های پاسخ به درمان را نشان می‌دهند و در برخی دیگر ارزیابی نهایی به زمان بیشتری نیاز دارد.</p>', 20 FROM pages WHERE path = '/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چه زمانی پزشک درمان را تغییر می‌دهد؟', '<p>اگر بررسی‌ها نشان دهد که سرطان همچنان در حال رشد است یا پاسخ مناسبی به داروها نمی‌دهد، پزشک ممکن است نوع داروها را تغییر دهد یا از روش‌های دیگری مانند ایمونوتراپی، درمان هدفمند، جراحی یا پرتودرمانی استفاده کند و هدف این تصمیمات، انتخاب مؤثرترین روش برای کنترل بیماری است.</p>', 30 FROM pages WHERE path = '/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'از کجا بفهمیم شیمی درمانی جواب داده؟', '<p>پاسخ شیمی‌درمانی معمولاً با بررسی علائم بیمار و نتایج آزمایش‌ها مشخص می‌شود که کاهش درد، بهبود اشتها، افزایش انرژی یا کمتر شدن علائم بیماری می‌تواند نشانه امیدوارکننده‌ای باشد اما معیار اصلی ارزیابی تصویربرداری‌هایی مانند سی‌تی‌اسکن، ام‌آر‌آی یا پت‌اسکن است و اگر تومور کوچک‌تر شود یا رشد آن متوقف شود و دیگر در تصاویر دیده نشود درمان مؤثر بوده است، در مقابل بزرگ‌تر شدن تومور یا ایجاد ضایعات جدید ممکن است نشان‌دهنده پاسخ ناکافی به شیمی‌درمانی باشد.</p>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>', 40 FROM pages WHERE path = '/از-کجا-بفهمیم-شیمی-درمانی-جواب-داده/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا گرفتگی عروق پا قابل درمان است؟', '</p>
<p>بله، با تشخیص به موقع و درمان مناسب می‌توان بیماری را کنترل کرد و از پیشرفت آن جلوگیری نمود. روش‌های درمانی متنوعی از تغییر سبک زندگی تا جراحی وجود دارد و بسیاری از بیماران با درمان مناسب بهبود قابل توجهی تجربه می‌کنند.</p>
<p>', 10 FROM pages WHERE path = '/ایا-گرفتگی-عروق-پا-خطرناک-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا گرفتگی عروق پا با واریس تفاوت دارد؟', '</p>
<p>بله. گرفتگی عروق پا مربوط به شریان‌ها (رگ‌هایی که خون اکسیژن‌دار را از قلب به پاها می‌رسانند) است، در حالی که واریس مربوط به وریدها (رگ‌هایی که خون را از پاها به قلب برمی‌گردانند) می‌باشد. هر دو بیماری‌های عروقی هستند اما مکانیسم، علائم و درمان متفاوتی دارند.</p>
<p>', 20 FROM pages WHERE path = '/ایا-گرفتگی-عروق-پا-خطرناک-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چقدر طول می‌کشد تا گرفتگی عروق پا پیشرفت کند؟', '</p>
<p>سرعت پیشرفت بیماری در افراد مختلف متفاوت است و به عواملی مانند سبک زندگی، وجود بیماری‌های زمینه‌ای، رعایت توصیه‌های پزشکی و ژنتیک بستگی دارد. در برخی افراد ممکن است سال‌ها طول بکشد و در برخی دیگر سریع‌تر پیشرفت کند.</p>
<p>', 30 FROM pages WHERE path = '/ایا-گرفتگی-عروق-پا-خطرناک-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا ورزش برای گرفتگی عروق پا مفید است؟', '</p>
<p>بله، ورزش منظم یکی از مؤثرترین روش‌های درمان غیرجراحی است. پیاده‌روی تحت نظارت می‌تواند به تشکیل عروق جدید (کولاترال) کمک کند، علائم را بهبود بخشد و فاصله راه رفتن بدون درد را افزایش دهد.</p>
<p>', 40 FROM pages WHERE path = '/ایا-گرفتگی-عروق-پا-خطرناک-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا گرفتگی عروق پا می‌تواند منجر به سکته قلبی شود؟', '</p>
<p>بله، افرادی که به گرفتگی عروق پا مبتلا هستند، خطر بالاتری برای ابتلا به بیماری‌های قلبی عروقی از جمله سکته قلبی و مغزی دارند. این به دلیل وجود آترواسکلروز (تصلب شرایین) در کل سیستم عروقی بدن است.</p>
<p>', 50 FROM pages WHERE path = '/ایا-گرفتگی-عروق-پا-خطرناک-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا می‌توانم با گرفتگی عروق پا به زندگی عادی ادامه دهم؟', '</p>
<p>بله، با تشخیص به موقع، درمان مناسب و رعایت توصیه‌های پزشکی، بسیاری از بیماران می‌توانند زندگی فعال و عادی داشته باشند. نکته کلیدی مدیریت بیماری و پیشگیری از پیشرفت آن است.</p>', 60 FROM pages WHERE path = '/ایا-گرفتگی-عروق-پا-خطرناک-است/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا تپش قلب همیشه نشانه آریتمی خطرناک است؟', '<p>خیر، بسیاری از تپش‌ها خوش‌خیم هستند و ناشی از استرس، کافئین یا ورزش می‌باشند. اما اگر تداوم داشت یا با علائم دیگر همراه بود، باید بررسی شود.</p>', 10 FROM pages WHERE path = '/تشخیص-آریتمی-قلبی-در-خانه/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا می‌توانم با گوشی موبایل نوار قلب بگیرم؟', '<p>برخی اپلیکیشن‌ها و گجت‌های متصل به گوشی این امکان را می‌دهند، اما دقت آن‌ها به اندازه دستگاه‌های پزشکی نیست و فقط برای غربالگری اولیه کاربرد دارند، نه تشخیص قطعی.</p>', 20 FROM pages WHERE path = '/تشخیص-آریتمی-قلبی-در-خانه/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'درمان آریتمی چگونه است؟', '<p>درمان بستگی به نوع آریتمی دارد و می‌تواند شامل دارو، تغییر سبک زندگی، شوک الکتریکی (کاردیوورژن)، ابلیشن (سوزاندن کانون آریتمی) یا نصب باتری قلب (Pacemaker) باشد.</p>
<p>متخصصین ما در تمامی موارد در کنار شما هستند. برای مشاوره تخصصی و راهنمایی، فرم زیر را تکمیل کنید تا در اسرع وقت با شما تماس بگیریم.</p>', 30 FROM pages WHERE path = '/تشخیص-آریتمی-قلبی-در-خانه/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چقدر طول می‌کشد تا سیستم ایمنی بعد از شیمی‌درمانی به حالت عادی برگردد؟', 'این زمان برای هر فرد متفاوت است و بستگی به نوع داروهای مصرفی، سن و سلامت کلی شما دارد. اما به طور معمول، سیستم ایمنی بین چند هفته تا چند ماه (معمولا 1 تا 3 ماه) زمان نیاز دارد تا به‌طور کامل بازسازی شود.', 10 FROM pages WHERE path = '/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا می‌توانم بعد از شیمی‌درمانی واکسن آنفولانزا بزنم؟', 'بله، معمولا پزشکان توصیه می‌کنند، اما زمان‌بندی آن بسیار مهم است. چون سیستم ایمنی ضعیف است، ممکن است واکسن به خوبی عمل نکند. حتما قبل از تزریق هر واکسنی با پزشک انکولوژیست خود مشورت کنید. واکسن‌های حاوی ویروس زنده اغلب ممنوع هستند.', 20 FROM pages WHERE path = '/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'بهترین میان‌وعده برای تقویت بدن در این دوران چیست؟', 'مخلوطی از مغزهای بوداده (بدون نمک زیاد و تمیز)، تکه‌های میوه پخته شده (مثل کمپوت سیب خانگی با کمترین شکر)، تخم‌مرغ آب‌‌پز سفت و اسموتی‌های خانگی با پودر پروتئین (تحت نظر پزشک) گزینه‌های عالی هستند.', 30 FROM pages WHERE path = '/تقویت-سیستم-ایمنی-بدن-بعد-از-شیمی-درمان/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا باید شب قبل از شیمی‌درمانی ناشتا باشم؟', 'خیر، مگر اینکه پزشک شما دستور خاصی داده باشد. ناشتا بودن طولانی باعث ضعف و افت قند خون می‌شود. بدن شما برای مقابله با استرس درمان به سوخت نیاز دارد. یک شام سبک و یک صبحانه مختصر معمولا توصیه می‌شود.', 10 FROM pages WHERE path = '/شب-قبل-از-شیمی-درمانی-چه-بخوریم/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'اگر اشتها ندارم، باز هم باید غذا بخورم؟', 'بله، اما مجبور نیستید غذای جامد بخورید. اگر اشتها ندارید، سراغ مایعات مغذی بروید. اسموتی‌های خانگی (بدون لبنیات سنگین)، سوپ‌های رقیق یا آب‌میوه‌های طبیعی (مثل آب سیب) گزینه‌های خوبی هستند تا معده خالی نماند.', 20 FROM pages WHERE path = '/شب-قبل-از-شیمی-درمانی-چه-بخوریم/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا می‌توانم مکمل یا ویتامین مصرف کنم؟', 'بسیار احتیاط کنید. برخی ویتامین‌ها و آنتی‌اکسیدان‌های قوی ممکن است با داروهای شیمی‌درمانی تداخل داشته باشند و اثر آن‌ها را کم کنند. حتماً لیست مکمل‌های خود را با پزشک آنکولوژیست خود چک کنید و خودسرانه شب قبل چیزی مصرف نکنید.', 30 FROM pages WHERE path = '/شب-قبل-از-شیمی-درمانی-چه-بخوریم/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'نوشیدن آب را تا کی ادامه دهم؟', 'نوشیدن آب را در طول روز و شب ادامه دهید. حتی صبح روز درمان هم نوشیدن آب بسیار کمک‌کننده است. این کار رگ‌گیری را برای پرستار آسان‌تر کرده و کلیه‌ها را آماده پاکسازی می‌کند.', 40 FROM pages WHERE path = '/شب-قبل-از-شیمی-درمانی-چه-بخوریم/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'شب قبل از شیمی‌درمانی چه غذاهایی بخوریم؟', 'برای شب قبل از شیمی‌درمانی بهتر است غذاهای سبک و سرشار از پروتئین مصرف کنید تا بدن برای درمان آماده‌تر باشد، همچنین بهتر است از غذاهای چرب، سرخ‌کردنی و پرادویه در شب قبل از شیمی‌درمانی پرهیز شود، برای شب قبل از شیمی درمانی مواد غذایی زیر پیشنهاد میشود: • تخم‌مرغ آب‌پز یا املت کم‌چرب • مرغ یا بوقلمون بدون پوست • ماهی به‌ویژه ماهی‌های چرب مانند سالمون • حبوبات مانند عدس و لوبیا • برنج، نان سبوس‌دار یا سیب‌زمینی • سبزیجات پخته و میوه‌های تازه • آب و مایعات کافی', 50 FROM pages WHERE path = '/شب-قبل-از-شیمی-درمانی-چه-بخوریم/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'اگر یک جلسه را به دلیل بیماری یا مشکل شخصی از دست بدهم چه می‌شود؟', 'اگر به‌خاطر سرماخوردگی، تب یا مشکلات شخصی یک جلسه به تعویق افتاد، پزشک معمولا برنامه را بازتنظیم می‌کند. اما باید سعی کنید تا حد امکان دقیق باشید. تاخیرهای مکرر می‌تواند اثر درمان را به شدت کاهش دهد. همیشه قبل از کنسل کردن نوبت، با تیم درمان مشورت کنید.', 10 FROM pages WHERE path = '/هر-دوره-شیمی-درمانی-چند-جلسه-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا شیمی درمانی همیشه 3 هفته یکبار است یا می‌تواند هر روز باشد؟', 'همانطور که گفته شد، رایج‌ترین مدل هر 3 هفته یا 2 هفته یکبار است. اما برخی رژیم‌ها شامل مصرف قرص‌های خوراکی شیمی درمانی هستند که باید هر روز به مدت 14 روز در خانه مصرف شوند. همچنین در پرتودرمانی همزمان با شیمی درمانی، ممکن است دوزهای بسیار پایین شیمی درمانی به‌صورت هفتگی تزریق شود. پس مدل هر روز برای تزریق وریدی سنگین نادر است، اما برای قرص‌های خوراکی رایج است.', 20 FROM pages WHERE path = '/هر-دوره-شیمی-درمانی-چند-جلسه-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'طولانی‌ترین دوره شیمی درمانی چقدر است؟', 'برای شیمی درمانی نگهدارنده (Maintenance Therapy) که بعد از دوره اصلی انجام می‌شود یا برای کنترل سرطان‌های مزمن، درمان ممکن است سال‌ها طول بکشد. در این حالت، بیمار دوزهای پایین‌تری دریافت می‌کند تا بیماری خاموش بماند. اما برای شیمی درمانی‌های تهاجمی اولیه، معمولا دوره بیشتر از 6 تا 8 ماه توصیه نمی‌شود زیرا ریسک آسیب‌های دائمی به بدن بالا می‌رود.', 30 FROM pages WHERE path = '/هر-دوره-شیمی-درمانی-چند-جلسه-است/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'شیمی‌درمانی چند جلسه است و هر جلسه با چه فاصله‌ای انجام می‌شود؟', 'تعداد جلسات شیمی‌درمانی و فاصله بین جلسات به نوع سرطان، داروها و وضعیت بیمار بستگی دارد اما معمولاً در یک دوره درمان بین ۴ تا ۸ سیکل شیمی‌درمانی انجام می‌شود. • تعداد جلسات معمولاً ۴ تا ۸ سیکل است. • فاصله بین جلسات اغلب ۲ تا ۴ هفته می‌باشد. • هر جلسه ممکن است از چند دقیقه تا چند ساعت طول بکشد. • نوع درمان می‌تواند سرپایی یا بستری کوتاه‌مدت باشد. • برنامه درمانی توسط پزشک و بر اساس شرایط بیمار تنظیم می‌شود.', 40 FROM pages WHERE path = '/هر-دوره-شیمی-درمانی-چند-جلسه-است/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'کاردیوآنکولوژی چیست و چرا برای بیماران تحت درمان سرطان ضروری است؟', 'کاردیوآنکولوژی شاخه‌ای تخصصی است که بر پیشگیری، تشخیص و مدیریت عوارض قلبی-عروقی ناشی از درمان‌های سرطان (مانند شیمی‌درمانی و رادیوتراپی) تمرکز دارد. بسیاری از داروهای ضدسرطان می‌توانند بر عملکرد قلب تأثیر بگذارند. حضور فلوشیپ کاردیوآنکولوژی در تیم درمان، تضمین می‌کند که پروسه درمان سرطان بدون آسیب به قلب پیش رود و سلامت قلب بیمار در تمام مراحل مراقبت شود.', 10 FROM pages WHERE path = '/service/قلب-و-عروق/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'رویکرد «تیم چندتخصصی» (Multidisciplinary) در همراه کلینیک چه مزیتی برای بیمار دارد؟', 'برخلاف مراکز معمولی که بیمار را بین متخصصان مختلف سرگردان می‌کنند، در همراه کلینیک، فلوشیپ‌های قلب (اکوکاردیوگرافی، نارسایی قلب، کاردیوآنکولوژی) به همراه فوق تخصصان غدد، عفونی، روانپزشک و تغذیه، پرونده بیمار را به صورت مشترک بررسی می‌کنند. این هماهنگی به ویژه برای بیماران پیچیده (مانند دیابتی‌های دارای بیماری قلبی یا بیماران سرطانی) حیاتی است تا تداخلات دارویی کاهش یافته و بهترین استراتژی درمانی با کمترین عارضه جانبی انتخاب شود.', 20 FROM pages WHERE path = '/service/قلب-و-عروق/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'تفاوت اکوکاردیوگرافی پیشرفته و استرس اکو در این مرکز با مراکز دیگر چیست؟', 'ما از دستگاه اکوکاردیوگرافی فیلیپس مدل افنیتی ادونس (Affinityَ Advance ) استفاده می‌کنیم که دقت تصویربرداری بسیار بالایی دارد. در اکوکاردیوگرافی پیشرفته بر خلاف برخی مراکز تمامی اندازه گیری های مورد نیاز در قلب و اطلاعاتی نظیر GLS(Global Longitudinal strain) ثبت میشود که در روند درمان بیماران، بخصوص بیماران سرطانی بسیار تعیین کننده میباشد. استرس اکوکاردیوگرافی(اکوکاردیوگرافی با ضربان بالا) تستی بی خطر، دقیق و حساس برای تشخیص زودهنگام تنگی‌های خاموش کرونر و مشکلات دریچه‌ای می باشد و برای تعیین ریسک قلبی قبل از هر عمل جراحی بسیار کمک کننده است. در این تست آنچه که دقت را بالا می برد تجربه پزشک انجام دهنده و کیفیت بالای دستگاه است که هر دو در همراه کلینیک فراهم شده است.', 30 FROM pages WHERE path = '/service/قلب-و-عروق/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا بیماران مبتلا به نارسایی قلبی پیشرفته نیز در این مرکز تحت پوشش هستند؟', 'بله، با حضور فلوشیپ تخصصی نارسایی قلب و واحد تزریقات (Infusion Unit)، ما امکان ارائه درمان‌های پیشرفته تزریقی برای بیماران نارسایی قلبی را فراهم کرده‌ایم. همچنین با همکاری متخصص تغذیه و روانپزشک، جنبه‌های سبک زندگی و سلامت روان این بیماران نیز به طور همزمان مدیریت می‌شود تا کیفیت زندگی آن‌ها به حداکثر برسد.', 40 FROM pages WHERE path = '/service/قلب-و-عروق/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا شیمی‌درمانی دردناک است؟', 'خیر، خود فرآیند تزریق داروی شیمی‌درمانی معمولاً بدون درد است. ممکن است در محل ورود آنژیوکت احساس سوزش خفیفی داشته باشید که کاملاً قابل تحمل است. برخی داروها مانند پاکلی‌تاکسل ممکن است باعث گزگز دست و پا شوند که با داروهای پیش‌دارویی کنترل می‌شود.', 10 FROM pages WHERE path = '/service/شیمی-درمانی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'مدت زمان هر جلسه شیمی‌درمانی چقدر است؟', 'مدت زمان هر جلسه بسته به رژیم درمانی متفاوت است؛ از ۳۰ دقیقه تا ۸ ساعت متغیر است. برخی پروتکل‌ها به صورت تزریق سریع و برخی به صورت انفوزیون طولانی‌مدت انجام می‌شوند. در همراه کلینیک، فضای استراحت مناسبی برای بیماران در طول انفوزیون‌های طولانی در نظر گرفته شده است.', 20 FROM pages WHERE path = '/service/شیمی-درمانی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا ریزش مو در همه بیماران رخ می‌دهد؟', 'ریزش مو به نوع داروی مصرفی بستگی دارد. داروهایی مانند دوکسوروبیسین، پاکلی‌تاکسل و سیکلوفسفامید معمولاً باعث ریزش مو می‌شوند، در حالی که بسیاری از داروهای هدفمند جدید این عارضه را ندارند. پس از پایان درمان، موها معمولاً طی ۳ تا ۶ ماه دوباره رشد می‌کنند.', 30 FROM pages WHERE path = '/service/شیمی-درمانی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا در طول شیمی‌درمانی می‌توانم به سر کار برگردم؟', 'بسیاری از بیماران با تنظیم ساعات کاری و رعایت مراقبت‌ها، قادر به ادامه فعالیت حرفه‌ای خود هستند. این موضوع به نوع شغل، رژیم درمانی و وضعیت عمومی بیمار بستگی دارد. در همراه کلینیک، امکان تنظیم زمان جلسات در روزهای تعطیل یا ساعات شناور برای بیماران شاغل فراهم است.', 40 FROM pages WHERE path = '/service/شیمی-درمانی/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا برای مراجعه به بخش روان‌پزشکی نیاز به معرفی‌نامه از پزشک دیگر دارم؟', '<p>خیر، در اکثر کلینیک‌ها می‌توانید مستقیماً و بدون نیاز به ارجاع، نوبت روان‌پزشکی بگیرید. البته در برخی سیستم‌های بیمه‌ای، داشتن معرفی‌نامه ممکن است به پوشش بهتر هزینه‌ها کمک کند.</p>', 10 FROM pages WHERE path = '/service/روان-پزشکی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'جلسه اول روان‌پزشکی شامل چه مواردی می‌شود؟', '<p>جلسه اول شامل مصاحبه بالینی جامع، بررسی سابقه خانوادگی، سابقه پزشکی، علائم فعلی و در صورت نیاز، انجام تست‌های روان‌سنجی است. در پایان جلسه، تشخیص اولیه و طرح درمان پیشنهادی ارائه می‌شود.</p>', 20 FROM pages WHERE path = '/service/روان-پزشکی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا داروهای روان‌پزشکی اعتیادآور هستند؟', '<p>بیشتر داروهای رایج مانند ضدافسردگی‌ها (SSRIها) و ضدروان‌پریشی‌ها اعتیادآور نیستند. تنها برخی از ضد اضطراب‌ها مانند بنزودیازپین‌ها در صورت مصرف طولانی‌مدت ممکن است وابستگی ایجاد کنند که روان‌پزشک این موضوع را مدیریت می‌کند.</p>', 30 FROM pages WHERE path = '/service/روان-پزشکی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'طول دوره درمان روان‌پزشکی معمولاً چقدر است؟', '<p>بسته به نوع اختلال متفاوت است. افسردگی خفیف ممکن است ۶ تا ۱۲ ماه درمان نیاز داشته باشد، در حالی که اختلالاتی مانند دوقطبی یا اسکیزوفرنی نیازمند درمان مادام‌العمر هستند. روان‌پزشک بر اساس پاسخ درمانی، مدت را تنظیم می‌کند.</p>', 40 FROM pages WHERE path = '/service/روان-پزشکی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا اطلاعات من در بخش روان‌پزشکی محرمانه می‌ماند؟', '<p>بله، رازداری یکی از اصول بنیادین اخلاق روان‌پزشکی است. اطلاعات شما تنها در موارد استثنایی مانند خطر جدی برای جان خود یا دیگران، یا به حکم قانون، قابل افشا است. در سایر موارد، هیچ اطلاعاتی بدون رضایت کتبی شما به شخص ثالثی داده نمی‌شود.</p>', 50 FROM pages WHERE path = '/service/روان-پزشکی/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'تفاوت روان‌درمانی MCT با روش‌های معمول چیست؟', '<p>در فراشناخت‌درمانی (MCT)، به جای بحث درباره محتوای افکار منفی، بر روی «نحوه فکر کردن» و کنترل توجه تمرکز می‌شود. این روش برای افرادی که دچار نشخوار فکری شدید یا نگرانی مداوم هستند، بسیار کارآمدتر و سریع‌تر از روش‌های سنتی عمل می‌کند.</p>', 10 FROM pages WHERE path = '/service/روان-شناسی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا خدمات سازمانی فقط برای بیمارستان‌هاست؟', '<p>خیر. اگرچه تخصص ما در بهبود تجربه مراجعان مراکز درمانی است، اما اصول روانشناسی صنعتی و سازمانی ما برای تمام شرکت‌ها، استارتاپ‌ها و نهادهای دولتی جهت ارزیابی نیروی انسانی، کاهش استرس شغلی و بهبود رضایت مشتریان قابل اجراست.</p>', 20 FROM pages WHERE path = '/service/روان-شناسی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'فرآیند ارزیابی روان‌شناختی چگونه است؟', '<p>پس از جلسه مصاحبه اولیه، بسته به نیاز شما، مجموعه‌ای از آزمون‌های استاندارد (کاغذی یا کامپیوتری) تکمیل می‌شود. سپس نتایج توسط متخصص تفسیر شده و یک گزارش جامع همراه با پیشنهادات درمانی یا توسعه‌ای به شما ارائه می‌گردد.</p>', 30 FROM pages WHERE path = '/service/روان-شناسی/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا برای مراجعه به بخش تغذیه نیاز به معرفی‌نامه پزشک دارم؟', '<p>خیر، در اکثر کلینیک‌ها می‌توانید مستقیماً و بدون نیاز به ارجاع، نوبت متخصص تغذیه بگیرید. با این حال، اگر بیماری زمینه‌ای مانند دیابت، کم‌خونی یا اختلال تیروئید دارید، همراه‌داشتن آزمایش‌های اخیر و معرفی‌نامه پزشک معالج، به طراحی دقیق‌تر رژیم کمک می‌کند.</p>', 10 FROM pages WHERE path = '/service/تغذیه/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'جلسه اول متخصص تغذیه شامل چه مواردی می‌شود؟', '<p>جلسه اول معمولاً ۶۰ تا ۹۰ دقیقه طول می‌کشد و شامل بررسی سابقه پزشکی و خانوادگی، ارزیابی عادات غذایی، بررسی فعالیت بدنی و در صورت نیاز، بررسی آزمایش‌های خون است. در پایان جلسه، نیاز کالری و درشت‌مغذی‌های شما محاسبه شده و رژیم اولیه ارائه می‌شود.</p>', 20 FROM pages WHERE path = '/service/تغذیه/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا رژیم‌های کلینیک شامل حذف کامل نان و برنج هستند؟', '<p>خیر، رویکرد علمی و اصولی در تغذیه بالینی، حذف کامل گروه‌های غذایی نیست مگر در موارد خاص پزشکی (مانند سلیاک برای گلوتن). متخصص تغذیه مجرب، با محاسبه نیاز کالری و کربوهیدرات شما، مقدار مناسب نان، برنج و سایر کربوهیدرات‌ها را در رژیم می‌گنجاند.</p>', 30 FROM pages WHERE path = '/service/تغذیه/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'مدت زمان لازم برای رسیدن به وزن ایده‌آل چقدر است؟', '<p>کاهش وزن سالم و پایدار، معمولاً ۰.۵ تا ۱ کیلوگرم در هفته است. برای کاهش ۱۰ کیلوگرم اضافه وزن، به حدود ۳ تا ۶ ماه زمان نیاز دارید. پس از رسیدن به هدف، یک دوره تثبیت ۳ تا ۶ ماهه برای تنظیم متابولیسم و جلوگیری از بازگشت وزن ضروری است.</p>', 40 FROM pages WHERE path = '/service/تغذیه/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا متخصص تغذیه مکمل هم تجویز می‌کند؟', '<p>بله، در صورت تشخیص کمبود ریزمغذی از طریق آزمایش خون یا ارزیابی رژیم غذایی، متخصص تغذیه می‌تواند مکمل‌های مناسب مانند ویتامین D، آهن، B12، امگا ۳ یا پروبیوتیک را تجویز کند. با این حال، اصل اول در تغذیه بالینی، دریافت ریزمغذی‌ها از طریق غذا است.</p>', 50 FROM pages WHERE path = '/service/تغذیه/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا طب ایرانی می‌تواند سرطان را درمان کند؟', '<p>خیر، طب ایرانی به‌تنهایی نمی‌تواند سرطان را درمان کند. این طب به‌عنوان یک رویکرد مکمل و حمایتی عمل می‌کند که هدف آن کاهش عوارض درمان‌های مدرن (شیمی‌درمانی، پرتودرمانی)، بهبود کیفیت زندگی بیمار، و تقویت توان بدن برای تحمل بهتر روند درمان است. درمان اصلی سرطان باید تحت نظر پزشک انکولوژیست و با روش‌های استاندارد مدرن انجام شود.</p>', 10 FROM pages WHERE path = '/service/طب-ایرانی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا گیاهان دارویی با شیمی‌درمانی تداخل دارند؟', '<p>بله، برخی گیاهان دارویی می‌توانند با شیمی‌درمانی تداخل داشته باشند. به‌عنوان مثال، آنتی‌اکسیدان‌های قوی ممکن است اثربخشی برخی داروهای شیمی‌درمانی را کاهش دهند، و برخی گیاهان ممکن است متابولیسم داروها را تغییر دهند. به همین دلیل، بسیار مهم است که تمام گیاهان دارویی تحت نظارت پزشک متخصص طب ایرانی و با هماهنگی پزشک انکولوژیست مصرف شوند. زمان‌بندی مصرف نیز اهمیت دارد و معمولاً باید فاصله‌ای بین شیمی‌درمانی و مصرف گیاهان وجود داشته باشد.</p>', 20 FROM pages WHERE path = '/service/طب-ایرانی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چه مدت طول می‌کشد تا اثرات طب ایرانی مشخص شود؟', '<p>مدت زمان مشاهده اثرات به نوع عارضه و شرایط بیمار بستگی دارد. برخی تدابیر مانند مصرف زنجبیل برای تهوع، ممکن است ظرف چند ساعت تا چند روز اثر کنند. اما برای بهبود خستگی مفرط، تقویت سیستم ایمنی، یا اصلاح مزاج، معمولاً به ۴ تا ۸ هفته زمان نیاز است. ارزیابی دقیق و پایش منظم توسط پزشک، به تنظیم بهینه درمان و مشاهده بهترین نتایج کمک می‌کند.</p>', 30 FROM pages WHERE path = '/service/طب-ایرانی/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا حجامت یا فصد برای بیماران سرطانی مناسب است؟', '<p>حجامت و فصد برای بیماران سرطانی نیازمند احتیاط فراوان است. در بیمارانی که پلاکت خون پایین دارند (ترومبوسیتوپنی) یا در معرض خطر خونریزی هستند، این درمان‌ها ممنوع است. همچنین، در بیمارانی که سیستم ایمنی ضعیف دارند، خطر عفونت وجود دارد. اما بادکش خشک و ماساژ درمانی با روغن‌های گیاهی، برای اکثر بیماران بی‌خطر و مفید است. تصمیم نهایی باید توسط پزشک متخصص طب ایرانی و با در نظر گرفتن شرایط خاص هر بیمار گرفته شود.</p>', 40 FROM pages WHERE path = '/service/طب-ایرانی/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا هر صدای اضافی قلب (سوفل) در کودکان خطرناک است؟', '<p>خیر، بسیاری از سوفل‌ها در کودکان &#8220;بی‌خطر&#8221; (Innocent) هستند و با رشد کودک برطرف می‌شوند. با این حال، تشخیص قطعی بی‌خطر بودن آن تنها توسط فلوشیپ قلب کودکان و با انجام اکوکاردیوگرافی امکان‌پذیر است.</p>', 10 FROM pages WHERE path = '/service/کلینیک-قلب-کودکان/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'اکوکاردیوگرافی جنینی چیست و چه کسانی باید انجام دهند؟', '<p>یک سونوگرافی تخصصی و دقیق از قلب جنین است که معمولاً بین هفته‌های ۱۸ تا ۲۲ بارداری برای مادران پرخطر (مانند سابقه خانوادگی بیماری قلبی، دیابت بارداری، یا مصرف داروهای خاص) توصیه می‌شود.</p>', 20 FROM pages WHERE path = '/service/کلینیک-قلب-کودکان/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا کودک مبتلا به بیماری قلبی می‌تواند ورزش کند یا بازی کند؟', '<p>بسته به نوع و شدت بیماری، بسیاری از کودکان می‌توانند فعالیت‌های سبک یا حتی ورزش‌های رقابتی را با تایید پزشک انجام دهند. محدود کردن خودسرانه و بدون دلیل فعالیت کودک، توصیه نمی‌شود.</p>', 30 FROM pages WHERE path = '/service/کلینیک-قلب-کودکان/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'تفاوت ویزیت قلب کودکان با قلب بزرگسالان چیست؟', '<p>بیماری‌های قلبی کودکان اغلب مادرزادی (Congenital) هستند و فیزیولوژی قلب در حال رشد، تفسیر علائم و دوز دارویی کاملاً متفاوتی دارد که فقط فلوشیپ فوق تخصصی قلب کودکان آموزش دیده این دانش را دارد.</p>', 40 FROM pages WHERE path = '/service/کلینیک-قلب-کودکان/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا در صورت نیاز به جراحی، کلینیک هماهنگی لازم را انجام می‌دهد؟', '<p>بله، یکی از مزایای مراجعه به یک کلینیک جامع، داشتن شبکه ارتباطی قوی با برترین جراحان قلب کودکان است. در صورت نیاز، پرونده بیمار با هماهنگی کامل و معرفی‌نامه معتبر ارجاع داده می‌شود.</p>', 50 FROM pages WHERE path = '/service/کلینیک-قلب-کودکان/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا اکوکاردیوگرافی برای جنین خطرناک است؟', '<p>خیر، این روش کاملاً ایمن است و از امواج صوتی (نه اشعه) استفاده می‌کند. تاکنون هیچ عارضه‌ای برای مادر یا جنین گزارش نشده است.</p>', 10 FROM pages WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا می‌توانم همراه جنین در حین آزمایش حرکت کنم یا صحبت کنم؟', '<p>بله، اما برای دریافت تصاویر باکیفیت، بهتر است در حین تصویربرداری آرام باشید و از حرکات ناگهانی خودداری کنید. گاهی ممکن است از شما خواسته شود برای چند دقیقه در وضعیت خاصی بمانید.</p>', 20 FROM pages WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'اگر جنین در وضعیت نامناسبی باشد چه می‌شود؟', '<p>در این موارد، ممکن است از شما خواسته شود کمی راه بروید، چیزی بخورید یا تغییر وضعیت دهید. گاهی نیاز است آزمایش در روز دیگری تکرار شود تا جنین در وضعیت بهتری قرار گیرد.</p>', 30 FROM pages WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا می‌توانم همراهم (همسر یا مادر) در اتاق باشد؟', '<p>بله، در اکثر موارد حضور یک همراه مجاز است و حتی می‌توانند تصاویر قلب جنین را مشاهده کنند. این تجربه می‌تواند برای خانواده آرامش‌بخش باشد.</p>', 40 FROM pages WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چه مدت طول می‌کشد تا جواب آزمایش آماده شود؟', '<p>نتایج اولیه بلافاصله پس از اتمام آزمایش به شما داده می‌شود. گزارش کامل و مکتوب معمولاً در همان روز یا حداکثر تا ۲۴-۴۸ ساعت بعد آماده می‌شود.</p>', 50 FROM pages WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'اگر ناهنجاری تشخیص داده شود، چه اقداماتی انجام می‌شود؟', '<p>در این صورت، شما به تیم متخصصین شامل فلوشیپ قلب کودکان، متخصص زنان و زایمان، و در صورت نیاز جراح قلب کودکان ارجاع داده می‌شوید. برنامه‌ریزی دقیقی برای مراقبت‌های دوران بارداری، زمان و مکان زایمان، و درمان پس از تولد انجام خواهد شد.</p>', 60 FROM pages WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا خستگی مزمن من می‌تواند از آدرنال باشد؟', 'خستگی مزمن علل بسیاری دارد. نارسایی واقعی آدرنال یک بیماری مشخص و قابل‌تشخیص با آزمایش است. ارزیابی پزشک غدد می‌تواند آن را تأیید یا رد کند.', 10 FROM pages WHERE path = '/service/adrenal/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'فشار خون مقاوم به درمان چه ارتباطی با آدرنال دارد؟', 'گاهی فشار خونی که با چند دارو کنترل نمی‌شود، ریشه‌ی هورمونی دارد (مانند هیپرآلدوسترونیسم). در این موارد ارزیابی آدرنال توصیه می‌شود.', 20 FROM pages WHERE path = '/service/adrenal/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا زخم شریانی قابل درمان است؟', '<p>بله، با تشخیص به‌موقع و revascularization، اکثر زخم‌های شریانی قابل درمان هستند. تأخیر منجر به قطع عضو می‌شود.</p>', 10 FROM pages WHERE path = '/service/arterial-ulcer/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چرا درد شب‌ها بدتر می‌شود؟', '<p>در حالت دراز کشیدن، جاذبه‌ی زمین در رساندن خون به پاها کمک نمی‌کند. این یک علامت کلاسیک ایسکمی پیشرفته است.</p>', 20 FROM pages WHERE path = '/service/arterial-ulcer/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'HBOT چقدر مؤثر است؟', '<p>HBOT می‌تواند در زخم‌های شریانی پس از revascularization، روند بهبود را تسریع کند. اما به‌تنهایی جایگزین درمان عروقی نیست.</p>', 30 FROM pages WHERE path = '/service/arterial-ulcer/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا سوختگی درجه ۲ خود به خود خوب می‌شود؟', '<p>سوختگی درجه ۲ سطحی معمولاً در ۲-۳ هفته بدون اسکار بهبود می‌یابد. سوختگی درجه ۲ عمقی ممکن است ۳-۸ هفته نیاز داشته باشد و اسکار باقی بگذارد.</p>', 10 FROM pages WHERE path = '/service/burn-wound/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا پماد سوختگی خانگی مؤثر است؟', '<p>مالیدن خمیردندان، روغن، تخم‌مرغ و موارد سنتی روی سوختگی', 20 FROM pages WHERE path = '/service/burn-wound/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چرا زخم من ۶ ماه است که خوب نمی‌شود؟', '<p>زخم‌های مزمن یک یا چند علت زمینه‌ای دارند که اگر شناسایی و درمان نشوند، زخم بهبود نمی‌یابد. ارزیابی جامع اولین قدم است.</p>', 10 FROM pages WHERE path = '/service/chronic-wound/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا قطع عضو حتمی است؟', '<p>خیر. اکثر زخم‌های مزمن با درمان مناسب و در زمان مناسب بهبود می‌یابند. قطع عضو فقط در موارد گانگرن یا عفونت کنترل‌نشده‌ی تهدیدکننده‌ی جان لازم می‌شود.</p>', 20 FROM pages WHERE path = '/service/chronic-wound/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'هزینه‌ی درمان زخم مزمن چقدر است؟', '<p>به علت و وسعت زخم بستگی دارد. در اولین ویزیت برآورد دقیق ارائه می‌شود. این هزینه باید با هزینه‌ی عوارض زخم مزمن (بستری، جراحی، قطع عضو) مقایسه شود.</p>', 30 FROM pages WHERE path = '/service/chronic-wound/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا دیابت نوع ۲ قابل برگشت است؟', 'در مراحل اولیه و با کاهش وزن چشمگیر و تغییر سبک زندگی، بسیاری از بیماران می‌توانند قند خود را بدون دارو در محدوده‌ی نرمال نگه دارند (Remission). اما این موضوع نیاز به پیگیری مداوم دارد.', 10 FROM pages WHERE path = '/service/diabetes/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'HbA1c چیست و چرا مهم است؟', 'HbA1c میانگین قند خون شما در ۲ تا ۳ ماه گذشته را نشان می‌دهد. هدف برای اکثر بیماران دیابتی، زیر ۷٪ است. این آزمایش بهترین شاخص کنترل بلندمدت دیابت محسوب می‌شود.', 20 FROM pages WHERE path = '/service/diabetes/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا با دیابت می‌توانم میوه بخورم؟', 'بله، اما با اندازه و انتخاب درست. میوه‌های با شاخص قند پایین و در حد متعادل توصیه می‌شوند. برنامه‌ی دقیق توسط کارشناس تغذیه‌ی کلینیک تنظیم می‌شود.', 30 FROM pages WHERE path = '/service/diabetes/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا با زخم پای دیابتی می‌توان راه رفت؟', '<p>تا حد امکان از فشار روی پای دارای زخم اجتناب کنید. پزشک ممکن است کفش طبی، کاست تخصصی یا عصای زیربغل تجویز کند.</p>', 10 FROM pages WHERE path = '/service/diabetic-foot/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا قطع عضو حتمی است؟', '<p>خیر. با تشخیص و درمان به‌موقع، اکثر زخم‌های پای دیابتی بدون نیاز به قطع عضو بهبود می‌یابند. تأخیر در درمان است که ریسک قطع را افزایش می‌دهد.</p>', 20 FROM pages WHERE path = '/service/diabetic-foot/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'NPWT برای زخم دیابتی چقدر مؤثر است؟', '<p>مطالعات نشان داده NPWT می‌تواند زمان بهبود زخم‌های دیابتی را تا ۴۰٪ کاهش دهد، به‌خصوص در زخم‌های درجه ۲ و ۳.</p>', 30 FROM pages WHERE path = '/service/diabetic-foot/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا بیمه هزینه‌ی درمان را پوشش می‌دهد؟', '<p>بخشی از هزینه‌های ویزیت و پانسمان معمولاً تحت پوشش بیمه‌ی پایه است. هزینه‌ی NPWT و HBOT با بیمه‌ی تکمیلی ممکن است پوشش داده شود.</p>', 40 FROM pages WHERE path = '/service/diabetic-foot/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا بیماری‌های غدد مثل تیروئید قابل درمان قطعی هستند؟', '<p>بسیاری از اختلالات مانند کم‌کاری تیروئید با مصرف روزانه یک قرص ساده کاملاً کنترل می‌شوند و فرد زندگی عادی خواهد داشت. برخی موارد مانند گره‌های خوش‌خیم فقط نیاز به پیگیری دارند. هدف ما بازگرداندن تعادل هورمونی به بدن است.</p>', 10 FROM pages WHERE path = '/service/endocrine-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'ارتباط دیابت و زخم پای دیابتی چیست؟', '<p>قند خون بالا به مرور زمان به اعصاب و عروق پا آسیب می‌زند. این باعث می‌شود بیمار متوجه زخم نشود و زخم بهبود نیابد. در کلینیک همراه، کنترل قند در بخش غدد و مراقبت از پا در بخش زخم به صورت هماهنگ انجام می‌شود.</p>', 20 FROM pages WHERE path = '/service/endocrine-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'هر چند وقت یکبار باید برای چکاپ غدد مراجعه کنم؟', '<p>برای بیماری‌های پایدار مثل کم‌کاری تیروئید، معمولاً هر ۶ تا ۱۲ ماه کافی است. برای دیابت، پایش هر ۳ ماهه (HbA1c) ضروری است. پزشک شما برنامه دقیق پیگیری را تعیین خواهد کرد.</p>', 30 FROM pages WHERE path = '/service/endocrine-clinic/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'کوتاهی قد فرزندم همیشه نیاز به درمان دارد؟', 'خیر. بسیاری از کودکان کوتاه‌قد فقط الگوی رشد خانوادگی یا تأخیری دارند و کاملاً طبیعی‌اند. ارزیابی پزشک مشخص می‌کند که آیا علت قابل‌درمانی وجود دارد یا خیر.', 10 FROM pages WHERE path = '/service/growth-puberty/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'بهترین زمان مراجعه برای درمان رشد چه موقع است؟', 'هرچه زودتر بهتر. درمان اختلالات رشد پیش از بسته شدن صفحات رشد استخوان مؤثرتر است، بنابراین مراجعه‌ی به‌موقع اهمیت زیادی دارد.', 20 FROM pages WHERE path = '/service/growth-puberty/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چه زمانی آنتی‌بیوتیک خوراکی لازم است؟', '<p>زمانی که عفونت از زخم به بافت اطراف پخش شده باشد (سلولیت) یا علائم سیستمیک (تب) وجود داشته باشد.</p>', 10 FROM pages WHERE path = '/service/infected-wound/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا عسل واقعاً برای زخم مفید است؟', '<p>عسل پزشکی استاندارد (Medical-grade Manuka Honey) دارای اثرات آنتی‌میکروبیال ثابت‌شده است. عسل معمولی خانگی توصیه نمی‌شود.</p>', 20 FROM pages WHERE path = '/service/infected-wound/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا برای ویزیت نیاز به ارجاع از پزشک دیگری دارم؟', '<p>خیر، شما می‌توانید مستقیماً از متخصص عفونی نوبت بگیرید. اما اگر آزمایش یا تصویربرداری خاصی دارید، همراه داشتن آن‌ها به تشخیص سریع‌تر کمک می‌کند.</p>', 10 FROM pages WHERE path = '/service/infectious-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا تست‌های HIV و هپاتیت محرمانه است؟', '<p>بله، کاملاً. تمام مراحل مشاوره، نمونه‌گیری و اعلام نتایج با رعایت اصول اخلاقی و محرمانگی کامل انجام می‌شود و اطلاعات فقط در اختیار خود بیمار قرار می‌گیرد.</p>', 20 FROM pages WHERE path = '/service/infectious-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'درمان سل (TB) چقدر طول می‌کشد؟', '<p>درمان استاندارد سل حداقل ۶ ماه طول می‌کشد. مصرف منظم داروها در این دوره حیاتی است تا از بازگشت بیماری و مقاوم شدن میکرب جلوگیری شود.</p>', 30 FROM pages WHERE path = '/service/infectious-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'تفاوت ویروس و باکتری چیست؟', '<p>باکتری‌ها موجودات زنده‌ای هستند که با آنتی‌بیوتیک کشته می‌شوند، اما ویروس‌ها (مثل سرماخوردگی یا آنفلوآنزا) به آنتی‌بیوتیک پاسخ نمی‌دهند و درمان آن‌ها حمایتی یا ضدویروسی خاص است.</p>', 40 FROM pages WHERE path = '/service/infectious-clinic/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا چربی خون فقط با رژیم درست می‌شود؟', 'در موارد خفیف، تغذیه و ورزش می‌تواند کافی باشد. اما اگر ریسک قلبی بالا یا چربی خیلی بالا باشد، دارو (مانند استاتین) برای پیشگیری از سکته ضروری است.', 10 FROM pages WHERE path = '/service/metabolic-syndrome/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا مصرف استاتین مادام‌العمر است؟', 'در بسیاری موارد بله، چون این داروها ریسک قلبی-عروقی را کاهش می‌دهند. تصمیم بر اساس ریسک فردی شما توسط پزشک گرفته می‌شود.', 20 FROM pages WHERE path = '/service/metabolic-syndrome/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چرا با وجود رژیم، وزنم کم نمی‌شود؟', 'گاهی علل هورمونی مانند کم‌کاری تیروئید، مقاومت به انسولین یا PCOS مانع کاهش وزن می‌شوند. ارزیابی غدد می‌تواند این عوامل پنهان را شناسایی کند.', 10 FROM pages WHERE path = '/service/obesity/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'داروهای لاغری جدید (GLP-1) چقدر مؤثرند؟', 'این داروها می‌توانند کاهش وزن قابل‌توجهی ایجاد کنند، اما باید تحت نظر پزشک، با اندیکاسیون درست و در کنار تغذیه و ورزش تجویز شوند. خوددرمانی توصیه نمی‌شود.', 20 FROM pages WHERE path = '/service/obesity/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'از چه سنی باید تست تراکم استخوان بدهم؟', 'برای زنان معمولاً از زمان یائسگی یا ۶۵ سالگی، و زودتر در صورت وجود عوامل خطر (مصرف کورتون، شکستگی قبلی، لاغری شدید). پزشک بر اساس شرایط شما تصمیم می‌گیرد.', 10 FROM pages WHERE path = '/service/osteoporosis/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا فقط مصرف کلسیم برای درمان کافی است؟', 'خیر. کلسیم و ویتامین D پایه‌اند، اما در پوکی استخوان واقعی معمولاً به داروهای اختصاصی برای کاهش خطر شکستگی نیاز است.', 20 FROM pages WHERE path = '/service/osteoporosis/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا با PCOS می‌توانم باردار شوم؟', 'بله. بسیاری از زنان مبتلا به PCOS با کاهش وزن، تنظیم هورمونی و در صورت نیاز القای تخمک‌گذاری باردار می‌شوند. درمان به‌موقع شانس باروری را افزایش می‌دهد.', 10 FROM pages WHERE path = '/service/pcos/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا PCOS درمان قطعی دارد؟', 'PCOS یک وضعیت مزمن است، اما کاملاً قابل کنترل است. با مدیریت سبک زندگی و درمان دارویی، علائم به‌خوبی کنترل و از عوارض بلندمدت پیشگیری می‌شود.', 20 FROM pages WHERE path = '/service/pcos/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چرا PCOS با دیابت ارتباط دارد؟', 'مقاومت به انسولین که در PCOS شایع است، خطر ابتلا به دیابت نوع ۲ را افزایش می‌دهد. به همین دلیل کنترل وزن و پایش قند در این بیماران اهمیت دارد.', 30 FROM pages WHERE path = '/service/pcos/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا تومور هیپوفیز سرطانی است؟', 'اکثریت قریب به اتفاق تومورهای هیپوفیز خوش‌خیم (آدنوم) هستند و بسیاری از آن‌ها فقط با دارو کنترل می‌شوند.', 10 FROM pages WHERE path = '/service/pituitary/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'تفاوت دیابت بی‌مزه با دیابت قند چیست؟', 'دیابت بی‌مزه به قند خون ربطی ندارد؛ مشکل در هورمون تنظیم آب بدن است که باعث تشنگی و ادرار فراوان می‌شود. درمان آن کاملاً متفاوت است.', 20 FROM pages WHERE path = '/service/pituitary/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا زخم بستر در منزل قابل درمان است؟', '<p>بله. در موارد سبک تا متوسط، تیم پرستاری و پزشکی ما به منزل اعزام می‌شود. در موارد شدید، انتقال به کلینیک ضروری است.</p>', 10 FROM pages WHERE path = '/service/pressure-ulcer/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چقدر طول می‌کشد زخم بستر خوب شود؟', '<p>زخم مرحله ۱ ممکن است در ۳-۷ روز، مرحله ۲ در ۲-۴ هفته، اما مرحله ۳ و ۴ ممکن است ماه‌ها زمان نیاز داشته باشند.</p>', 20 FROM pages WHERE path = '/service/pressure-ulcer/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'تشک ضد زخم بستر را از کجا تهیه کنیم؟', '<p>کلینیک همراه با چند تأمین‌کننده‌ی معتبر همکاری دارد و می‌توانیم بهترین گزینه را با توجه به شرایط بیمار معرفی کنیم.</p>', 30 FROM pages WHERE path = '/service/pressure-ulcer/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا هورمون‌درمانی یائسگی خطرناک است؟', 'هورمون‌درمانی در افراد مناسب و با دوز و مدت درست، بی‌خطر و مؤثر است. تصمیم بر اساس سن، علائم و سابقه‌ی پزشکی فردی و پس از ارزیابی دقیق گرفته می‌شود.', 10 FROM pages WHERE path = '/service/sex-hormones/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'افت تستوسترون فقط مربوط به سن است؟', 'خیر. علاوه بر سن، چاقی، دیابت، اختلالات هیپوفیز و برخی داروها نیز می‌توانند باعث افت تستوسترون شوند. به همین دلیل ارزیابی علت ضروری است.', 20 FROM pages WHERE path = '/service/sex-hormones/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چه زمانی نگران زخم جراحی شویم؟', '<p>قرمزی فزاینده، ترشح چرکی، تب، باز شدن لبه‌های زخم، درد فزاینده — همگی نیاز به ارزیابی فوری دارند.</p>', 10 FROM pages WHERE path = '/service/surgical-wound/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا NPWT برای همه‌ی زخم‌های جراحی مناسب است؟', '<p>خیر. NPWT در زخم‌های با ترشح زیاد، عمق متوسط تا زیاد، و در زخم‌های Open Abdomen کاربرد دارد. در زخم‌های با خونریزی فعال یا عفونت شدید کنترل‌نشده، contraindicated است.</p>', 20 FROM pages WHERE path = '/service/surgical-wound/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'هزینه‌ی NPWT چقدر است؟', '<p>بسته به مدت و نوع دستگاه متفاوت است. در ویزیت اول برآورد دقیق ارائه می‌شود.</p>', 30 FROM pages WHERE path = '/service/surgical-wound/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا داروی تیروئید را باید مادام‌العمر مصرف کنم؟', 'در کم‌کاری دائمی تیروئید (مانند هاشیموتو)، معمولاً مصرف لووتیروکسین مادام‌العمر است، اما دارو ارزان، بی‌خطر و کاملاً مؤثر است و زندگی طبیعی را ممکن می‌سازد.', 10 FROM pages WHERE path = '/service/thyroid/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا همه‌ی گره‌های تیروئید سرطانی هستند؟', 'خیر. بیش از ۹۰٪ گره‌های تیروئید خوش‌خیم‌اند. با سونوگرافی و در صورت نیاز نمونه‌برداری، گره‌های پرخطر شناسایی می‌شوند.', 20 FROM pages WHERE path = '/service/thyroid/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'قرص تیروئید را چه زمانی بخورم؟', 'لووتیروکسین باید ناشتا و حدود ۳۰ تا ۶۰ دقیقه پیش از صبحانه با آب مصرف شود تا جذب کامل صورت گیرد.', 30 FROM pages WHERE path = '/service/thyroid/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'تا چه مدت پس از حادثه می‌توان بخیه زد؟', '<p>بخیه‌ی اولیه معمولاً در ۶-۸ ساعت اول. در صورت تأخیر، خطر عفونت افزایش می‌یابد و ممکن است بخیه‌ی تأخیری توصیه شود.</p>', 10 FROM pages WHERE path = '/service/traumatic-wound/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'زخم گاز سگ چه باید کرد؟', '<p>شست‌وشوی فوری با آب و صابون به مدت ۵ دقیقه، مراجعه به اورژانس برای واکسن هاری و کزاز، و سپس پیگیری در کلینیک زخم.</p>', 20 FROM pages WHERE path = '/service/traumatic-wound/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا UTI بدون آنتی‌بیوتیک خوب می‌شود؟', '<p>UTI ساده در برخی موارد خفیف می‌تواند خود به خود بهبود یابد، اما اکثر موارد نیاز به آنتی‌بیوتیک دارند تا از پیلونفریت جلوگیری شود.</p>', 10 FROM pages WHERE path = '/service/urinary-tract-infection/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چرا UTI من مرتب عود می‌کند؟', '<p>دلایل: تخلیه‌ی ناقص مثانه، سنگ ادراری، یائسگی، فعالیت جنسی، نقص ایمنی، یا مقاومت میکروبی. ارزیابی جامع لازم است.</p>', 20 FROM pages WHERE path = '/service/urinary-tract-infection/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا خانم‌ها هم باید به متخصص اورولوژی مراجعه کنند؟', '<p>بله، قطعاً. اورولوژی تخصص بیماری‌های دستگاه ادراری (کلیه، مثانه و مجرا) است که در هر دو جنس مشترک است. عفونت‌های مکرر ادراری، سنگ کلیه، بی‌اختیاری ادرار و خون در ادرار از مشکلات شایع بانوان است که توسط اورولوژیست درمان می‌شود.</p>', 10 FROM pages WHERE path = '/service/urology-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'برای ویزیت اورولوژی چه آمادگی‌هایی لازم است؟', '<p>بهتر است مثانه شما پر باشد تا در صورت نیاز سونوگرافی انجام شود. همچنین اگر آزمایش ادرار یا خون اخیر دارید، همراه داشته باشید. برای معاینه پروستات در آقایان، تخلیه روده می‌تواند کمک‌کننده باشد اما الزامی نیست.</p>', 20 FROM pages WHERE path = '/service/urology-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا سنگ کلیه همیشه نیاز به جراحی دارد؟', '<p>خیر. سنگ‌های کوچک (زیر ۵-۶ میلی‌متر) معمولاً با مصرف مایعات و دارو دفع می‌شوند. سنگ‌های متوسط با سنگ‌شکنی سرپایی و تنها سنگ‌های بسیار بزرگ یا پیچیده نیاز به جراحی دارند.</p>', 30 FROM pages WHERE path = '/service/urology-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'درمان کرایوتراپی برای HPV چقدر طول می‌کشد؟', '<p>این روش معمولاً به صورت سرپایی و در چند جلسه کوتاه انجام می‌شود. پس از فریز کردن ضایعه، ناحیه بهبود یافته و زگیل طی چند روز تا یک هفته جدا می‌شود. این روش درد کمی دارد و نیاز به بیهوشی ندارد.</p>', 40 FROM pages WHERE path = '/service/urology-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'سن شروع غربالگری سرطان پروستات چه زمانی است؟', '<p>برای مردان عادی، از سن ۵۰ سالگی و برای کسانی که سابقه خانوادگی دارند، از ۴۵ سالگی توصیه می‌شود سالانه آزمایش PSA و معاینه انگشتی انجام دهند.</p>', 50 FROM pages WHERE path = '/service/urology-clinic/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چقدر طول می‌کشد زخم وریدی خوب شود؟', '<p>زخم‌های وریدی متوسط معمولاً در ۳ تا ۴ ماه با درمان فشاری مناسب بهبود می‌یابند. زخم‌های وسیع ممکن است ۶ تا ۱۲ ماه نیاز داشته باشند.</p>', 10 FROM pages WHERE path = '/service/venous-ulcer/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا جوراب واریس را همیشه باید پوشید؟', '<p>پس از بهبود زخم، استفاده‌ی دائمی از جوراب واریس درجه ۲ برای جلوگیری از عود توصیه می‌شود.</p>', 20 FROM pages WHERE path = '/service/venous-ulcer/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا بدون درمان واریس، زخم بهبود می‌یابد؟', '<p>ممکن است موقتاً بهبود یابد، اما عود قطعی است. درمان ریشه‌ای نارسایی وریدی برای بهبود پایدار ضروری است.</p>', 30 FROM pages WHERE path = '/service/venous-ulcer/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا هپاتیت B واقعاً قابل درمان نیست؟', '<p>هپاتیت B مزمن قابل کنترل کامل است (سرکوب ویروس) اما شفای کامل نادر است. در حال حاضر داروهای جدید در حال توسعه هستند.</p>', 10 FROM pages WHERE path = '/service/viral-hepatitis/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'هزینه‌ی درمان هپاتیت C چقدر است؟', '<p>به لطف تولید داخلی DAAها در ایران، هزینه‌ی درمان هپاتیت C در مقایسه با ۱۰ سال پیش به‌شدت کاهش یافته و معمولاً تحت پوشش بیمه قرار می‌گیرد.</p>', 20 FROM pages WHERE path = '/service/viral-hepatitis/';

INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا درمان زخم دیابتی نیاز به بستری دارد؟', '<p>در اکثر موارد خیر. بیش از ۹۰٪ زخم‌های دیابتی به صورت سرپایی در کلینیک درمان می‌شوند. فقط در صورت وجود عفونت استخوان (استئومیلیت) یا گانگرن گسترده، نیاز به بستری و جراحی است.</p>', 10 FROM pages WHERE path = '/service/wound-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'هزینه درمان زخم چقدر است؟', '<p>هزینه بستگی به وسعت زخم و نوع پانسمان دارد. ما قبل از شروع درمان، برآورد هزینه را به شما اعلام می‌کنیم. همچنین با بسیاری از بیمه‌های تکمیلی قرارداد داریم.</p>', 20 FROM pages WHERE path = '/service/wound-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'آیا خدمات تعویض پانسمان در منزل دارید؟', '<p>بله، برای بیمارانی که امکان حرکت ندارند، تیم پرستاری متخصص ما پس از ویزیت اولیه توسط پزشک، برای تعویض پانسمان به منزل اعزام می‌شوند.</p>', 30 FROM pages WHERE path = '/service/wound-clinic/';
INSERT INTO faqs (page_id, question, answer, sort)
  SELECT id, 'چه زمانی باید نگران زخم شوم؟', '<p>اگر زخم دارای بوی بد، ترشحات چرکی سبز یا زرد، قرمزی گسترش یابنده در اطراف و یا تب باشد، نشانه عفونت است و باید فوراً مراجعه کنید.</p>', 40 FROM pages WHERE path = '/service/wound-clinic/';

