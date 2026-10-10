use strict;
use warnings;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';

# ============================================================
#  استخراج فهرست خدمات از فایل‌های seed
#
#  خروجی TSV:  بخش <tab> عنوان <tab> مسیر <tab> توضیح
#
#  چرا پارسر و نه regex ساده: ستون‌های INSERT در فایل‌های
#  مختلف یکسان نیستند — ۰۱ ستون lede و sort ندارد و ۰۵ و ۰۶
#  دارند. پس فهرست ستون‌ها از خود دستور خوانده می‌شود و مقدارها
#  به نامشان نگاشت می‌شوند، نه به جایگاهشان.
# ============================================================

my @FILES = glob('db/seed/*.sql');
die "هیچ فایل seedی پیدا نشد\n" unless @FILES;

my %svc;      # path => { title, desc }
my @order;
my %clinicName;
my %belongs;  # slug یا path => clinic slug
my @allSlugs;

for my $file (@FILES) {
    open my $fh, '<:encoding(UTF-8)', $file or die "$file: $!";
    local $/;
    my $sql = <$fh>;
    close $fh;

    parse_pages($sql);
    parse_clinics($sql);
    parse_assignments($sql);
}

# ---- خروجی ----
for my $path (@order) {
    my $s  = $svc{$path};
    my $cl = $belongs{ $s->{slug} } // $belongs{$path} // '';
    my $cn = $cl ? ($clinicName{$cl} // $cl) : 'بدون بخش';
    print join("\t", $cn, $s->{title}, $path, $s->{desc}), "\n";
}

# ------------------------------------------------------------

# یک تاپل SQL را به فهرست مقدارها می‌شکند، با احترام به رشته‌های
# تک‌کوتیشنی و '' به‌عنوان کوتیشن درون رشته
sub split_tuple {
    my ($t) = @_;
    my @out;
    my $cur = '';
    my $in  = 0;
    my $i   = 0;

    while ($i < length $t) {
        my $c = substr($t, $i, 1);
        if ($in) {
            if ($c eq "'" && substr($t, $i + 1, 1) eq "'") { $cur .= "'"; $i += 2; next; }
            if ($c eq "'") { $in = 0; $i++; next; }
            $cur .= $c;
        }
        else {
            if ($c eq "'") { $in = 1; $i++; next; }
            if ($c eq ',') { push @out, trim($cur); $cur = ''; $i++; next; }
            $cur .= $c;
        }
        $i++;
    }
    push @out, trim($cur);
    return @out;
}

sub trim { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }

sub parse_pages {
    my ($sql) = @_;

    while ($sql =~ /INSERT\s+INTO\s+pages\s*\(([^)]*)\)\s*VALUES\s*(.*?)(?:ON\s+DUPLICATE|;)/gis) {
        my ($colText, $rows) = ($1, $2);
        my @cols = map { trim($_) } split /,/, $colText;

        # هر تاپل سطح بالا
        while ($rows =~ /\(((?:[^()']|'(?:[^']|'')*')*)\)/gs) {
            my @vals = split_tuple($1);
            next unless @vals >= @cols;

            my %r;
            @r{@cols} = @vals[0 .. $#cols];
            next unless ($r{type} // '') eq 'service';

            my $path = $r{path} // next;
            next if exists $svc{$path};

            push @order, $path;
            push @allSlugs, $r{slug} // '';
            $svc{$path} = {
                slug  => $r{slug}      // '',
                title => $r{title}     // '',
                desc  => $r{meta_desc} // '',
            };
        }
    }
}

sub parse_clinics {
    my ($sql) = @_;

    # تاپل‌های clinics داخلشان (SELECT id FROM pages ...) دارند، پس
    # شکستن تاپل با شمارش پرانتز کار نمی‌کند. فقط دو مقدار اول لازم
    # است — slug و نام — و همان‌ها در ابتدای تاپل‌اند.
    while ($sql =~ /INSERT\s+INTO\s+clinics\s*\([^)]*\)\s*VALUES\s*(.*?)(?:ON\s+DUPLICATE\s+KEY|;)/gis) {
        my $rows = $1;
        while ($rows =~ /\(\s*'([a-z][a-z0-9\-]*)'\s*,\s*'((?:[^']|'')*)'/gs) {
            my ($slug, $name) = ($1, $2);
            $name =~ s/''/'/g;
            $clinicName{$slug} = $name;
        }
    }
}

sub parse_assignments {
    my ($sql) = @_;

    # هر UPDATE که clinic_id را از روی slug ست می‌کند
    while ($sql =~ /UPDATE\s+pages(?:\s+p)?\s+SET\s+clinic_id\s*=\s*\(SELECT\s+id\s+FROM\s+clinics\s+WHERE\s+slug\s*=\s*'([a-z\-]+)'\)\s*(.*?);/gis) {
        my ($cl, $where) = ($1, $2);

        # IN ('...','...')  یا  = '...'
        my @vals = ($where =~ /'([^']+)'/g);

        if ($where =~ /p?\.?path/i) {
            $belongs{$_} = $cl for @vals;
        }
        elsif ($where =~ /LIKE/i) {
            # شرط الگویی — بخش زخم این‌طور وصل می‌شود
            my @likes = ($where =~ /LIKE\s*'%([^%']+)%'/g);
            my @exact = ($where =~ /p?\.?slug\s*=\s*'([^']+)'/g);
            for my $s (@allSlugs) {
                next if !$s || exists $belongs{$s};
                $belongs{$s} = $cl if grep { $s eq $_ } @exact;
                $belongs{$s} = $cl if grep { index($s, $_) >= 0 } @likes;
            }
        }
        else {
            $belongs{$_} = $cl for @vals;
        }
    }
}
