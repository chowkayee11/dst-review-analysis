PRAGMA foreign_keys = ON;

-- ============================================================
-- 1. Monthly review metrics
--
-- This query demonstrates:
-- GROUP BY
-- conditional aggregation
-- CTEs
-- LAG window functions
-- RANK window functions
-- cumulative totals
-- rolling averages
-- ============================================================

WITH dataset_bounds AS (
    SELECT
        MIN(review_month) AS first_month,
        MAX(review_month) AS last_month
    FROM reviews
),

monthly_base AS (
    SELECT
        review_month,

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
            100.0
            * SUM(recommended)
            / COUNT(*),
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
        ) AS helpful_vote_rate
    FROM reviews
    GROUP BY review_month
),

monthly_windows AS (
    SELECT
        monthly_base.*,
        dataset_bounds.first_month,
        dataset_bounds.last_month,

        LAG(positive_rate) OVER (
            ORDER BY review_month
        ) AS previous_month_positive_rate,

        LAG(total_reviews) OVER (
            ORDER BY review_month
        ) AS previous_month_review_count,

        RANK() OVER (
            ORDER BY total_reviews DESC
        ) AS review_volume_rank,

        RANK() OVER (
            ORDER BY positive_rate DESC
        ) AS positive_rate_rank,

        SUM(total_reviews) OVER (
            ORDER BY review_month
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_reviews,

        ROUND(
            AVG(positive_rate) OVER (
                ORDER BY review_month
                ROWS BETWEEN 2 PRECEDING
                AND CURRENT ROW
            ),
            2
        ) AS rolling_3_month_positive_rate
    FROM monthly_base
    CROSS JOIN dataset_bounds
)

SELECT
    review_month,
    total_reviews,
    positive_reviews,
    negative_reviews,
    positive_rate,

    previous_month_positive_rate,

    ROUND(
        positive_rate
        - previous_month_positive_rate,
        2
    ) AS positive_rate_change_pp,

    previous_month_review_count,

    CASE
        WHEN previous_month_review_count IS NULL
            THEN NULL
        ELSE ROUND(
            100.0
            * (
                total_reviews
                - previous_month_review_count
            )
            / previous_month_review_count,
            2
        )
    END AS review_volume_change_pct,

    average_playtime_hours,
    average_review_words,
    helpful_vote_rate,
    rolling_3_month_positive_rate,
    cumulative_reviews,
    review_volume_rank,
    positive_rate_rank,

    CASE
        WHEN review_month IN (
            first_month,
            last_month
        )
            THEN 'Partial month'
        ELSE 'Complete month'
    END AS month_status
FROM monthly_windows
ORDER BY review_month;


-- ============================================================
-- 2. Complete-month positive-rate ranking
--
-- The first and last months are excluded because the collection
-- period does not cover the whole month.
-- ============================================================

WITH dataset_bounds AS (
    SELECT
        MIN(review_month) AS first_month,
        MAX(review_month) AS last_month
    FROM reviews
),

monthly_metrics AS (
    SELECT
        review_month,
        COUNT(*) AS total_reviews,

        ROUND(
            100.0
            * SUM(recommended)
            / COUNT(*),
            2
        ) AS positive_rate
    FROM reviews
    GROUP BY review_month
),

complete_months AS (
    SELECT
        monthly_metrics.*
    FROM monthly_metrics
    CROSS JOIN dataset_bounds
    WHERE review_month NOT IN (
        first_month,
        last_month
    )
)

SELECT
    review_month,
    total_reviews,
    positive_rate,

    RANK() OVER (
        ORDER BY positive_rate DESC
    ) AS positive_rate_rank,

    RANK() OVER (
        ORDER BY total_reviews DESC
    ) AS review_volume_rank
FROM complete_months
ORDER BY positive_rate_rank;


-- ============================================================
-- 3. Month-over-month positive-rate changes
-- ============================================================

WITH dataset_bounds AS (
    SELECT
        MIN(review_month) AS first_month,
        MAX(review_month) AS last_month
    FROM reviews
),

monthly_metrics AS (
    SELECT
        review_month,
        COUNT(*) AS total_reviews,

        ROUND(
            100.0
            * SUM(recommended)
            / COUNT(*),
            2
        ) AS positive_rate
    FROM reviews
    GROUP BY review_month
),

monthly_changes AS (
    SELECT
        monthly_metrics.*,

        LAG(positive_rate) OVER (
            ORDER BY review_month
        ) AS previous_month_positive_rate
    FROM monthly_metrics
)

SELECT
    review_month,
    total_reviews,
    positive_rate,
    previous_month_positive_rate,

    ROUND(
        positive_rate
        - previous_month_positive_rate,
        2
    ) AS positive_rate_change_pp,

    CASE
        WHEN positive_rate
             > previous_month_positive_rate
            THEN 'Increase'

        WHEN positive_rate
             < previous_month_positive_rate
            THEN 'Decrease'

        ELSE 'No change'
    END AS change_direction
FROM monthly_changes
CROSS JOIN dataset_bounds
WHERE previous_month_positive_rate IS NOT NULL
  AND review_month NOT IN (
      first_month,
      last_month
  )
ORDER BY positive_rate_change_pp ASC;


-- ============================================================
-- 4. Monthly aggregation reconciliation
-- ============================================================

WITH monthly_counts AS (
    SELECT
        review_month,
        COUNT(*) AS total_reviews
    FROM reviews
    GROUP BY review_month
)

SELECT
    SUM(total_reviews) AS monthly_total_reviews,

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
FROM monthly_counts;