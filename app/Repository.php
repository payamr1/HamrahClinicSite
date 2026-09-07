<?php
declare(strict_types=1);

/**
 * همه‌ی کوئری‌های خواندنی سایت. قالب‌ها مستقیماً SQL نمی‌زنند.
 */
final class Repository
{
    public function __construct(private Database $db) {}

    // ---- صفحات ----------------------------------------------------

    public function pageByPath(string $path): ?array
    {
        return $this->db->one('SELECT * FROM pages WHERE path = ? LIMIT 1', [$path]);
    }

    public function pageById(int $id): ?array
    {
        return $this->db->one('SELECT * FROM pages WHERE id = ? LIMIT 1', [$id]);
    }

    /** @return array<int,array> */
    public function pagesOfType(string $type, int $limit = 100, int $offset = 0): array
    {
        return $this->db->all(
            'SELECT * FROM pages
              WHERE type = ? AND status = ?
              ORDER BY sort ASC, published_at DESC, id DESC
              LIMIT ' . (int) $limit . ' OFFSET ' . (int) $offset,
            [$type, 'published']
        );
    }

    public function countOfType(string $type): int
    {
        return (int) $this->db->value(
            'SELECT COUNT(*) FROM pages WHERE type = ? AND status = ?',
            [$type, 'published']
        );
    }

    /** آدرس همه‌ی صفحات منتشرشده — برای sitemap */
    public function allPublishedPaths(): array
    {
        return $this->db->all(
            'SELECT path, type, updated_at FROM pages
              WHERE status = ? AND noindex = 0
              ORDER BY type ASC, id ASC',
            ['published']
        );
    }

    // ---- کلینیک‌ها -------------------------------------------------

    public function clinics(bool $activeOnly = true): array
    {
        $sql = 'SELECT c.*, p.path AS page_path,
                       (SELECT COUNT(*) FROM pages s WHERE s.clinic_id = c.id AND s.type = "service" AND s.status = "published") AS service_count,
                       (SELECT COUNT(*) FROM doctor_clinic dc WHERE dc.clinic_id = c.id) AS doctor_count
                  FROM clinics c
                  LEFT JOIN pages p ON p.id = c.page_id';
        if ($activeOnly) {
            $sql .= ' WHERE c.is_active = 1';
        }
        $sql .= ' ORDER BY c.sort ASC, c.id ASC';
        return $this->db->all($sql);
    }

    public function clinicById(int $id): ?array
    {
        return $this->db->one('SELECT * FROM clinics WHERE id = ? LIMIT 1', [$id]);
    }

    /** خدمات زیرمجموعه‌ی یک کلینیک */
    public function servicesOfClinic(int $clinicId, int $limit = 24): array
    {
        return $this->db->all(
            'SELECT * FROM pages
              WHERE clinic_id = ? AND type = ? AND status = ?
              ORDER BY sort ASC, title ASC
              LIMIT ' . (int) $limit,
            [$clinicId, 'service', 'published']
        );
    }

    // ---- پزشکان ---------------------------------------------------

    public function doctors(int $limit = 30): array
    {
        return $this->db->all(
            'SELECT d.*, p.path
               FROM doctors d
               LEFT JOIN pages p ON p.id = d.page_id
              WHERE d.is_active = 1
              ORDER BY d.is_founder DESC, d.sort ASC, d.id ASC
              LIMIT ' . (int) $limit
        );
    }

    public function doctorByPageId(int $pageId): ?array
    {
        return $this->db->one(
            'SELECT d.*, p.path FROM doctors d
               LEFT JOIN pages p ON p.id = d.page_id
              WHERE d.page_id = ? LIMIT 1',
            [$pageId]
        );
    }

    public function doctorsOfClinic(int $clinicId): array
    {
        return $this->db->all(
            'SELECT d.*, p.path
               FROM doctors d
               JOIN doctor_clinic dc ON dc.doctor_id = d.id
               LEFT JOIN pages p ON p.id = d.page_id
              WHERE dc.clinic_id = ? AND d.is_active = 1
              ORDER BY d.is_founder DESC, d.sort ASC',
            [$clinicId]
        );
    }

    public function clinicsOfDoctor(int $doctorId): array
    {
        return $this->db->all(
            'SELECT c.*, p.path AS page_path
               FROM clinics c
               JOIN doctor_clinic dc ON dc.clinic_id = c.id
               LEFT JOIN pages p ON p.id = c.page_id
              WHERE dc.doctor_id = ?
              ORDER BY c.sort ASC',
            [$doctorId]
        );
    }

    // ---- مقالات ---------------------------------------------------

    public function posts(int $limit = 12, int $offset = 0): array
    {
        return $this->db->all(
            'SELECT p.*, d.name AS author_name, d.specialty AS author_specialty,
                    d.photo AS author_photo, dp.path AS author_path
               FROM pages p
               LEFT JOIN page_author pa ON pa.page_id = p.id
               LEFT JOIN doctors d      ON d.id = pa.doctor_id
               LEFT JOIN pages dp       ON dp.id = d.page_id
              WHERE p.type = ? AND p.status = ?
              ORDER BY p.published_at DESC, p.id DESC
              LIMIT ' . (int) $limit . ' OFFSET ' . (int) $offset,
            ['post', 'published']
        );
    }

    public function authorOfPage(int $pageId): ?array
    {
        return $this->db->one(
            'SELECT d.*, p.path
               FROM page_author pa
               JOIN doctors d ON d.id = pa.doctor_id
               LEFT JOIN pages p ON p.id = d.page_id
              WHERE pa.page_id = ? LIMIT 1',
            [$pageId]
        );
    }

    public function postsByDoctor(int $doctorId, int $limit = 6): array
    {
        return $this->db->all(
            'SELECT p.* FROM pages p
               JOIN page_author pa ON pa.page_id = p.id
              WHERE pa.doctor_id = ? AND p.status = ?
              ORDER BY p.published_at DESC
              LIMIT ' . (int) $limit,
            [$doctorId, 'published']
        );
    }

    /** مقالات مرتبط: هم‌کلینیک، در غیر این صورت جدیدترین‌ها */
    public function relatedPosts(array $page, int $limit = 3): array
    {
        if (!empty($page['clinic_id'])) {
            $rows = $this->db->all(
                'SELECT * FROM pages
                  WHERE type = ? AND status = ? AND clinic_id = ? AND id <> ?
                  ORDER BY published_at DESC LIMIT ' . (int) $limit,
                ['post', 'published', $page['clinic_id'], $page['id']]
            );
            if ($rows !== []) {
                return $rows;
            }
        }
        return $this->db->all(
            'SELECT * FROM pages
              WHERE type = ? AND status = ? AND id <> ?
              ORDER BY published_at DESC LIMIT ' . (int) $limit,
            ['post', 'published', $page['id']]
        );
    }

    // ---- سؤالات متداول ---------------------------------------------

    public function faqs(int $pageId): array
    {
        return $this->db->all(
            'SELECT question, answer FROM faqs WHERE page_id = ? ORDER BY sort ASC, id ASC',
            [$pageId]
        );
    }
}
