use strict;
use warnings;
use utf8;

# ============================================================
#  ساخت word/document.xml برای فهرست خدمات همراه کلینیک
#
#  چرا دستی: روی این ماشین نه Node هست نه Python نه LibreOffice،
#  پس docx-js در دسترس نیست. یک .docx در عمل یک ZIP از چند فایل
#  XML است و همان را می‌سازیم.
#
#  نکته‌ی راست‌به‌چپ: سه چیز لازم است و هر سه جداست —
#    <w:bidi/>  جهت پاراگراف
#    <w:rtl/>   جهت متن داخل ران
#    <w:bidiVisual/>  ترتیب ستون‌های جدول
#  نبودن هرکدام یکی از سه نشانه‌ی «فارسیِ چپ‌چین» را می‌سازد.
# ============================================================

my $TSV = shift or die "usage: gen.pl services.tsv > document.xml\n";

# ---- پاک‌سازی عنوان‌ها -------------------------------------
# عنوان‌های دیتابیس برای سئو نوشته شده‌اند: ایموجی، دنباله‌ی
# «در تهران»، و موجودیت HTML. برای یک سند چاپی باید نام تمیز باشد.
my %OVERRIDE = (
    'متخصص قلب و عروق در تجریش تهران'                                              => 'ویزیت تخصصی قلب و عروق',
    'خدمات مشاوره و درمان آنکولوژی در همراه کلینیک'                                 => 'مشاوره و درمان آنکولوژی',
    'بخش تخصصی تغذیه و رژیم‌درمانی بالینی همراه کلینیک'                             => 'تغذیه و رژیم‌درمانی بالینی',
    'بخش طب ایرانی همراه کلینیک | طب سنتی مبتنی بر شواهد برای بیماران سرطانی'       => 'طب ایرانی',
    'مرکز تخصصی درمان زخم‌های مزمن و دیابتی'                                        => 'معرفی کلینیک زخم',
    'مرکز تخصصی بیماری‌های عفونی و گرمسیری'                                         => 'معرفی کلینیک عفونی',
    'کلینیک غدد'                                                                    => 'معرفی کلینیک غدد',
    'کلینیک اورولوژی'                                                               => 'معرفی کلینیک اورولوژی',
    'کلینیک واریس'                                                                  => 'معرفی کلینیک واریس',
    'کلینیک قلب کودکان'                                                             => 'قلب کودکان',
);

sub clean_title {
    my ($t) = @_;
    $t =~ s/&#8211;/–/g;
    $t =~ s/&#8212;/—/g;
    $t =~ s/&amp;/&/g;
    $t =~ s/^\s*[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{FE0F}]+\s*//;   # ایموجی ابتدای عنوان
    $t =~ s/\s+/ /g;
    $t =~ s/^\s+|\s+$//g;

    return $OVERRIDE{$t} if exists $OVERRIDE{$t};

    $t =~ s/\s*در کلینیک غدد همراه تهران$//;
    $t =~ s/\s*در همراه کلینیک$//;
    $t =~ s/\s*همراه کلینیک$//;
    $t =~ s/\s*در تجریش تهران$//;
    $t =~ s/^بخش\s+//;
    $t =~ s/^خدمات\s+//;
    return $t;
}

# توضیح‌های دیتابیس meta description هستند و ۱۸ تای آن‌ها وسط
# جمله بریده شده‌اند. در یک سند خواندنی، جمله‌ی ناتمام بد است؛ پس
# تا آخرین نقطه می‌بریم. اگر چیزی نماند، همان را با سه‌نقطه
# می‌گذاریم تا دست‌کم معلوم باشد ادامه داشته.
sub trim_sentence {
    my ($d) = @_;
    $d =~ s/\s+/ /g;
    $d =~ s/^\s+|\s+$//g;
    return $d if $d =~ /[.!?؟]$/;

    my $cut = $d;
    if ($cut =~ /^(.*[.!?؟])\s/s) {
        my $kept = $1;
        return $kept if length($kept) >= 60;
    }
    return $d . ' …';
}

sub x {                      # گریز XML
    my ($s) = @_;
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    return $s;
}

# ---- خواندن داده --------------------------------------------
open my $fh, '<:encoding(UTF-8)', $TSV or die "$TSV: $!";
my (@groups, %byGroup);
while (my $line = <$fh>) {
    chomp $line;
    my ($clinic, $title, $path, $desc) = split /\t/, $line, 4;
    next unless defined $desc;
    next if $clinic eq 'بدون بخش';          # صفحه‌ی فهرست، خودش خدمت نیست

    push @groups, $clinic unless exists $byGroup{$clinic};
    push @{ $byGroup{$clinic} }, {
        title => clean_title($title),
        desc  => trim_sentence($desc),
    };
}
close $fh;

# صفحه‌ی معرفی هر بخش باید اول فهرست همان بخش بیاید، نه وسطش
for my $g (keys %byGroup) {
    my @list = @{ $byGroup{$g} };
    my @intro = grep {     $_->{title} =~ /^معرفی/ } @list;
    my @rest  = grep { not $_->{title} =~ /^معرفی/ } @list;
    $byGroup{$g} = [ @intro, @rest ];
}

# بخش‌ها به ترتیب تعداد خدمت، بزرگ‌ها اول
@groups = sort { @{ $byGroup{$b} } <=> @{ $byGroup{$a} } or $a cmp $b } @groups;

my $total = 0;
$total += @{ $byGroup{$_} } for @groups;

# ---- سازنده‌های XML ------------------------------------------
sub run {
    my ($text, %o) = @_;
    my $rpr = '<w:rtl/>';
    $rpr .= '<w:b/><w:bCs/>'                if $o{bold};
    $rpr .= '<w:color w:val="' . $o{color} . '"/>' if $o{color};
    $rpr .= '<w:sz w:val="' . $o{size} . '"/><w:szCs w:val="' . $o{size} . '"/>' if $o{size};
    return '<w:r><w:rPr>' . $rpr . '</w:rPr><w:t xml:space="preserve">' . x($text) . '</w:t></w:r>';
}

sub para {
    my ($content, %o) = @_;
    my $ppr = '<w:bidi/>';
    $ppr .= '<w:pStyle w:val="' . $o{style} . '"/>' if $o{style};
    $ppr .= '<w:jc w:val="' . ($o{jc} // 'both') . '"/>';
    $ppr .= '<w:spacing w:before="' . ($o{before} // 0) . '" w:after="' . ($o{after} // 120)
          . '" w:line="300" w:lineRule="auto"/>';
    $ppr .= '<w:ind w:start="' . $o{indent} . '" w:left="' . $o{indent} . '"/>' if $o{indent};
    if ($o{rule}) {
        $ppr .= '<w:pBdr><w:bottom w:val="single" w:sz="6" w:space="6" w:color="4EC3A9"/></w:pBdr>';
    }
    return '<w:p><w:pPr>' . $ppr . '</w:pPr>' . $content . '</w:p>';
}

sub cell {
    my ($text, $w, %o) = @_;
    my $shade = $o{head} ? '<w:shd w:val="clear" w:color="auto" w:fill="24408D"/>' : '';
    return '<w:tc><w:tcPr><w:tcW w:w="' . $w . '" w:type="dxa"/>' . $shade
         . '<w:vAlign w:val="center"/></w:tcPr>'
         . para(run($text, bold => $o{head} ? 1 : 0, color => $o{head} ? 'FFFFFF' : undef),
                jc => $o{jc} // 'right', after => 40)
         . '</w:tc>';
}

# ============================================================
my @body;

# ---- سربرگ --------------------------------------------------
push @body, para(run('فهرست خدمات همراه کلینیک', bold => 1, size => 44, color => '24408D'),
                 jc => 'center', after => 60);
push @body, para(run('کلینیک فوق تخصصی قلب و عروق، آنکولوژی و شیمی‌درمانی', size => 24, color => '4A5673'),
                 jc => 'center', after => 40);
push @body, para(run('تهران، تجریش، خیابان شریعتی، نرسیده به میدان قدس، کوچه مهنا ۱، پلاک ۶  ·  ۰۲۱۹۱۳۰۳۱۳۲',
                 size => 20, color => '7C88A3'), jc => 'center', after => 240, rule => 1);

push @body, para(run('در مجموع ' . fa($total) . ' خدمت درمانی در ' . fa(scalar @groups) . ' بخش تخصصی.',
                 size => 22), jc => 'center', after => 300);

# ---- جدول خلاصه ---------------------------------------------
my $tbl = '<w:tbl><w:tblPr><w:tblW w:w="9000" w:type="dxa"/><w:bidiVisual/>'
        . '<w:tblBorders>'
        . join('', map { '<w:' . $_ . ' w:val="single" w:sz="4" w:space="0" w:color="DCE3EC"/>' }
                   qw(top left bottom right insideH insideV))
        . '</w:tblBorders>'
        . '<w:tblCellMar><w:top w:w="80" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/>'
        . '<w:start w:w="120" w:type="dxa"/><w:end w:w="120" w:type="dxa"/></w:tblCellMar>'
        . '</w:tblPr>'
        . '<w:tblGrid><w:gridCol w:w="6600"/><w:gridCol w:w="2400"/></w:tblGrid>';

$tbl .= '<w:tr><w:trPr><w:tblHeader/></w:trPr>'
      . cell('بخش تخصصی', 6600, head => 1)
      . cell('تعداد خدمت', 2400, head => 1, jc => 'center') . '</w:tr>';

for my $g (@groups) {
    my $n = scalar @{ $byGroup{$g} };
    $tbl .= '<w:tr>' . cell($g, 6600) . cell(fa($n), 2400, jc => 'center') . '</w:tr>';
}
$tbl .= '</w:tbl>';
push @body, $tbl;

push @body, para('', after => 200);

# ---- بخش‌ها --------------------------------------------------
my $gi = 0;
for my $g (@groups) {
    $gi++;
    my $items = $byGroup{$g};

    push @body, '<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:br w:type="page"/></w:r></w:p>' if $gi > 1;

    push @body, para(run($g, bold => 1, size => 32, color => '24408D'),
                     style => 'Heading1', jc => 'right', before => 120, after => 40);
    push @body, para(run(fa(scalar @$items) . ' خدمت', size => 19, color => '7C88A3'),
                     jc => 'right', after => 180, rule => 1);

    my $i = 0;
    for my $s (@$items) {
        $i++;
        push @body, para(run(fa($i) . '. ' . $s->{title}, bold => 1, size => 23),
                         jc => 'right', before => 140, after => 20);
        push @body, para(run($s->{desc}, size => 20, color => '4A5673'),
                         jc => 'both', indent => 280, after => 60);
    }
}

# ---- پانویس --------------------------------------------------
push @body, para(run('این فهرست از پایگاه داده‌ی وب‌سایت hamrahclinic.ir استخراج شده است.',
                 size => 18, color => '7C88A3'), jc => 'center', before => 300, after => 0);

# ---- ارقام فارسی ---------------------------------------------
sub fa {
    my ($n) = @_;
    my @d = ('۰','۱','۲','۳','۴','۵','۶','۷','۸','۹');
    $n =~ s/(\d)/$d[$1]/g;
    return $n;
}

# ---- خروجی ---------------------------------------------------
binmode STDOUT, ':encoding(UTF-8)';
print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' . "\n";
print '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">';
print '<w:body>';
print join('', @body);
print '<w:sectPr><w:bidi/>'
    . '<w:pgSz w:w="11906" w:h="16838"/>'
    . '<w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134"'
    . ' w:header="708" w:footer="708" w:gutter="0"/>'
    . '</w:sectPr>';
print '</w:body></w:document>';
