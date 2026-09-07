#!/usr/bin/perl
# ============================================================
#  تولید داده اولیه جدول pages از فایل‌های زیر:
#    seo/meta-new.tsv        — عنوان و توضیحات بازنویسی‌شده
#    extract/inventory.tsv   — H1 استخراج‌شده از سایت فعلی
#  خروجی: db/seed/01-pages.sql
#
#  ستون path به‌صورت decode‌شده ذخیره می‌شود تا در PHP بدون
#  دردسر با rawurldecode مقایسه شود. آدرس ایندکس‌شده تغییر نمی‌کند.
# ============================================================
use strict;
use utf8;
use warnings;
use Encode qw(encode decode);

binmode STDOUT, ':encoding(UTF-8)';

my $BASE = 'https://hamrahclinic.ir';

# %XX رشته‌ی بایتی می‌دهد، پس اول به بایت می‌بریم و بعد به کاراکتر
# برمی‌گردانیم؛ وگرنه لایه‌ی خروجی UTF-8 را دوباره encode می‌کند.
sub urldec {
    my ($s) = @_;
    $s = encode('UTF-8', $s);
    $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    return decode('UTF-8', $s);
}
# یکسان‌سازی مسیر برای تطبیق بخشنده.
# باید مو‌به‌مو با Router::normalizePath() در PHP یکسان بماند.
sub pathnorm {
    my ($s) = @_;
    $s =~ s/\x{0643}/\x{06A9}/g;   # ك عربی  → ک فارسی
    $s =~ s/\x{064A}/\x{06CC}/g;   # ي عربی  → ی فارسی
    $s =~ s/\x{0649}/\x{06CC}/g;   # ى       → ی
    $s =~ tr/\x{0660}-\x{0669}\x{06F0}-\x{06F9}/0-90-9/;  # ارقام عربی و فارسی → لاتین
    $s =~ s/\x{200C}//g;           # نیم‌فاصله
    $s =~ s{/{2,}}{/}g;            # اسلش تکراری
    $s =~ s/([A-Z])/lc($1)/ge;     # فقط حروف لاتین کوچک شوند
    return $s;
}

sub sqlq {                      # escape for a single-quoted SQL literal
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/\\/\\\\/g;
    $s =~ s/'/''/g;
    return $s;
}
sub trim {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/^\s+|\s+$//g;
    $s =~ s/\s+/ /g;
    return $s;
}

# ---- read the current H1 for each URL -----------------------
my %h1;
open my $inv, '<:encoding(UTF-8)', 'extract/inventory.tsv' or die "inventory: $!";
<$inv>;
while (my $l = <$inv>) {
    chomp $l;
    my @f = split /\t/, $l, -1;
    next unless @f >= 8;
    $h1{ $f[0] } = trim($f[7]);
}
close $inv;

# archives inherited a wrong or weak H1 from the old site — override
my %archive_title = (
    '/service/' => 'خدمات و کلینیک‌های تخصصی',
    '/team/'    => 'پزشکان همراه کلینیک',
    '/blog/'    => 'بلاگ سلامت همراه',
);

my %type_map = (
    home => 'home', page => 'page', service => 'service',
    team => 'doctor', post => 'post',
);

open my $out, '>:encoding(UTF-8)', 'db/seed/01-pages.sql' or die "out: $!";
print $out <<'HDR';
-- ============================================================
--  همراه کلینیک — داده اولیه صفحات (۸۲ آدرس)
--  تولید خودکار: perl db/seed/gen-pages.pl
--
--  ستون path دقیقاً همان مسیری است که امروز در گوگل ایندکس شده.
--  تغییر هر مقدار path بدون ثبت ریدایرکت = از دست رفتن رتبه.
-- ============================================================
SET NAMES utf8mb4;

HDR

open my $tsv, '<:encoding(UTF-8)', 'seo/meta-new.tsv' or die "meta: $!";
<$tsv>;
my ($n, %seen, %bytype) = (0);
while (my $l = <$tsv>) {
    chomp $l;
    next unless length $l;
    my ($url, $type, $mtitle, $mdesc) = split /\t/, $l, -1;

    my $raw  = $url;  $raw =~ s/^\Q$BASE\E//;
    my $path = urldec($raw);
    $path = '/' unless length $path;

    die "duplicate path: $path\n" if $seen{$path}++;

    (my $bare = $path) =~ s{/+$}{};
    my @seg  = split m{/}, $bare;
    my $slug = @seg ? $seg[-1] : 'home';
    $slug = 'home' unless length $slug;

    my $t = $type_map{$type} // 'page';
    $t = 'archive' if exists $archive_title{$path};
    $bytype{$t}++;

    my $title = $archive_title{$path}
             // (length($h1{$url} // '') ? $h1{$url} : do {
                    (my $x = $mtitle) =~ s/\s*\|.*$//;
                    $x =~ s/\s*-\s*همراه کلینیک$//;
                    trim($x);
                });

    printf $out "INSERT INTO pages (path, path_norm, type, slug, title, meta_title, meta_desc) VALUES\n"
              . "  ('%s', '%s', '%s', '%s', '%s', '%s', '%s')\n"
              . "  ON DUPLICATE KEY UPDATE path_norm=VALUES(path_norm), title=VALUES(title),\n"
              . "    meta_title=VALUES(meta_title), meta_desc=VALUES(meta_desc);\n",
        sqlq($path), sqlq(pathnorm($path)), $t, sqlq($slug), sqlq($title), sqlq(trim($mtitle)), sqlq(trim($mdesc));
    $n++;
}
close $tsv;
close $out;

print "rows: $n\n";
print "  $_ : $bytype{$_}\n" for sort keys %bytype;
