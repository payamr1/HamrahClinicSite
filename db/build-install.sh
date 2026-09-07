#!/bin/sh
# ============================================================
#  بازتولید کامل فایل‌های داده از منابع اولیه
#
#  ترتیب مهم است — هر مرحله به خروجی مرحله‌ی قبل تکیه دارد:
#    gen-pages.pl    از seo/meta-new.tsv     → 01-pages.sql
#    gen-content.pl  از extract/raw/*.html   → 03-content.sql
#    gen-faqs.pl     از 03-content.sql       → 04-faqs.sql
#                    و بخش FAQ را از 03 حذف می‌کند
#
#  در پایان هر پنج فایل در db/install.sql ترکیب می‌شوند.
#
#  نیازمند پوشه‌ی extract/ که در مخزن نیست (فایل‌های کرال).
#  اگر آن را ندارید، فایل‌های تولیدشده را دست نزنید.
# ============================================================
set -e
cd "$(dirname "$0")/.."

perl db/seed/gen-pages.pl
perl db/seed/gen-content.pl
perl db/seed/gen-faqs.pl

OUT=db/install.sql
{
  printf "SET NAMES utf8mb4;\n"
  printf "SET SQL_MODE = 'NO_AUTO_VALUE_ON_ZERO';\n\n"
  printf -- "-- ============================================================\n"
  printf -- "--  همراه کلینیک — نصب کامل دیتابیس در یک فایل\n"
  printf -- "--\n"
  printf -- "--  ترکیب پنج فایل به ترتیب درست:\n"
  printf -- "--    db/schema.sql                  ۱۳ جدول\n"
  printf -- "--    db/seed/01-pages.sql           ۸۲ آدرس با متای سئو\n"
  printf -- "--    db/seed/02-clinics-doctors.sql ۱۰ کلینیک و ۱۲ پزشک\n"
  printf -- "--    db/seed/03-content.sql         متن صفحات\n"
  printf -- "--    db/seed/04-faqs.sql            سؤالات متداول — منبع FAQPage\n"
  printf -- "--\n"
  printf -- "--  در phpMyAdmin فقط همین یک فایل را Import کنید.\n"
  printf -- "--  اجرای مکرر بی‌خطر است.\n"
  printf -- "--  بازتولید: sh db/build-install.sh\n"
  printf -- "-- ============================================================\n\n"

  for f in db/schema.sql \
           db/seed/01-pages.sql \
           db/seed/02-clinics-doctors.sql \
           db/seed/03-content.sql \
           db/seed/04-faqs.sql
  do
    printf -- "\n-- ##### %s #####\n\n" "$f"
    grep -v '^SET NAMES utf8mb4;$' "$f"
  done
} > "$OUT"

printf 'install.sql ساخته شد: %s\n' "$(du -h "$OUT" | cut -f1)"
printf '  جدول‌ها: %s   صفحات: %s   متن: %s   سؤالات: %s\n' \
  "$(grep -c 'CREATE TABLE' "$OUT")" \
  "$(grep -c 'INSERT INTO pages' "$OUT")" \
  "$(grep -c 'UPDATE pages SET body' "$OUT")" \
  "$(grep -c 'INSERT INTO faqs' "$OUT")"
