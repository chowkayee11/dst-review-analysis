PRAGMA foreign_keys = ON;

-- ============================================================
-- 1. Table row counts
-- ============================================================

SELECT
    'reviews' AS table_name,
    COUNT(*) AS row_count
FROM reviews

UNION ALL

SELECT
    'themes' AS table_name,
    COUNT(*) AS row_count
FROM themes

UNION ALL

SELECT
    'review_themes' AS table_name,
    COUNT(*) AS row_count
FROM review_themes;


-- ============================================================
-- 2. Consolidated data quality report
-- ============================================================

WITH quality_checks AS (

    SELECT
        'Duplicate recommendation IDs' AS check_name,
        COUNT(*) - COUNT(DISTINCT recommendation_id)
            AS issue_count
    FROM reviews

    UNION ALL

    SELECT
        'Missing or empty review text',
        COUNT(*)
    FROM reviews
    WHERE review_text IS NULL
       OR TRIM(review_text) = ''

    UNION ALL

    SELECT
        'Missing review dates',
        COUNT(*)
    FROM reviews
    WHERE review_date IS NULL
       OR TRIM(review_date) = ''

    UNION ALL

    SELECT
        'Invalid recommendation values',
        COUNT(*)
    FROM reviews
    WHERE recommended IS NULL
       OR recommended NOT IN (0, 1)

    UNION ALL

    SELECT
        'Invalid Steam purchase values',
        COUNT(*)
    FROM reviews
    WHERE steam_purchase IS NULL
       OR steam_purchase NOT IN (0, 1)

    UNION ALL

    SELECT
        'Invalid free-copy values',
        COUNT(*)
    FROM reviews
    WHERE received_for_free IS NULL
       OR received_for_free NOT IN (0, 1)

    UNION ALL

    SELECT
        'Negative playtime values',
        COUNT(*)
    FROM reviews
    WHERE playtime_at_review_hours < 0
       OR playtime_forever_hours < 0

    UNION ALL

    SELECT
        'Negative review-length values',
        COUNT(*)
    FROM reviews
    WHERE review_word_count < 0
       OR review_length_chars < 0

    UNION ALL

    SELECT
        'Negative vote or comment values',
        COUNT(*)
    FROM reviews
    WHERE votes_up < 0
       OR votes_funny < 0
       OR comment_count < 0

    UNION ALL

    SELECT
        'Invalid review dates',
        COUNT(*)
    FROM reviews
    WHERE DATE(review_date) IS NULL

    UNION ALL

    SELECT
        'Review month and date mismatches',
        COUNT(*)
    FROM reviews
    WHERE review_month <> SUBSTR(review_date, 1, 7)

    UNION ALL

    SELECT
        'Orphaned review-theme review IDs',
        COUNT(*)
    FROM review_themes AS rt
    LEFT JOIN reviews AS r
        ON rt.recommendation_id = r.recommendation_id
    WHERE r.recommendation_id IS NULL

    UNION ALL

    SELECT
        'Orphaned review-theme theme IDs',
        COUNT(*)
    FROM review_themes AS rt
    LEFT JOIN themes AS t
        ON rt.theme_id = t.theme_id
    WHERE t.theme_id IS NULL

    UNION ALL

    SELECT
        'Duplicate review-theme relationships',
        COUNT(*)
    FROM (
        SELECT
            recommendation_id,
            theme_id
        FROM review_themes
        GROUP BY
            recommendation_id,
            theme_id
        HAVING COUNT(*) > 1
    )
)

SELECT
    check_name,
    issue_count,
    CASE
        WHEN issue_count = 0 THEN 'PASS'
        ELSE 'REVIEW'
    END AS check_status
FROM quality_checks
ORDER BY check_name;


-- ============================================================
-- 3. Review ID uniqueness
-- ============================================================

SELECT
    COUNT(*) AS total_reviews,
    COUNT(DISTINCT recommendation_id)
        AS distinct_recommendation_ids,
    COUNT(*) - COUNT(DISTINCT recommendation_id)
        AS duplicate_id_rows
FROM reviews;


-- ============================================================
-- 4. Duplicate review text
-- Duplicate text is not automatically a data-quality error.
-- Different users may submit the same short review.
-- ============================================================

SELECT
    COUNT(*) AS total_reviews,
    COUNT(DISTINCT review_text)
        AS distinct_review_texts,
    COUNT(*) - COUNT(DISTINCT review_text)
        AS repeated_text_rows
FROM reviews;


-- ============================================================
-- 5. Recommendation summary
-- ============================================================

SELECT
    COUNT(*) AS total_reviews,
    SUM(recommended) AS positive_reviews,
    SUM(
        CASE
            WHEN recommended = 0 THEN 1
            ELSE 0
        END
    ) AS negative_reviews,
    ROUND(
        100.0 * SUM(recommended) / COUNT(*),
        2
    ) AS positive_rate
FROM reviews;


-- ============================================================
-- 6. Missing-value summary
-- ============================================================

SELECT
    SUM(
        CASE
            WHEN playtime_at_review_hours IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_playtime_at_review,

    SUM(
        CASE
            WHEN playtime_forever_hours IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_total_playtime,

    SUM(
        CASE
            WHEN weighted_vote_score IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_weighted_vote_score,

    SUM(
        CASE
            WHEN detected_language IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_detected_language
FROM reviews;


-- ============================================================
-- 7. Theme coverage
-- LEFT JOIN keeps reviews that do not match any theme.
-- ============================================================

WITH theme_counts AS (
    SELECT
        r.recommendation_id,
        COUNT(rt.theme_id) AS theme_count
    FROM reviews AS r
    LEFT JOIN review_themes AS rt
        ON r.recommendation_id = rt.recommendation_id
    GROUP BY r.recommendation_id
)

SELECT
    COUNT(*) AS total_reviews,

    SUM(
        CASE
            WHEN theme_count > 0 THEN 1
            ELSE 0
        END
    ) AS reviews_with_theme,

    SUM(
        CASE
            WHEN theme_count = 0 THEN 1
            ELSE 0
        END
    ) AS reviews_without_theme,

    ROUND(
        100.0
        * SUM(
            CASE
                WHEN theme_count > 0 THEN 1
                ELSE 0
            END
        )
        / COUNT(*),
        2
    ) AS theme_coverage_rate,

    ROUND(
        AVG(theme_count),
        2
    ) AS average_themes_per_review,

    MAX(theme_count) AS maximum_themes_per_review
FROM theme_counts;


-- ============================================================
-- 8. Theme lookup table
-- ============================================================

SELECT
    theme_id,
    theme_name
FROM themes
ORDER BY theme_id;


-- ============================================================
-- 9. Foreign-key validation
-- No output means no foreign-key violations.
-- ============================================================

PRAGMA foreign_key_check;