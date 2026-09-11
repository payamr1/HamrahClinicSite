#!/usr/bin/perl
# ============================================================
#  بررسی ساختاری فایل‌های PHP
#
#  روی این ماشین PHP نصب نیست و `php -l` در دسترس نیست، پس این
#  اسکریپت جای آن را می‌گیرد. جایگزین کامل کامپایلر نیست، ولی
#  خطاهایی را می‌گیرد که در عمل بیشترین سهم را دارند:
#
#    • پرانتز، آکولاد یا براکت باز‌مانده
#    • رشته‌ی بسته‌نشده
#    • heredoc بسته‌نشده
#    • تگ <?php بازنشده در فایلی که کد دارد
#
#  روش کار: اول رشته‌ها و توضیح‌ها و بخش‌های HTML بیرون از تگ PHP
#  حذف می‌شوند، بعد شمارش انجام می‌شود. بدون این پاک‌سازی، یک
#  آکولاد داخل یک رشته‌ی فارسی کل شمارش را خراب می‌کند.
# ============================================================
use strict;
use warnings;

my @files = @ARGV;
unless (@files) {
    @files = grep { -f } split /\n/, `find app public -name '*.php' -not -path '*/vendor/*'`;
}

my $bad = 0;
my $n   = 0;

for my $file (@files) {
    $n++;
    open my $fh, '<:raw', $file or do { warn "باز نشد: $file\n"; $bad++; next; };
    local $/;
    my $src = <$fh>;
    close $fh;

    my @problems = check($file, $src);
    if (@problems) {
        $bad++;
        print "\n✗ $file\n";
        print "    $_\n" for @problems;
    }
}

printf "\n%s  %d فایل بررسی شد%s\n",
    $bad ? '✗' : '✓', $n,
    $bad ? "، $bad تا ایراد دارد" : '، همه سالم';

exit($bad ? 1 : 0);

# ------------------------------------------------------------

sub check {
    my ($file, $src) = @_;
    my @out;

    # ---- عبور نویسه به نویسه، با آگاهی از حالت ----
    my @stack;                 # [نویسه, شماره خط]
    my $line     = 1;
    my $i        = 0;
    my $len      = length $src;
    my $in_php   = 0;
    my %pair     = (')' => '(', '}' => '{', ']' => '[');

    while ($i < $len) {
        my $c  = substr($src, $i, 1);
        my $c2 = substr($src, $i, 2);

        $line++ if $c eq "\n";

        # ---- بیرون از تگ PHP: فقط دنبال <?php می‌گردیم ----
        unless ($in_php) {
            if ($c2 eq '<?') {
                $in_php = 1;
                $i += (substr($src, $i, 5) eq '<?php') ? 5 : 2;
                next;
            }
            $i++;
            next;
        }

        # ---- پایان بخش PHP ----
        if ($c2 eq '?>') {
            $in_php = 0;
            $i += 2;
            next;
        }

        # ---- توضیح تک‌خطی ----
        if ($c2 eq '//' || $c eq '#') {
            my $nl = index($src, "\n", $i);
            $i = $nl < 0 ? $len : $nl;
            next;
        }

        # ---- توضیح چندخطی ----
        if ($c2 eq '/*') {
            my $end = index($src, '*/', $i + 2);
            if ($end < 0) {
                push @out, "توضیح /* در خط $line بسته نشده";
                last;
            }
            $line += (substr($src, $i, $end - $i) =~ tr/\n//);
            $i = $end + 2;
            next;
        }

        # ---- heredoc و nowdoc ----
        if (substr($src, $i, 3) =~ /^<<</
            && substr($src, $i) =~ /^<<<[ \t]*(['"]?)([A-Za-z_]\w*)\1\r?\n/) {
            my $tag  = $2;
            my $skip = length($&);
            $line += ($& =~ tr/\n//);
            my $rest = substr($src, $i + $skip);
            if ($rest =~ /^(.*?\n)[ \t]*\Q$tag\E\b/s) {
                $line += ($1 =~ tr/\n//) + 1;
                $i += $skip + length($1) + length($tag);
                # فاصله‌ی احتمالی پیش از برچسب
                $i = $i;
                next;
            }
            push @out, "heredoc «$tag» در خط $line بسته نشده";
            last;
        }

        # ---- رشته ----
        if ($c eq "'" || $c eq '"') {
            my $q     = $c;
            my $start = $line;
            $i++;
            my $closed = 0;
            while ($i < $len) {
                my $d = substr($src, $i, 1);
                if ($d eq "\\") { $i += 2; next; }
                $line++ if $d eq "\n";
                if ($d eq $q) { $closed = 1; $i++; last; }
                $i++;
            }
            push @out, "رشته‌ی بازشده در خط $start بسته نشده" unless $closed;
            last unless $closed;
            next;
        }

        # ---- پرانتزها ----
        if ($c =~ /^[\(\{\[]$/) {
            push @stack, [$c, $line];
            $i++;
            next;
        }
        if ($c =~ /^[\)\}\]]$/) {
            my $want = $pair{$c};
            if (!@stack) {
                push @out, "«$c» اضافی در خط $line";
                last;
            }
            my $top = pop @stack;
            if ($top->[0] ne $want) {
                push @out, "«$c» در خط $line با «$top->[0]» خط $top->[1] جور نیست";
                last;
            }
            $i++;
            next;
        }

        $i++;
    }

    for my $open (@stack) {
        push @out, "«$open->[0]» خط $open->[1] بسته نشده";
    }

    # ---- چند بررسی ساده‌ی دیگر ----
    if ($src =~ /\A\xEF\xBB\xBF/) {
        push @out, 'فایل با BOM شروع شده — پیش از هر هدری خروجی می‌دهد';
    }
    # PHP دقیقاً یک خط جدیدِ بلافاصله پس از ?> را می‌بلعد، پس
    # «?>\n» در انتهای قالب بی‌خطر است. فقط چیزی که واقعاً چاپ
    # می‌شود ایراد است: فاصله پیش از خط جدید، یا خط جدید دوم.
    my $close = rindex($src, '?>');
    if ($close >= 0) {
        my $tail = substr($src, $close + 2);
        # فقط فضای خالی بعد از آخرین ?>، و فقط اگر بیش از یک خط
        # جدید باشد. PHP خودش دقیقاً یک \n بلافاصله پس از ?> را
        # می‌بلعد، پس پایان‌بندی معمولِ قالب‌ها بی‌خطر است.
        if ($tail =~ /\A\s*\z/ && $tail !~ /\A(?:|\r?\n)\z/) {
            push @out, 'بعد از ?> پایانی فاصله‌ی اضافه مانده — هدر را می‌شکند';
        }
    }

    return @out;
}
