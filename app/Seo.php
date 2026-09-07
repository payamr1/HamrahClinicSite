<?php
declare(strict_types=1);

/**
 * تولید تگ‌های سئو و اسکیما.
 *
 * دو قاعده‌ی حیاتی در این کلاس:
 *
 *  ۱. canonical همیشه به دامنه‌ی اصلی (hamrahclinic.ir) اشاره می‌کند،
 *     حتی وقتی سایت روی new.hamrahclinic.ir اجرا می‌شود. اگر این
 *     رعایت نشود، نسخه‌ی آزمایشی با سایت اصلی محتوای تکراری می‌سازد.
 *
 *  ۲. روی محیط staging کل سایت noindex می‌شود.
 */
final class Seo
{
    public function __construct(private array $config, private array $settings) {}

    public function canonicalHost(): string
    {
        return $this->config['canonical_host'] ?? 'hamrahclinic.ir';
    }

    public function canonicalUrl(array $page): string
    {
        if (!empty($page['canonical'])) {
            return $page['canonical'];
        }
        // مسیر باید دوباره encode شود تا آدرس فارسی معتبر بماند
        $path = $this->encodePath($page['path'] ?? '/');
        return 'https://' . $this->canonicalHost() . $path;
    }

    /** هر بخش مسیر جداگانه encode می‌شود تا اسلش‌ها سالم بمانند */
    public function encodePath(string $path): string
    {
        $parts = explode('/', $path);
        return implode('/', array_map('rawurlencode', $parts));
    }

    public function isStaging(): bool
    {
        return ($this->config['env'] ?? 'staging') !== 'production';
    }

    public function shouldNoindex(array $page = []): bool
    {
        if (!empty($this->config['force_noindex']) && $this->isStaging()) {
            return true;
        }
        return !empty($page['noindex']);
    }

    public function robotsValue(array $page = []): string
    {
        return $this->shouldNoindex($page)
            ? 'noindex, nofollow'
            : 'index, follow, max-image-preview:large, max-snippet:-1';
    }

    // ---------------------------------------------------------------
    //  اسکیما
    // ---------------------------------------------------------------

    /** اسکیمای پایه‌ی کلینیک — روی همه‌ی صفحات */
    public function clinicSchema(): array
    {
        $host = $this->canonicalHost();
        return [
            '@type'       => 'MedicalClinic',
            '@id'         => "https://$host/#clinic",
            'name'        => $this->settings['site_name'] ?? 'همراه کلینیک',
            'url'         => "https://$host/",
            'telephone'   => '+98' . ltrim((string) ($this->settings['phone_raw'] ?? '02191303132'), '0'),
            'address'     => [
                '@type'           => 'PostalAddress',
                'addressCountry'  => 'IR',
                'addressLocality' => 'تهران',
                'addressRegion'   => 'تهران',
                'streetAddress'   => $this->settings['address'] ?? '',
            ],
            'medicalSpecialty' => ['Cardiovascular', 'Oncology', 'Hematologic', 'Psychiatric', 'Dietetics'],
            'openingHoursSpecification' => [
                [
                    '@type'     => 'OpeningHoursSpecification',
                    'dayOfWeek' => ['Saturday', 'Sunday', 'Monday', 'Tuesday', 'Wednesday'],
                    'opens'     => '08:00',
                    'closes'    => '20:00',
                ],
                [
                    '@type'     => 'OpeningHoursSpecification',
                    'dayOfWeek' => ['Thursday'],
                    'opens'     => '08:00',
                    'closes'    => '13:00',
                ],
            ],
        ];
    }

    public function breadcrumbSchema(array $trail): array
    {
        $host  = $this->canonicalHost();
        $items = [];
        $i = 1;
        foreach ($trail as $label => $path) {
            $items[] = [
                '@type'    => 'ListItem',
                'position' => $i++,
                'name'     => $label,
                'item'     => $path === null ? null : "https://$host" . $this->encodePath($path),
            ];
        }
        return ['@type' => 'BreadcrumbList', 'itemListElement' => $items];
    }

    /** از جدول faqs — همان چیزی که شانس نتایج غنی می‌سازد */
    public function faqSchema(array $faqs): ?array
    {
        if ($faqs === []) {
            return null;
        }
        return [
            '@type'      => 'FAQPage',
            'mainEntity' => array_map(fn(array $f) => [
                '@type'          => 'Question',
                'name'           => $f['question'],
                'acceptedAnswer' => ['@type' => 'Answer', 'text' => strip_tags($f['answer'])],
            ], $faqs),
        ];
    }

    public function physicianSchema(array $doc): array
    {
        $host = $this->canonicalHost();
        $s = [
            '@type'    => 'Physician',
            'name'     => $doc['name'],
            'jobTitle' => $doc['specialty'],
            'memberOf' => ['@id' => "https://$host/#clinic"],
        ];
        if (!empty($doc['path']))       { $s['url']   = "https://$host" . $this->encodePath($doc['path']); }
        if (!empty($doc['photo']))      { $s['image'] = "https://$host/assets/uploads/" . $doc['photo']; }
        if (!empty($doc['license_no'])) {
            $s['identifier'] = [
                '@type' => 'PropertyValue',
                'name'  => 'شماره نظام پزشکی',
                'value' => $doc['license_no'],
            ];
        }
        return $s;
    }

    public function articleSchema(array $page, ?array $author): array
    {
        $host = $this->canonicalHost();
        $s = [
            '@type'         => 'Article',
            'headline'      => $page['title'],
            'description'   => $page['meta_desc'],
            'mainEntityOfPage' => ['@type' => 'WebPage', '@id' => $this->canonicalUrl($page)],
            'publisher'     => ['@id' => "https://$host/#clinic"],
        ];
        if (!empty($page['published_at'])) { $s['datePublished'] = $page['published_at']; }
        if (!empty($page['updated_at']))   { $s['dateModified']  = substr($page['updated_at'], 0, 10); }
        if ($author !== null)              { $s['author']        = $this->physicianSchema($author); }
        return $s;
    }

    /** بسته‌بندی نهایی در یک گراف */
    public function graph(array $nodes): string
    {
        $nodes = array_values(array_filter($nodes));
        return json_encode(
            ['@context' => 'https://schema.org', '@graph' => $nodes],
            JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
        );
    }
}
