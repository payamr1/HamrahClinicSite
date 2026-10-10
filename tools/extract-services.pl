use strict;
use warnings;
use utf8;
binmode STDOUT, ':encoding(UTF-8)';

# ---- ۱. صفحه‌های خدمت از 01-pages.sql ----
open my $p, '<:encoding(UTF-8)', 'db/seed/01-pages.sql' or die $!;
local $/;
my $pages = <$p>;
close $p;

my %svc;    # slug => { path, title, desc }
my @order;

while ($pages =~ /\('([^']*)',\s*'[^']*',\s*'service',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'((?:[^']|'')*)'\)/g) {
    my ($path, $slug, $title, $metaTitle, $desc) = ($1, $2, $3, $4, $5);
    $desc =~ s/''/'/g;
    next if exists $svc{$slug};
    $svc{$slug} = { path => $path, title => $title, desc => $desc };
    push @order, $slug;
}

# ---- ۲. اینکه هر صفحه زیر کدام بخش است ----
open my $c, '<:encoding(UTF-8)', 'db/seed/02-clinics-doctors.sql' or die $!;
my $clin = <$c>;
close $c;

# نام بخش‌ها
my %clinicName;
while ($clin =~ /\('([a-z\-]+)',\s*'([^']*)',\s*'([^']*)',/g) {
    $clinicName{$1} = $2;
}

my %belongs;   # slug یا path => clinic slug

# حالت الف: UPDATE ... WHERE p.slug IN (...)
while ($clin =~ /clinics WHERE slug = '([a-z\-]+)'\)\s*\n\s*WHERE p\.type = 'service' AND p\.slug IN\s*\n?\s*\(((?:[^)]|\n)*?)\);/g) {
    my ($cl, $list) = ($1, $2);
    $belongs{$_} = $cl for ($list =~ /'([^']+)'/g);
}

# حالت ب: UPDATE ... WHERE p.path IN (...)
while ($clin =~ /clinics WHERE slug = '([a-z\-]+)'\)\s*\n\s*WHERE p\.path IN \(((?:[^)]|\n)*?)\);/g) {
    my ($cl, $list) = ($1, $2);
    $belongs{$_} = $cl for ($list =~ /'([^']+)'/g);
}

# حالت پ: UPDATE ... WHERE p.path = '...'
while ($clin =~ /clinics WHERE slug = '([a-z\-]+)'\)\s*\n\s*WHERE p\.path = '([^']+)';/g) {
    $belongs{$2} = $1;
}

# حالت ت: UPDATE pages SET clinic_id ... WHERE path = '...'
while ($clin =~ /clinics WHERE slug = '([a-z\-]+)'\)\s*\n\s*WHERE path = '([^']+)';/g) {
    $belongs{$2} = $1;
}

# حالت ث: WHERE p.slug = '...'  (تک‌اسلاگ)
while ($clin =~ /clinics WHERE slug = '([a-z\-]+)'\)\s*\n\s*WHERE p\.slug = '([^']+)';/g) {
    $belongs{$2} = $1;
}

# حالت ج: شرط LIKE روی اسلاگ — بخش زخم این‌طور وصل می‌شود
while ($clin =~ /clinics WHERE slug = '([a-z\-]+)'\)\s*\n\s*WHERE p\.type = 'service' AND \(((?:[^)]|\n)*?)\);/g) {
    my ($cl, $cond) = ($1, $2);
    my @likes = ($cond =~ /LIKE '%([^%']+)%'/g);
    my @exact = ($cond =~ /p\.slug = '([^']+)'/g);

    for my $slug (@order) {
        next if exists $belongs{$slug};
        if (grep { $slug eq $_ } @exact) { $belongs{$slug} = $cl; next; }
        if (grep { index($slug, $_) >= 0 } @likes) { $belongs{$slug} = $cl; }
    }
}

# ---- ۳. خروجی TSV ----
for my $slug (@order) {
    my $s  = $svc{$slug};
    my $cl = $belongs{$slug} // $belongs{ $s->{path} } // '';
    my $cn = $cl ? ($clinicName{$cl} // $cl) : 'بدون بخش';
    print join("\t", $cn, $s->{title}, $s->{path}, $s->{desc}), "\n";
}
