-- ============================================================
--  همراه کلینیک — پاک کردن کامل دیتابیس
--
--  ⚠ همه‌ی جدول‌ها و داده‌ها را حذف می‌کند.
--
--  کِی لازم است: اگر ساختار دیتابیس نیمه‌کاره ماند یا خطایی
--  گرفتید که با import دوباره حل نشد. بعد از این فایل،
--  db/install.sql را اجرا کنید تا همه‌چیز از نو ساخته شود.
--
--  چیزی از دست نمی‌رود: تمام محتوا در install.sql است.
--  تنها استثنا داده‌هایی است که خودِ سایت ساخته باشد —
--  درخواست‌های نوبت، گزارش ۴۰۴ و کاربران پنل.
-- ============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS admin_otp;
DROP TABLE IF EXISTS admin_users;
DROP TABLE IF EXISTS appointments;
DROP TABLE IF EXISTS media_tag;
DROP TABLE IF EXISTS media;
DROP TABLE IF EXISTS not_found_log;
DROP TABLE IF EXISTS redirects;
DROP TABLE IF EXISTS faqs;
DROP TABLE IF EXISTS page_author;
DROP TABLE IF EXISTS doctor_clinic;
DROP TABLE IF EXISTS doctors;
DROP TABLE IF EXISTS pages;
DROP TABLE IF EXISTS clinics;
DROP TABLE IF EXISTS settings;

SET FOREIGN_KEY_CHECKS = 1;
