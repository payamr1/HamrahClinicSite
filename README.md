# همراه کلینیک — نسخه‌ی جدید

بازنویسی کامل hamrahclinic.ir با PHP خام و MySQL، بدون وردپرس.

**قاعده‌ی حاکم بر کل پروژه:** هر ۸۲ آدرس ایندکس‌شده‌ی سایت فعلی باید در
نسخه‌ی جدید کد ۲۰۰ برگردانند. فهرست مرجع در `current-urls-82.txt` است و
هر مسیری که کد ۲۰۰ نگیرد، یک خطای انتشار محسوب می‌شود.

---

## ساختار

```
public/          ریشه‌ی وب — تنها پوشه‌ای که از مرورگر دیده می‌شود
app/             کد برنامه: Router، Database، Seo، Repository، قالب‌ها
db/              schema.sql و داده‌ی اولیه
admin/           پنل مدیریت
seo/             متای بازنویسی‌شده‌ی ۸۲ صفحه + صفحه‌ی بازبینی
design/          ماکاپ‌های تأییدشده و توکن‌های رنگ
```

روی سرور، کد برنامه بیرون از ریشه‌ی وب قرار می‌گیرد:

```
~/public_html/             ← محتوای public/
~/hamrah-app/app/          ← کد
~/hamrah-app/db/           ← اسکیما و seed
~/hamrah-app/config.php    ← رمز دیتابیس (در مخزن نیست)
```

---

## استقرار — بار اول

### ۱. مخزن را روی گیت‌هاب بگذارید

روی گیت‌هاب یک مخزن **خصوصی** بسازید، بعد در ترمینال همین پوشه:

```bash
git remote add origin https://github.com/USER/hamrah-clinic.git
git push -u origin main
```

### ۲. دیتابیس بسازید

cPanel ▸ **MySQL Databases** ▸ یک دیتابیس و یک کاربر بسازید و کاربر را با
دسترسی `ALL PRIVILEGES` به دیتابیس وصل کنید. نام و رمز را نگه دارید.

### ۳. مخزن را در cPanel وصل کنید

cPanel ▸ **Git Version Control** ▸ Create:

| فیلد | مقدار |
|---|---|
| Clone URL | آدرس مخزن گیت‌هاب |
| Repository Path | `repositories/hamrah-clinic` |
| Repository Name | `hamrah-clinic` |

بعد از ساخته شدن، تب **Pull or Deploy** ▸ دکمه‌ی **Update from Remote** و
سپس **Deploy HEAD Commit**.

> اگر clone انجام نشد، احتمالاً سرور به گیت‌هاب دسترسی ندارد. در آن صورت
> `git bundle` یا آپلود zip از File Manager جایگزین است — خبر بدهید.

### ۴. مسیر ریشه‌ی وب را چک کنید

cPanel ▸ **Domains** ▸ روی `new.hamrahclinic.ir` ▸ مقدار Document Root.
ریشه‌ی وب این اکانت `/public_html` است و در `.cpanel.yml` تنظیم شده. اگر عوض شد، فقط خط `WEBROOT`
را عوض کنید و دوباره deploy بزنید.

### ۵. config.php را پر کنید

File Manager ▸ پوشه‌ی `hamrah-app` ▸ فایل `config.php.example` را به
`config.php` تغییر نام دهید و ویرایش کنید:

- `db.name` و `db.user` و `db.pass` ← از مرحله‌ی ۲
- `app_key` ← یک رشته‌ی تصادفی؛ در Terminal: `php -r "echo bin2hex(random_bytes(32));"`

سه مقدار زیر را **دست نزنید** تا روز جایگزینی:

```php
'env'            => 'staging',
'force_noindex'  => true,
'canonical_host' => 'hamrahclinic.ir',
```

### ۶. جدول‌ها را بسازید

cPanel ▸ **phpMyAdmin** ▸ دیتابیس را انتخاب کنید ▸ تب Import، **به همین ترتیب**:

1. `db/schema.sql` — ساخت ۱۳ جدول
2. `db/seed/01-pages.sql` — ۸۲ آدرس با متای سئو
3. `db/seed/02-clinics-doctors.sql` — ۹ کلینیک، ۱۲ پزشک و اتصال‌ها
4. `db/seed/03-content.sql` — متن ۷۷ صفحه، استخراج‌شده از سایت فعلی

ترتیب مهم است: فایل سوم با `path` به صفحات فایل دوم وصل می‌شود.

### ۷. سلامت را بررسی کنید

```
https://new.hamrahclinic.ir/_health.php
```

باید همه‌ی ردیف‌ها «قبول» باشند و «آدرس‌های ثبت‌شده» عدد **۸۲ از ۸۲** را
نشان دهد.

### ۸. گواهی SSL

cPanel ▸ **SSL/TLS Status** ▸ `new.hamrahclinic.ir` را تیک بزنید ▸
**Run AutoSSL**.

---

## استقرار — بارهای بعد

من commit می‌زنم، شما:

```bash
git push
```

بعد در cPanel ▸ Git Version Control ▸ **Update from Remote** ▸
**Deploy HEAD Commit**.

`config.php` و پوشه‌ی uploads هرگز بازنویسی نمی‌شوند.

---

## محافظت سئویی

سه لایه جلوی ایندکس شدن نسخه‌ی آزمایشی را می‌گیرند. تا روز جایگزینی
هیچ‌کدام را خاموش نکنید:

1. هدر `X-Robots-Tag: noindex` در `public/.htaccess`
2. `force_noindex => true` در `config.php`
3. تگ `canonical` که به `hamrahclinic.ir` اشاره می‌کند، نه به `new.`

اگر نسخه‌ی آزمایشی ایندکس شود، با سایت اصلی محتوای تکراری می‌سازد و به
رتبه‌ی هر دو آسیب می‌زند.

---

## روز جایگزینی

1. کل دیتابیس و فایل‌ها را برای رشته‌ی `new.hamrahclinic.ir` جست‌وجو و پاک‌سازی کنید
2. در `config.php`: `env => 'production'` و `force_noindex => false`
3. بلوک `X-Robots-Tag` را از `.htaccess` حذف کنید
4. `public/_health.php` را حذف کنید
5. هر ۸۲ آدرس `current-urls-82.txt` را تست کنید — همه باید ۲۰۰ بدهند
6. سایت‌مپ را در سرچ کنسول دوباره ثبت کنید
7. سی روز گزارش Page Indexing و Core Web Vitals را هفتگی ببینید

---

## توسعه‌ی محلی

روی این کامپیوتر PHP نصب نیست، پس تست روی `new.hamrahclinic.ir` انجام
می‌شود. برای اجرای محلی:

```bash
php -S localhost:8000 -t public
```

و در `config.php` مقدار `db.host` را به دیتابیس محلی وصل کنید.

بازتولید داده‌ی اولیه از فایل متا:

```bash
perl db/seed/gen-pages.pl
```
