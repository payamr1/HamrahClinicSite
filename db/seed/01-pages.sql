-- ============================================================
--  همراه کلینیک — داده اولیه صفحات (۸۲ آدرس)
--  تولید خودکار: perl db/seed/gen-pages.pl
--
--  ستون path دقیقاً همان مسیری است که امروز در گوگل ایندکس شده.
--  تغییر هر مقدار path بدون ثبت ریدایرکت = از دست رفتن رتبه.
-- ============================================================
SET NAMES utf8mb4;

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
