-- ============================================================
--  همراه کلینیک — کلینیک‌ها، پزشکان و اتصال آن‌ها
--
--  پیش‌نیاز: 01-pages.sql اجرا شده باشد.
--  اتصال‌ها با path انجام می‌شود، نه با id، تا مستقل از ترتیب
--  درج و قابل اجرای مکرر باشد.
-- ============================================================
SET NAMES utf8mb4;

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
--  پاک‌سازی تکراری‌های import های قبلی
--
--  جدول doctors در نسخه‌ی اول کلید یکتا نداشت، پس هر بار اجرای
--  این فایل ۱۲ پزشک تازه اضافه می‌کرد. اثرش روی سایت این بود که
--  صفحه‌ی اصلی شش کارت نشان می‌داد ولی فقط سه پزشک — هر کدام
--  دو بار — و همین باعث می‌شد به نظر برسد عکس‌ها با اسم‌ها
--  نمی‌خوانند.
--
--  اول تکراری‌ها حذف می‌شوند (قدیمی‌ترین ردیف می‌ماند)، بعد کلید
--  یکتا اضافه می‌شود تا دیگر تکرار نشود.
-- ------------------------------------------------------------
DELETE d FROM doctors d
  JOIN doctors keep ON keep.name = d.name AND keep.id < d.id;

SET @k := (SELECT COUNT(*) FROM information_schema.STATISTICS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'doctors' AND INDEX_NAME = 'uq_doctor_name');
SET @sql := IF(@k = 0,
  'ALTER TABLE doctors ADD UNIQUE KEY uq_doctor_name (name)',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

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
  ('address',        'تهران، تجریش، خیابان شریعتی، نرسیده به میدان قدس، کوچه مهنا ۱، پلاک ۶'),
  ('hours',          'شنبه تا چهارشنبه ۸ تا ۲۰ · پنجشنبه ۸ تا ۱۳'),
  ('canonical_host', 'hamrahclinic.ir')
ON DUPLICATE KEY UPDATE v = VALUES(v);

-- ------------------------------------------------------------
--  تصاویر
--  فایل‌ها در public/assets/img/ هستند و همراه مخزن استقرار
--  می‌شوند. عکس‌های باکیفیت‌تر بعداً از پنل جایگزین می‌شوند.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
--  تصویر کلینیک‌ها
--
--  از تگ og:image صفحه‌ی هر کلینیک در سایت اصلی گرفته شده.
--  کلینیک غدد و اورولوژی در سایت اصلی تصویر شاخص ندارند و
--  خالی می‌مانند؛ قالب برایشان زمینه‌ی گرادیان می‌گذارد.
-- ------------------------------------------------------------
UPDATE clinics SET image = 'clinics/cardiology.jpg' WHERE slug = 'cardiology';
UPDATE clinics SET image = 'clinics/chemotherapy.jpg' WHERE slug = 'chemotherapy';
UPDATE clinics SET image = 'clinics/infectious.webp' WHERE slug = 'infectious';
UPDATE clinics SET image = 'clinics/mental-health.jpg' WHERE slug = 'mental-health';
UPDATE clinics SET image = 'clinics/nutrition.jpg' WHERE slug = 'nutrition';
UPDATE clinics SET image = 'clinics/oncology.webp' WHERE slug = 'oncology';
UPDATE clinics SET image = 'clinics/persian-medicine.jpg' WHERE slug = 'persian-medicine';
UPDATE clinics SET image = 'clinics/wound.webp' WHERE slug = 'wound';
UPDATE clinics SET image = NULL WHERE slug IN ('endocrine', 'urology');

-- ------------------------------------------------------------
--  لینک نوبت‌دهی آنلاین
--
--  از فهرست book.hamrahclinic.ir. فقط ۹ پزشکی که نامشان قطعاً
--  با ردیف سایت می‌خواند اینجا آمده‌اند.
--
--  چهار مورد عمداً خالی مانده چون ابهام دارد و حدس زدن همان
--  اشتباهی است که سر عکس‌ها کردم:
--    · محبوبه خلیلی — در فهرست نوبت‌دهی «فرناز خلیلی» هست،
--      نام کوچک فرق دارد؛ معلوم نیست یک نفرند یا دو نفر
--    · مهناز عالم‌زاده بحرینی — در فهرست نوبت‌دهی نیست
--    · حسام دانش‌آموز — در فهرست نوبت‌دهی نیست
--  و هشت پزشک فهرست نوبت‌دهی که اصلاً صفحه‌ای در سایت ندارند.
--
--  ستون اضافه می‌شود اگر نباشد، تا روی دیتابیس موجود هم کار کند.
-- ------------------------------------------------------------
SET @c := (SELECT COUNT(*) FROM information_schema.COLUMNS
           WHERE TABLE_SCHEMA = DATABASE()
             AND TABLE_NAME = 'doctors' AND COLUMN_NAME = 'booking_url');
SET @sql := IF(@c = 0,
  'ALTER TABLE doctors ADD COLUMN booking_url VARCHAR(255) NULL AFTER photo',
  'DO 0');
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1214' WHERE name = 'دکتر حسین اصغری‌پور';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1158' WHERE name = 'دکتر مریم بدیع‌زادگان';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1221' WHERE name = 'دکتر بهناز بهزادی';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1168' WHERE name = 'دکتر علیرضا تاتینا';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1180' WHERE name = 'دکتر غزاله حیدری‌راد';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1165' WHERE name = 'دکتر شادی شکرخوار';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1163' WHERE name = 'دکتر احمد مافی';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1215' WHERE name = 'دکتر رضا مقبولی';
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1162' WHERE name = 'دکتر فاطمه نائینی';

-- ============================================================
--  پزشکان تازه، لینک نوبت‌دهی بخش‌ها و اصلاحات
-- ============================================================

-- ------------------------------------------------------------
--  دکتر محبوبه خلیلی
--  در سامانه‌ی نوبت‌دهی با نام «فرناز خلیلی» ثبت شده ولی همان
--  فرد است؛ نام رسمی محبوبه است و روی سایت همان می‌ماند.
-- ------------------------------------------------------------
UPDATE doctors SET booking_url = 'https://book.hamrahclinic.ir/?doctor=1156'
  WHERE name = 'دکتر محبوبه خلیلی';

-- ------------------------------------------------------------
--  دو پزشک تازه
--  صفحه‌ی این دو در سایت قبلی وجود نداشت، پس آدرس تازه‌اند و
--  قرارداد ۸۲ آدرس را نقض نمی‌کنند.
--  عکسشان بعداً اضافه می‌شود؛ تا آن موقع قالب گرادیان می‌گذارد.
-- ------------------------------------------------------------
INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc, sort) VALUES
  ('/team/دکتر-الهام-مهرآوران/', '/team/دکتر-الهام-مهرآوران/', 'doctor', 'دکتر-الهام-مهرآوران',
   'دکتر الهام مهرآوران',
   'دکتر الهام مهرآوران | متخصص رادیوتراپی انکولوژی',
   'دکتر الهام مهرآوران، متخصص رادیوتراپی انکولوژی در بخش آنکولوژی همراه کلینیک تجریش تهران. رزرو نوبت آنلاین و مشاوره تخصصی درمان سرطان.',
   125),
  ('/team/دکتر-شهرزاد-محسنی/', '/team/دکتر-شهرزاد-محسنی/', 'doctor', 'دکتر-شهرزاد-محسنی',
   'دکتر شهرزاد محسنی',
   'دکتر شهرزاد محسنی | متخصص قلب و فلوشیپ نارسایی قلب',
   'دکتر شهرزاد محسنی، متخصص قلب و عروق با فلوشیپ نارسایی قلب، در بخش قلب و عروق همراه کلینیک تجریش تهران. رزرو نوبت آنلاین.',
   75)
ON DUPLICATE KEY UPDATE title = VALUES(title),
  meta_title = VALUES(meta_title), meta_desc = VALUES(meta_desc), sort = VALUES(sort);

INSERT INTO doctors (page_id, name, specialty, fellowship, university, booking_url, sort) VALUES
  ((SELECT id FROM pages WHERE path = '/team/دکتر-الهام-مهرآوران/'),
   'دکتر الهام مهرآوران', 'متخصص رادیوتراپی انکولوژی',
   NULL, 'دانشگاه علوم پزشکی شهید بهشتی',
   'https://book.hamrahclinic.ir/?doctor=1232', 125),
  ((SELECT id FROM pages WHERE path = '/team/دکتر-شهرزاد-محسنی/'),
   'دکتر شهرزاد محسنی', 'متخصص قلب و عروق',
   'فلوشیپ نارسایی قلب', NULL,
   'https://book.hamrahclinic.ir/?doctor=1224', 75)
ON DUPLICATE KEY UPDATE
  specialty = VALUES(specialty), fellowship = VALUES(fellowship),
  university = VALUES(university), booking_url = VALUES(booking_url),
  page_id = VALUES(page_id), sort = VALUES(sort);

INSERT INTO doctor_clinic (doctor_id, clinic_id)
SELECT d.id, c.id FROM doctors d, clinics c WHERE
     (d.name = 'دکتر الهام مهرآوران' AND c.slug IN ('oncology', 'chemotherapy'))
  OR (d.name = 'دکتر شهرزاد محسنی'   AND c.slug = 'cardiology')
ON DUPLICATE KEY UPDATE doctor_id = VALUES(doctor_id);

-- ------------------------------------------------------------
--  لینک نوبت‌دهی بخش‌ها
--
--  اجرای مکرر نباید تکراری بسازد.
-- ------------------------------------------------------------
DELETE FROM booking_links;

-- دکتر نیلوفر آخوندزاده: فقط امکان گرفتن نوبت، بدون نمایش نام
INSERT INTO booking_links (page_id, label, url, sort)
  SELECT id, NULL, 'https://book.hamrahclinic.ir/?doctor=1238', 10
    FROM pages WHERE path = '/service/اکوکاردیوگرافی-قلب-جنین/';
INSERT INTO booking_links (page_id, label, url, sort)
  SELECT id, NULL, 'https://book.hamrahclinic.ir/?doctor=1238', 10
    FROM pages WHERE path = '/service/کلینیک-قلب-کودکان/';

-- کلینیک عفونی → دکتر منیره کمالی
INSERT INTO booking_links (clinic_id, label, url, sort)
  SELECT id, 'دکتر منیره کمالی', 'https://book.hamrahclinic.ir/?doctor=1216', 10
    FROM clinics WHERE slug = 'infectious';

-- کلینیک غدد → دو پزشک، بیمار انتخاب می‌کند
INSERT INTO booking_links (clinic_id, label, url, sort)
  SELECT id, 'دکتر زهرا قائم‌مقامی', 'https://book.hamrahclinic.ir/?doctor=1219', 10
    FROM clinics WHERE slug = 'endocrine';
INSERT INTO booking_links (clinic_id, label, url, sort)
  SELECT id, 'دکتر زهرا جلیلیان', 'https://book.hamrahclinic.ir/?doctor=1220', 20
    FROM clinics WHERE slug = 'endocrine';
