PRAGMA foreign_keys = ON;

-- ============================================================
-- 1. Theme performance summary
--
-- Skills demonstrated:
-- multiple-table JOIN
-- conditional aggregation
-- CTEs
-- NULLIF
-- window ranking
-- rate and lift calculations
-- ============================================================

WITH review_totals AS (
    SELECT
        COUNT(*) AS total_reviews,

        SUM(
            CASE
                WHEN recommended = 1 THEN 1
                ELSE 0
            END
        ) AS positive_reviews,

        SUM(
            CASE
                WHEN recommended = 0 THEN 1
                ELSE 0
            END
        ) AS negative_reviews,

        1.0 * SUM(
            CASE
                WHEN recommended = 0 THEN 1
                ELSE 0
            END
        ) / COUNT(*) AS overall_negative_rate
    FROM reviews
),

theme_counts AS (
    SELECT
        t.theme_id,
        t.theme_name,

        COUNT(
            DISTINCT rt.recommendation_id
        ) AS theme_review_count,

        SUM(
            CASE
                WHEN r.recommended = 1 THEN 1
                ELSE 0
            END
        ) AS positive_theme_reviews,

        SUM(
            CASE
                WHEN r.recommended = 0 THEN 1
                ELSE 0
            END
        ) AS negative_theme_reviews

    FROM themes AS t

    LEFT JOIN review_themes AS rt
        ON t.theme_id = rt.theme_id

    LEFT JOIN reviews AS r
        ON rt.recommendation_id = r.recommendation_id

    GROUP BY
        t.theme_id,
        t.theme_name
),

theme_metrics AS (
    SELECT
        tc.theme_id,
        tc.theme_name,
        tc.theme_review_count,
        tc.positive_theme_reviews,
        tc.negative_theme_reviews,

        ROUND(
            100.0
            * tc.theme_review_count
            / NULLIF(rt.total_reviews, 0),
            2
        ) AS overall_theme_rate,

        ROUND(
            100.0
            * tc.positive_theme_reviews
            / NULLIF(rt.positive_reviews, 0),
            2
        ) AS positive_review_theme_rate,

        ROUND(
            100.0
            * tc.negative_theme_reviews
            / NULLIF(rt.negative_reviews, 0),
            2
        ) AS negative_review_theme_rate,

        ROUND(
            100.0
            * tc.negative_theme_reviews
            / NULLIF(tc.theme_review_count, 0),
            2
        ) AS negative_rate_within_theme,

        ROUND(
            100.0
            * tc.negative_theme_reviews
            / NULLIF(rt.negative_reviews, 0)
            -
            100.0
            * tc.positive_theme_reviews
            / NULLIF(rt.positive_reviews, 0),
            2
        ) AS negative_positive_gap_pp,

        ROUND(
            (
                1.0
                * tc.negative_theme_reviews
                / NULLIF(tc.theme_review_count, 0)
            )
            / NULLIF(
                rt.overall_negative_rate,
                0
            ),
            2
        ) AS negative_rate_lift

    FROM theme_counts AS tc
    CROSS JOIN review_totals AS rt
)

SELECT
    theme_id,
    theme_name,
    theme_review_count,
    positive_theme_reviews,
    negative_theme_reviews,
    overall_theme_rate,
    positive_review_theme_rate,
    negative_review_theme_rate,
    negative_rate_within_theme,
    negative_positive_gap_pp,
    negative_rate_lift,

    DENSE_RANK() OVER (
        ORDER BY negative_positive_gap_pp DESC
    ) AS negative_association_rank,

    DENSE_RANK() OVER (
        ORDER BY theme_review_count DESC
    ) AS theme_volume_rank

FROM theme_metrics

ORDER BY negative_association_rank;

-- ============================================================
-- 2. Theme ranking within positive and negative reviews
-- ============================================================

WITH recommendation_totals AS (
    SELECT
        recommended,
        COUNT(*) AS category_total
    FROM reviews
    GROUP BY recommended
),

theme_by_category AS (
    SELECT
        r.recommended,

        CASE
            WHEN r.recommended = 1
                THEN 'Recommended'
            ELSE 'Not recommended'
        END AS recommendation_category,

        t.theme_name,

        COUNT(
            DISTINCT r.recommendation_id
        ) AS theme_review_count
    FROM reviews AS r
    INNER JOIN review_themes AS rt
        ON r.recommendation_id = rt.recommendation_id
    INNER JOIN themes AS t
        ON rt.theme_id = t.theme_id
    GROUP BY
        r.recommended,
        recommendation_category,
        t.theme_name
),

theme_rates AS (
    SELECT
        tbc.recommended,
        tbc.recommendation_category,
        tbc.theme_name,
        tbc.theme_review_count,

        ROUND(
            100.0
            * tbc.theme_review_count
            / rt.category_total,
            2
        ) AS theme_rate
    FROM theme_by_category AS tbc
    INNER JOIN recommendation_totals AS rt
        ON tbc.recommended = rt.recommended
),

ranked_themes AS (
    SELECT
        theme_rates.*,

        DENSE_RANK() OVER (
            PARTITION BY recommended
            ORDER BY theme_rate DESC
        ) AS theme_rank
    FROM theme_rates
)

SELECT
    recommendation_category,
    theme_rank,
    theme_name,
    theme_review_count,
    theme_rate
FROM ranked_themes
ORDER BY
    recommended DESC,
    theme_rank,
    theme_name;


-- ============================================================
-- 3. Theme co-occurrence
--
-- A self-join identifies theme pairs that appear in the
-- same review.
-- ============================================================

WITH theme_pairs AS (
    SELECT
        t1.theme_name AS theme_1,
        t2.theme_name AS theme_2,

        COUNT(
            DISTINCT rt1.recommendation_id
        ) AS cooccurrence_count,

        SUM(
            CASE
                WHEN r.recommended = 0 THEN 1
                ELSE 0
            END
        ) AS negative_cooccurrence_count
    FROM review_themes AS rt1
    INNER JOIN review_themes AS rt2
        ON rt1.recommendation_id
           = rt2.recommendation_id
       AND rt1.theme_id < rt2.theme_id

    INNER JOIN themes AS t1
        ON rt1.theme_id = t1.theme_id

    INNER JOIN themes AS t2
        ON rt2.theme_id = t2.theme_id

    INNER JOIN reviews AS r
        ON rt1.recommendation_id
           = r.recommendation_id

    GROUP BY
        t1.theme_name,
        t2.theme_name
),

scored_pairs AS (
    SELECT
        theme_1,
        theme_2,
        cooccurrence_count,
        negative_cooccurrence_count,

        ROUND(
            100.0
            * negative_cooccurrence_count
            / NULLIF(cooccurrence_count, 0),
            2
        ) AS negative_rate
    FROM theme_pairs
),

ranked_pairs AS (
    SELECT
        scored_pairs.*,

        DENSE_RANK() OVER (
            ORDER BY cooccurrence_count DESC
        ) AS cooccurrence_rank
    FROM scored_pairs
)

SELECT
    cooccurrence_rank,
    theme_1,
    theme_2,
    cooccurrence_count,
    negative_cooccurrence_count,
    negative_rate
FROM ranked_pairs
WHERE cooccurrence_rank <= 10
ORDER BY
    cooccurrence_rank,
    theme_1,
    theme_2;


-- ============================================================
-- 4. Theme coverage by recommendation category
-- ============================================================

WITH review_theme_counts AS (
    SELECT
        r.recommendation_id,
        r.recommended,
        COUNT(rt.theme_id) AS theme_count
    FROM reviews AS r
    LEFT JOIN review_themes AS rt
        ON r.recommendation_id
           = rt.recommendation_id
    GROUP BY
        r.recommendation_id,
        r.recommended
)

SELECT
    CASE
        WHEN recommended = 1
            THEN 'Recommended'
        ELSE 'Not recommended'
    END AS recommendation_category,

    COUNT(*) AS total_reviews,

    SUM(
        CASE
            WHEN theme_count > 0 THEN 1
            ELSE 0
        END
    ) AS reviews_with_theme,

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
        AVG(1.0 * theme_count),
        2
    ) AS average_themes_per_review,

    MAX(theme_count) AS maximum_themes_per_review
FROM review_theme_counts
GROUP BY recommended
ORDER BY recommended DESC;


-- ============================================================
-- 5. Review-theme relationship reconciliation
-- ============================================================

WITH theme_relationship_counts AS (
    SELECT
        theme_id,
        COUNT(*) AS relationship_count
    FROM review_themes
    GROUP BY theme_id
)

SELECT
    SUM(relationship_count)
        AS aggregated_relationship_count,

    (
        SELECT COUNT(*)
        FROM review_themes
    ) AS review_theme_table_count,

    CASE
        WHEN SUM(relationship_count) = (
            SELECT COUNT(*)
            FROM review_themes
        )
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS reconciliation_status
FROM theme_relationship_counts;