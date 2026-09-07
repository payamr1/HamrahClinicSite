#!/usr/bin/perl
# ============================================================
#  استخراج سؤالات متداول از متن صفحات
#
#  ورودی : db/seed/03-content.sql   (خروجی gen-content.pl)
#  خروجی : db/seed/04-faqs.sql      + بازنویسی 03-content.sql
#
#  چرا مهم است: بخش سؤالات متداول تنها منبع اسکیمای FAQPage است
#  و همان چیزی است که شانس نمایش در نتایج غنی گوگل را می‌سازد.
#  در سایت فعلی این محتوا فقط متن ساده بود و هیچ اسکیمایی نداشت.
#
#  ضمناً این بخش از ستون body حذف می‌شود، چون قالب آن را از جدول
#  faqs جداگانه رندر می‌کند و وگرنه دو بار روی صفحه می‌آمد.
#
#  ترتیب اجرا:  gen-pages.pl → gen-content.pl → gen-faqs.pl
# ============================================================
use strict;
use utf8;
use warnings;

binmode STDOUT, ':encoding(UTF-8)';

my $CONTENT = 'db/seed/03-content.sql';
my $OUT     = 'db/seed/04-faqs.sql';

sub sqlq {
    my ($s) = @_;
    $s = '' unless defined $s;
    $s =~ s/\\/\\\\/g;
    $s =~ s/'/''/g;
    return $s;
}
sub unsqlq {                      # برعکس sqlq برای خواندن فایل
    my ($s) = @_;
    $s =~ s/''/'/g;
    $s =~ s/\\\\/\\/g;
    return $s;
}
sub tidy {
    my ($s) = @_;
    $s =~ s/<[^>]+>//g;           # تگ‌ها را بردار
    $s =~ s/&nbsp;/ /g;
    # نشانه‌های جهت‌دهی نامرئی که در محتوای اصلی جا مانده‌اند
    $s =~ s/[\x{200E}\x{200F}\x{202A}-\x{202E}\x{2066}-\x{2069}]//g;
    $s =~ s/\s+/ /g;
    $s =~ s/^\s+|\s+$//g;
    return $s;
}
sub strip_number {                # «۱. » یا «1) » ابتدای سؤال
    my ($s) = @_;
    $s =~ s/^[\s\x{06F0}-\x{06F9}\x{0660}-\x{0669}0-9]{1,3}\s*[.．)\x{06D4}-]\s*//;
    return $s;
}

# ---- خواندن ------------------------------------------------
open my $in, '<:encoding(UTF-8)', $CONTENT or die "$CONTENT: $!";
local $/;
my $all = <$in>;
close $in;

my ($header) = $all =~ /\A(.*?)(?=UPDATE pages SET body)/s;
$header //= '';

open my $out, '>:encoding(UTF-8)', $OUT or die "$OUT: $!";
print $out <<'HDR';
-- ============================================================
--  همراه کلینیک — سؤالات متداول
--  تولید خودکار: perl db/seed/gen-faqs.pl
--
--  منبع اسکیمای FAQPage. هر ردیف به یک صفحه در جدول pages
--  وصل است و قالب، این بخش را جداگانه رندر می‌کند.
--
--  پیش‌نیاز: 01-pages.sql و 03-content.sql اجرا شده باشند.
-- ============================================================
SET NAMES utf8mb4;

-- اجرای مکرر نباید سؤال تکراری بسازد
DELETE FROM faqs;

HDR

my ($pagesWithFaq, $totalQ, $rewritten) = (0, 0, 0);
my @newBlocks;
my @report;

while ($all =~ /(UPDATE pages SET body = '(.*?)' WHERE path = '([^']+)';)/gs) {
    my ($whole, $bodyRaw, $pathRaw) = ($1, $2, $3);
    my $body = unsqlq($bodyRaw);
    my $path = unsqlq($pathRaw);

    # صفحات آرشیو قالب فهرست‌ساز دارند و متن ثابت ندارند، پس
    # اسکیمای FAQPage هم نباید بگیرند
    if ($path =~ m{^/(service|team|blog)/$}) {
        push @newBlocks, $whole;
        next;
    }

    # تیتر بخش سؤالات متداول.
    # متن تیتر ممکن است داخل <b> یا <strong> باشد، پس تگ‌ها را
    # قبل از تطبیق برمی‌داریم.
    # نکته: tidy() خودش regex اجرا می‌کند و $1 و @- را پاک می‌کند،
    # پس باید قبل از صدا زدنش مقادیر را برداریم.
    my ($hLevel, $start);
    while ($body =~ m{<h([234])>(.*?)</h\1>}gs) {
        my ($lvl, $txt, $off) = ($1, $2, $-[0]);
        next unless tidy($txt) =~ /(سوالات متداول|سؤالات متداول|پرسش‌های متداول|پرسش های متداول)/;
        ($hLevel, $start) = ($lvl, $off);
        last;
    }
    unless (defined $start) {
        push @newBlocks, $whole;
        next;
    }
    my $after = substr($body, $start);

    # بخش از خود تیتر شروع و تا اولین تیتر هم‌سطح یا بالاتر
    # ادامه دارد.
    #
    # نسخه‌ی قبلی یک lookahead منفی روی کل ادامه‌ی متن داشت که با
    # /s تقریباً همیشه شکست می‌خورد، پس بخش هیچ‌وقت تمام نمی‌شد و
    # باقی صفحه را هم می‌بلعید — نتیجه‌اش ۱۸ «سؤال» روی صفحه‌ای
    # که واقعاً ۶ تا داشت.
    #
    # اگر تیتر بخش و خود سؤال‌ها هم‌سطح باشند (مثلاً هر دو h3)،
    # مرز ساده بعد از اولین سؤال بسته می‌شود. پس تیترهایی که به
    # علامت سؤال ختم می‌شوند، خودشان سؤال‌اند و مرز محسوب نمی‌شوند.
    my $hEnd = index($after, "</h$hLevel>");
    $hEnd = $hEnd < 0 ? 0 : $hEnd + length("</h$hLevel>");

    my $section = $after;
    my $rest    = '';
    my $tail    = substr($after, $hEnd);

    while ($tail =~ m{<h([1-$hLevel])>(.*?)</h\1>}gs) {
        my ($txt, $off) = ($2, $-[0]);
        next if tidy($txt) =~ /[؟?]\s*$/;     # این خودش یک سؤال است
        my $cut  = $hEnd + $off;
        $section = substr($after, 0, $cut);
        $rest    = substr($after, $cut);
        last;
    }

    # جفت‌های سؤال/جواب
    # هر چهار الگو یک شرط مشترک دارند: سؤال باید به علامت سؤال ختم
    # شود. بدون این شرط، تیترهایی مثل «خدمات مرتبط» که داخل همان
    # بخش‌اند هم به‌عنوان پرسش وارد اسکیمای FAQPage می‌شدند.
    my @qa;
    while ($section =~ m{<(h[345])>(.*?)</\1>(.*?)(?=<h[1-5]>|\z)}gs) {
        my ($q, $a) = (tidy($2), $3);
        next unless $q =~ /[؟?]\s*$/;
        $q = strip_number($q);
        next if $q eq '' || length($q) < 8;
        # جواب: تگ‌های معنایی داخلش بماند اما تیترها نه
        $a =~ s{<h[1-6]>.*?</h[1-6]>}{}gs;
        $a =~ s/^\s+|\s+$//g;
        next if tidy($a) eq '' || length(tidy($a)) < 15;
        push @qa, [$q, $a];
    }

    # الگوی دوم: بعضی صفحات سؤال را در <p> شماره‌دار گذاشته‌اند
    # نه در تیتر، و پاراگراف بعدی جواب است.
    unless (@qa) {
        my @paras;
        while ($section =~ m{<p>(.*?)</p>}gs) { push @paras, $1 }
        for my $k (0 .. $#paras - 1) {
            my $q = tidy($paras[$k]);
            next unless $q =~ /^[\x{06F0}-\x{06F9}\x{0660}-\x{0669}0-9]{1,3}\s*[.．)\x{06D4}-]/;
            next unless $q =~ /[؟?]\s*$/;
            my $a = $paras[$k + 1];
            next if tidy($a) eq '' || length(tidy($a)) < 15;
            # پاراگراف بعدی نباید خودش سؤال باشد
            next if tidy($a) =~ /^[\x{06F0}-\x{06F9}\x{0660}-\x{0669}0-9]{1,3}\s*[.．)\x{06D4}-]/;
            push @qa, [strip_number($q), tidy($a)];
        }
    }

    # الگوی سوم: سؤال در <strong> بدون تگ والد، جواب در <p> بعدی
    unless (@qa) {
        while ($section =~ m{<strong>(.*?)</strong>\s*(.*?)(?=<strong>|<h[1-6]>|\z)}gs) {
            my ($q, $a) = (tidy($1), $2);
            next unless $q =~ /[؟?]\s*$/;
            $q = strip_number($q);
            next if length($q) < 8;
            $a =~ s/^\s+|\s+$//g;
            next if tidy($a) eq '' || length(tidy($a)) < 15;
            push @qa, [$q, $a];
        }
    }

    # الگوی چهارم: فهرست شماره‌دار، سؤال در <b> و جواب بعد از <br>
    unless (@qa) {
        while ($section =~ m{<li>\s*<(?:b|strong)>(.*?)</(?:b|strong)>\s*(?:<br>)?\s*(.*?)</li>}gs) {
            my ($q, $a) = (tidy($1), tidy($2));
            $q = strip_number($q);
            next if length($q) < 8 || length($a) < 15;
            push @qa, [$q, $a];
        }
    }

    unless (@qa) {
        push @newBlocks, $whole;
        push @report, "بدون جفت پرسش/پاسخ: $path";
        next;
    }

    $pagesWithFaq++;
    my $i = 0;
    for my $pair (@qa) {
        printf $out "INSERT INTO faqs (page_id, question, answer, sort)\n"
                  . "  SELECT id, '%s', '%s', %d FROM pages WHERE path = '%s';\n",
            sqlq($pair->[0]), sqlq($pair->[1]), ($i += 10), sqlq($path);
        $totalQ++;
    }
    print $out "\n";

    # بخش را از متن اصلی بردار تا دوبار نمایش داده نشود
    my $newBody = substr($body, 0, $start) . $rest;
    $newBody =~ s/\s+\z//;
    push @newBlocks, sprintf("UPDATE pages SET body = '%s' WHERE path = '%s';",
        sqlq($newBody), sqlq($path));
    $rewritten++;
}

close $out;

# ---- بازنویسی فایل محتوا ------------------------------------
open my $cw, '>:encoding(UTF-8)', $CONTENT or die "$CONTENT: $!";
print $cw $header;
print $cw join("\n\n", @newBlocks), "\n";
print $cw "\n-- صفحات آرشیو متن ثابت ندارند؛ قالبشان فهرست را از دیتابیس می‌سازد.\n";
print $cw "UPDATE pages SET body = NULL WHERE path IN ('/service/', '/team/', '/blog/');\n";
close $cw;

printf "صفحات با سؤالات متداول: %d\n", $pagesWithFaq;
printf "مجموع پرسش‌ها: %d\n", $totalQ;
printf "متن بازنویسی‌شده (بخش FAQ حذف شد): %d صفحه\n", $rewritten;
printf "حجم 04-faqs.sql: %.0f KB\n", (-s $OUT) / 1024;
print "\n", join("\n", @report), "\n" if @report;
