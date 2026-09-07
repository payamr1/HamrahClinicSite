#!/usr/bin/perl
# ============================================================
#  استخراج متن ۸۲ صفحه از آرشیو سایت فعلی
#
#  ورودی : extract/raw/*.html   (خروجی کرال سایت فعلی)
#  خروجی : db/seed/03-content.sql
#
#  کار اصلی: HTML شلوغ المنتور را به HTML تمیز تبدیل می‌کند.
#  فقط تگ‌های معنایی می‌مانند و همه‌ی div و span و class حذف
#  می‌شوند، چون قالب جدید استایل خودش را دارد.
#
#  ایموجی از تیترها برداشته می‌شود: در تگ h2 به گوگل سیگنالی
#  نمی‌دهد و در نتایج جست‌وجو معمولاً حذف می‌شود.
# ============================================================
use strict;
use utf8;
use warnings;
use Encode qw(encode decode);

binmode STDOUT, ':encoding(UTF-8)';

my $RAW  = 'extract/raw';
my $META = 'seo/meta-new.tsv';
my $OUT  = 'db/seed/03-content.sql';

# ---- کمکی --------------------------------------------------
sub urldec {
    my ($s) = @_;
    $s = encode('UTF-8', $s);
    $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    return decode('UTF-8', $s);
}
sub sqlq {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/\\/\\\\/g;
    $s =~ s/'/''/g;
    return $s;
}
sub strip_emoji {
    my ($s) = @_;
    # نمادها، ایموجی و علائم تزئینی
    $s =~ s/[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}\x{20E3}\x{2190}-\x{21FF}]//g;
    $s =~ s/^[\s:•\-–—]+//;
    $s =~ s/[\s:]+$//;
    return $s;
}

# تگ‌هایی که نگه می‌داریم و attribute مجاز هرکدام
my %KEEP = (
    h2 => [], h3 => [], h4 => [],
    p  => [], br => [],
    ul => [], ol => [], li => [],
    strong => [], b => [], em => [], i => [],
    blockquote => [],
    table => [], thead => [], tbody => [], tr => [], th => [], td => [],
    a  => ['href'],
);

sub clean_html {
    my ($h) = @_;

    # چیزهایی که کامل حذف می‌شوند
    $h =~ s{<(script|style|noscript|iframe|svg|form|button|select|textarea)\b.*?</\1\s*>}{}gis;
    $h =~ s{<!--.*?-->}{}gs;
    $h =~ s{<(script|style|link|meta|input|source)\b[^>]*/?>}{}gis;

    # تصاویر: فعلاً حذف می‌شوند چون فایل‌ها روی سرور جدید نیستند.
    # تصویر شاخص از ستون hero_image می‌آید.
    $h =~ s{<img\b[^>]*>}{}gis;
    $h =~ s{<(figure|figcaption)\b[^>]*>}{}gis;
    $h =~ s{</(figure|figcaption)\s*>}{}gis;

    # h1 داخل متن به h2 تبدیل می‌شود — h1 صفحه از ستون title می‌آید
    $h =~ s{<h1\b[^>]*>}{<h2>}gis;
    $h =~ s{</h1\s*>}{</h2>}gis;

    # تگ‌های باقی‌مانده را فیلتر کن
    $h =~ s{<\s*/\s*([a-zA-Z][a-zA-Z0-9]*)\s*>}{
        my $t = lc $1;
        exists $KEEP{$t} ? "</$t>" : ''
    }gex;

    $h =~ s{<\s*([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>}{
        my ($t, $attr) = (lc $1, $2);
        if (!exists $KEEP{$t}) { '' }
        elsif (!@{$KEEP{$t}})  { "<$t>" }
        else {
            my $out = "<$t";
            for my $a (@{$KEEP{$t}}) {
                if ($attr =~ /\b\Q$a\E\s*=\s*"([^"]*)"/i || $attr =~ /\b\Q$a\E\s*=\s*'([^']*)'/i) {
                    my $v = $1;
                    # لینک‌های داخلی نسبی شوند، خارجی‌ها حذف
                    if ($a eq 'href') {
                        next if $v =~ /^(javascript|mailto|#)/i;
                        $v =~ s{^https?://(?:www\.)?hamrahclinic\.ir}{};
                        $v = urldec($v) if $v =~ /%[0-9A-Fa-f]{2}/;
                        next if $v !~ m{^/};
                    }
                    $v =~ s/"/&quot;/g;
                    $out .= qq{ $a="$v"};
                }
            }
            $out . '>';
        }
    }gex;

    # ایموجی را از تیترها بردار
    $h =~ s{<(h[234])>(.*?)</\1>}{ "<$1>" . strip_emoji($2) . "</$1>" }gise;

    # فاصله‌ها
    $h =~ s/&nbsp;/ /g;
    $h =~ s/[ \t]+/ /g;
    $h =~ s/\s*\n\s*/\n/g;

    # عناصر خالی
    for (1 .. 4) {
        $h =~ s{<(p|li|ul|ol|h2|h3|h4|strong|em|b|i|td|th|tr|table|blockquote)>\s*</\1>}{}gis;
        $h =~ s{<(p|h2|h3|h4)>(?:\s|<br>)*</\1>}{}gis;
    }
    $h =~ s{(?:<br>\s*){3,}}{<br>}gis;

    # هر تگ در خط خودش، برای خوانایی خروجی
    $h =~ s{>\s*<}{>\n<}g;
    $h =~ s/^\s+|\s+$//g;

    # متن‌های آزاد را در <p> بپیچ.
    # وقتی div و span حذف می‌شوند، متنی که داخلشان بود بی‌تگ می‌ماند
    # و بدون این کار در قالب بدون استایل رندر می‌شود.
    my @out;
    my $depth = 0;   # عمق داخل عناصری که می‌توانند متن بگیرند
    for my $line (split /\n/, $h) {
        if ($line =~ /^\s*$/) { next }
        if ($line =~ /^</) {
            $depth++ while $line =~ m{<(p|li|td|th|h[234]|strong|b|em|i|a|blockquote)\b[^>]*>}g;
            $depth-- while $line =~ m{</(p|li|td|th|h[234]|strong|b|em|i|a|blockquote)\s*>}g;
            $depth = 0 if $depth < 0;
            push @out, $line;
        } else {
            my $t = $line;
            $t =~ s/^\s+|\s+$//g;
            next if $t eq '' || $t eq '&nbsp;';
            push @out, $depth > 0 ? $line : "<p>$t</p>";
        }
    }
    $h = join "\n", @out;

    # پاکسازی نهایی عناصر خالی که ممکن است تازه ساخته شده باشند
    $h =~ s{<p>\s*</p>}{}gis;

    return $h;
}

# ---- محدوده‌ی محتوای اصلی ----------------------------------
sub extract_body {
    my ($src) = @_;

    # ساختار صفحات یکسان نیست: روی صفحات خدمات متن در
    # entry-content است و محفظه‌ی data-elementor-type مربوط به
    # قالب فوتر می‌شود؛ روی مقالات برعکس. پس همه‌ی محفظه‌های
    # ممکن امتحان و بلندترین خروجی انتخاب می‌شود.
    my @candidates;

    for my $marker ('class="entry-content', 'class="site-main', 'data-elementor-type=') {
        my $pos = 0;
        while ((my $i = index($src, $marker, $pos)) >= 0) {
            $pos = $i + 1;
            # محفظه‌هایی که در واقع هدر یا فوتر هستند را رد کن
            next if substr($src, $i, 400) =~ /data-elementor-post-type="(?:footer|header)"/;

            my $end = length($src);
            for my $stop ('<footer', 'data-elementor-post-type="footer"', 'class="site-footer') {
                my $j = index($src, $stop, $i);
                $end = $j if $j >= 0 && $j < $end;
            }
            next if $end - $i < 300;

            my $chunk = substr($src, $i, $end - $i);

            # برش از داخل یک تگ شروع شده، پس تا اولین تگ محتوایی
            # واقعی جلو برو. اگر چنین تگی نبود، این نامزد به درد
            # نمی‌خورد — وگرنه attribute های نیمه‌کاره متن می‌شوند.
            next unless $chunk =~ /(<(?:h[1-4]|p|ul|ol|table)\b)/i;
            $chunk = substr($chunk, $-[1]);

            push @candidates, clean_html($chunk);
        }
    }
    return '' unless @candidates;

    my ($best) = sort { length($b) <=> length($a) } @candidates;
    return $best;
}

# ---- اجرا ---------------------------------------------------
open my $out, '>:encoding(UTF-8)', $OUT or die "$OUT: $!";
print $out <<'HDR';
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
SET NAMES utf8mb4;

HDR

open my $tsv, '<:encoding(UTF-8)', $META or die "$META: $!";
<$tsv>;
my ($done, $empty, $chars) = (0, 0, 0);
my @report;

while (my $l = <$tsv>) {
    chomp $l;
    next unless length $l;
    my ($url) = split /\t/, $l, 2;

    (my $raw = $url) =~ s{^https://hamrahclinic\.ir}{};
    my $path = urldec($raw) || '/';

    # نام فایل آرشیو را از آدرس بساز (همان قاعده‌ی اسکریپت دانلود)
    (my $name = $raw) =~ s{^/}{};
    $name =~ s{/$}{};
    $name =~ s{/}{__}g;
    $name = '__HOME__' if $name eq '';
    $name = substr($name, 0, 120);
    my $file = "$RAW/$name.html";

    unless (-s $file) { push @report, "بی‌فایل   $path"; next; }

    open my $fh, '<:encoding(UTF-8)', $file or next;
    local $/; my $src = <$fh>; close $fh;

    my $body = extract_body($src);
    my $len  = length($body);

    if ($len < 200) { $empty++; push @report, sprintf("کم‌محتوا %5d  %s", $len, $path); next; }

    printf $out "UPDATE pages SET body = '%s' WHERE path = '%s';\n\n",
        sqlq($body), sqlq($path);
    $done++;
    $chars += $len;
}
close $tsv;
close $out;

printf "صفحات با متن: %d\n", $done;
printf "کم‌محتوا/بی‌فایل: %d\n", scalar(@report);
printf "میانگین طول متن: %d کاراکتر\n", $done ? $chars / $done : 0;
printf "حجم فایل: %.0f KB\n", (-s $OUT) / 1024;
print "\n", join("\n", @report), "\n" if @report;
