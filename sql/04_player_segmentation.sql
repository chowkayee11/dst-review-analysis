PRAGMA foreign_keys = ON;

-- ============================================================
-- 1. Player segmentation by playtime at review
--
-- Skills demonstrated:
-- CASE WHEN
-- CTEs
-- conditional aggregation
-- LEFT JOIN
-- window functions
-- median calculation
-- ============================================================

WITH theme_counts AS (
    SELECT
        r.recommendation_id,
        COUNT(rt.theme_id) AS theme_count
    FROM reviews AS r
    LEFT JOIN review_themes AS rt
        ON r.recommendation_id = rt.recommendation_id
    GROUP BY r.recommendation_id
),

segmented_reviews AS (
    SELECT
        r.recommendation_id,
        r.recommended,
        r.playtime_at_review_hours,
        r.review_word_count,
        r.votes_up,
        r.steam_purchase,
        r.received_for_free,
        tc.theme_count,

        CASE
            WHEN r.playtime_at_review_hours IS NULL
                THEN 'Unknown'

            WHEN r.playtime_at_review_hours < 2
                THEN 'Under 2 hours'

            WHEN r.playtime_at_review_hours < 10
                THEN '2 to under 10 hours'

            WHEN r.playtime_at_review_hours < 50
                THEN '10 to under 50 hours'

            WHEN r.playtime_at_review_hours < 200
                THEN '50 to under 200 hours'

            ELSE '200 hours or more'
        END AS playtime_segment,

        CASE
            WHEN r.playtime_at_review_hours IS NULL
                THEN 0

            WHEN r.playtime_at_review_hours < 2
                THEN 1

            WHEN r.playtime_at_review_hours < 10
                THEN 2

            WHEN r.playtime_at_review_hours < 50
                THEN 3

            WHEN r.playtime_at_review_hours < 200
                THEN 4

            ELSE 5
        END AS segment_order
    FROM reviews AS r
    LEFT JOIN theme_counts AS tc
        ON r.recommendation_id = tc.recommendation_id
),

ranked_reviews AS (
    SELECT
        segmented_reviews.*,

        ROW_NUMBER() OVER (
            PARTITION BY segment_order
            ORDER BY playtime_at_review_hours
        ) AS playtime_rank,

        ROW_NUMBER() OVER (
            PARTITION BY segment_order
            ORDER BY review_word_count
        ) AS word_count_rank,

        COUNT(*) OVER (
            PARTITION BY segment_order
        ) AS segment_count
    FROM segmented_reviews
),

segment_medians AS (
    SELECT
        segment_order,
        playtime_segment,

        ROUND(
            AVG(
                CASE
                    WHEN playtime_rank IN (
                        (segment_count + 1) / 2,
                        (segment_count + 2) / 2
                    )
                    THEN playtime_at_review_hours
                END
            ),
            2
        ) AS median_playtime_hours,

        ROUND(
            AVG(
                CASE
                    WHEN word_count_rank IN (
                        (segment_count + 1) / 2,
                        (segment_count + 2) / 2
                    )
                    THEN review_word_count
                END
            ),
            2
        ) AS median_review_words
    FROM ranked_reviews
    GROUP BY
        segment_order,
        playtime_segment
),

segment_summary AS (
    SELECT
        segment_order,
        playtime_segment,

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

        ROUND(
            100.0 * SUM(recommended) / COUNT(*),
            2
        ) AS positive_rate,

        ROUND(
            AVG(playtime_at_review_hours),
            2
        ) AS average_playtime_hours,

        ROUND(
            AVG(review_word_count),
            2
        ) AS average_review_words,

        ROUND(
            100.0
            * AVG(
                CASE
                    WHEN votes_up > 0 THEN 1.0
                    ELSE 0.0
                END
            ),
            2
        ) AS helpful_vote_rate,

        ROUND(
            AVG(1.0 * theme_count),
            2
        ) AS average_themes_per_review,

        ROUND(
            100.0 * AVG(steam_purchase),
            2
        ) AS steam_purchase_rate,

        ROUND(
            100.0 * AVG(received_for_free),
            2
        ) AS free_copy_rate
    FROM segmented_reviews
    GROUP BY
        segment_order,
        playtime_segment
)

SELECT
    ss.playtime_segment,
    ss.total_reviews,

    ROUND(
        100.0
        * ss.total_reviews
        / (
            SELECT COUNT(*)
            FROM reviews
        ),
        2
    ) AS review_share,

    ss.positive_reviews,
    ss.negative_reviews,
    ss.positive_rate,
    sm.median_playtime_hours,
    ss.average_playtime_hours,
    sm.median_review_words,
    ss.average_review_words,
    ss.helpful_vote_rate,
    ss.average_themes_per_review,
    ss.steam_purchase_rate,
    ss.free_copy_rate,

    RANK() OVER (
        ORDER BY ss.positive_rate DESC
    ) AS positive_rate_rank
FROM segment_summary AS ss
INNER JOIN segment_medians AS sm
    ON ss.segment_order = sm.segment_order
ORDER BY ss.segment_order;


-- ============================================================
-- 2. Positive and negative review comparison
-- ============================================================

WITH classified_reviews AS (
    SELECT
        recommended,

        CASE
            WHEN recommended = 1
                THEN 'Recommended'
            ELSE 'Not recommended'
        END AS recommendation_category,

        playtime_at_review_hours,
        review_word_count,
        votes_up
    FROM reviews
),

ranked_reviews AS (
    SELECT
        classified_reviews.*,

        ROW_NUMBER() OVER (
            PARTITION BY recommended
            ORDER BY playtime_at_review_hours
        ) AS playtime_rank,

        ROW_NUMBER() OVER (
            PARTITION BY recommended
            ORDER BY review_word_count
        ) AS word_count_rank,

        COUNT(*) OVER (
            PARTITION BY recommended
        ) AS category_count
    FROM classified_reviews
)

SELECT
    recommendation_category,
    COUNT(*) AS total_reviews,

    ROUND(
        AVG(playtime_at_review_hours),
        2
    ) AS average_playtime_hours,

    ROUND(
        AVG(
            CASE
                WHEN playtime_rank IN (
                    (category_count + 1) / 2,
                    (category_count + 2) / 2
                )
                THEN playtime_at_review_hours
            END
        ),
        2
    ) AS median_playtime_hours,

    ROUND(
        AVG(review_word_count),
        2
    ) AS average_review_words,

    ROUND(
        AVG(
            CASE
                WHEN word_count_rank IN (
                    (category_count + 1) / 2,
                    (category_count + 2) / 2
                )
                THEN review_word_count
            END
        ),
        2
    ) AS median_review_words,

    ROUND(
        100.0
        * AVG(
            CASE
                WHEN votes_up > 0 THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS helpful_vote_rate
FROM ranked_reviews
GROUP BY
    recommended,
    recommendation_category
ORDER BY recommended DESC;


-- ============================================================
-- 3. Top themes within each playtime segment
--
-- Reviews can match multiple themes.
-- The query uses JOIN and DENSE_RANK.
-- ============================================================

WITH segmented_reviews AS (
    SELECT
        recommendation_id,
        recommended,

        CASE
            WHEN playtime_at_review_hours IS NULL
                THEN 'Unknown'

            WHEN playtime_at_review_hours < 2
                THEN 'Under 2 hours'

            WHEN playtime_at_review_hours < 10
                THEN '2 to under 10 hours'

            WHEN playtime_at_review_hours < 50
                THEN '10 to under 50 hours'

            WHEN playtime_at_review_hours < 200
                THEN '50 to under 200 hours'

            ELSE '200 hours or more'
        END AS playtime_segment,

        CASE
            WHEN playtime_at_review_hours IS NULL
                THEN 0

            WHEN playtime_at_review_hours < 2
                THEN 1

            WHEN playtime_at_review_hours < 10
                THEN 2

            WHEN playtime_at_review_hours < 50
                THEN 3

            WHEN playtime_at_review_hours < 200
                THEN 4

            ELSE 5
        END AS segment_order
    FROM reviews
),

segment_sizes AS (
    SELECT
        segment_order,
        playtime_segment,
        COUNT(*) AS segment_review_count
    FROM segmented_reviews
    GROUP BY
        segment_order,
        playtime_segment
),

theme_metrics AS (
    SELECT
        sr.segment_order,
        sr.playtime_segment,
        t.theme_name,

        COUNT(DISTINCT sr.recommendation_id)
            AS theme_review_count,

        SUM(
            CASE
                WHEN sr.recommended = 0 THEN 1
                ELSE 0
            END
        ) AS negative_theme_reviews,

        ROUND(
            100.0
            * SUM(
                CASE
                    WHEN sr.recommended = 0 THEN 1
                    ELSE 0
                END
            )
            / COUNT(DISTINCT sr.recommendation_id),
            2
        ) AS negative_rate
    FROM segmented_reviews AS sr
    INNER JOIN review_themes AS rt
        ON sr.recommendation_id = rt.recommendation_id
    INNER JOIN themes AS t
        ON rt.theme_id = t.theme_id
    GROUP BY
        sr.segment_order,
        sr.playtime_segment,
        t.theme_name
),

ranked_themes AS (
    SELECT
        tm.segment_order,
        tm.playtime_segment,
        tm.theme_name,
        tm.theme_review_count,
        tm.negative_theme_reviews,
        tm.negative_rate,

        ROUND(
            100.0
            * tm.theme_review_count
            / ss.segment_review_count,
            2
        ) AS theme_rate_within_segment,

        DENSE_RANK() OVER (
            PARTITION BY tm.segment_order
            ORDER BY
                tm.theme_review_count DESC
        ) AS theme_rank
    FROM theme_metrics AS tm
    INNER JOIN segment_sizes AS ss
        ON tm.segment_order = ss.segment_order
)

SELECT
    playtime_segment,
    theme_rank,
    theme_name,
    theme_review_count,
    theme_rate_within_segment,
    negative_theme_reviews,
    negative_rate
FROM ranked_themes
WHERE theme_rank <= 3
ORDER BY
    segment_order,
    theme_rank,
    theme_name;


-- ============================================================
-- 4. Segment reconciliation
-- ============================================================

WITH segmented_reviews AS (
    SELECT
        CASE
            WHEN playtime_at_review_hours IS NULL
                THEN 'Unknown'

            WHEN playtime_at_review_hours < 2
                THEN 'Under 2 hours'

            WHEN playtime_at_review_hours < 10
                THEN '2 to under 10 hours'

            WHEN playtime_at_review_hours < 50
                THEN '10 to under 50 hours'

            WHEN playtime_at_review_hours < 200
                THEN '50 to under 200 hours'

            ELSE '200 hours or more'
        END AS playtime_segment
    FROM reviews
),

segment_counts AS (
    SELECT
        playtime_segment,
        COUNT(*) AS total_reviews
    FROM segmented_reviews
    GROUP BY playtime_segment
)

SELECT
    SUM(total_reviews) AS segmented_total,
    (
        SELECT COUNT(*)
        FROM reviews
    ) AS review_table_total,

    CASE
        WHEN SUM(total_reviews) = (
            SELECT COUNT(*)
            FROM reviews
        )
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS reconciliation_status
FROM segment_counts;