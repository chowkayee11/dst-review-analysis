PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS review_themes;
DROP TABLE IF EXISTS themes;
DROP TABLE IF EXISTS reviews;

CREATE TABLE reviews (
    recommendation_id INTEGER PRIMARY KEY,
    review_text TEXT NOT NULL,
    recommended INTEGER NOT NULL
        CHECK (recommended IN (0, 1)),

    votes_up INTEGER NOT NULL DEFAULT 0
        CHECK (votes_up >= 0),
    votes_funny INTEGER NOT NULL DEFAULT 0
        CHECK (votes_funny >= 0),
    weighted_vote_score REAL,
    comment_count INTEGER NOT NULL DEFAULT 0
        CHECK (comment_count >= 0),

    steam_purchase INTEGER NOT NULL
        CHECK (steam_purchase IN (0, 1)),
    received_for_free INTEGER NOT NULL
        CHECK (received_for_free IN (0, 1)),
    written_during_early_access INTEGER NOT NULL
        CHECK (written_during_early_access IN (0, 1)),

    created_at TEXT NOT NULL,
    review_date TEXT NOT NULL,
    review_month TEXT NOT NULL,

    playtime_forever_hours REAL
        CHECK (
            playtime_forever_hours IS NULL
            OR playtime_forever_hours >= 0
        ),
    playtime_at_review_hours REAL
        CHECK (
            playtime_at_review_hours IS NULL
            OR playtime_at_review_hours >= 0
        ),

    num_games_owned INTEGER
        CHECK (
            num_games_owned IS NULL
            OR num_games_owned >= 0
        ),
    author_num_reviews INTEGER
        CHECK (
            author_num_reviews IS NULL
            OR author_num_reviews >= 0
        ),

    review_length_chars INTEGER NOT NULL
        CHECK (review_length_chars >= 0),
    review_word_count INTEGER NOT NULL
        CHECK (review_word_count >= 0),
    review_length_category TEXT,

    detected_language TEXT,
    contains_non_latin_script INTEGER NOT NULL
        CHECK (contains_non_latin_script IN (0, 1))
);

CREATE TABLE themes (
    theme_id INTEGER PRIMARY KEY,
    theme_name TEXT NOT NULL UNIQUE
);

CREATE TABLE review_themes (
    recommendation_id INTEGER NOT NULL,
    theme_id INTEGER NOT NULL,

    PRIMARY KEY (
        recommendation_id,
        theme_id
    ),

    FOREIGN KEY (recommendation_id)
        REFERENCES reviews (recommendation_id)
        ON DELETE CASCADE,

    FOREIGN KEY (theme_id)
        REFERENCES themes (theme_id)
        ON DELETE CASCADE
);

CREATE INDEX idx_reviews_month
    ON reviews (review_month);

CREATE INDEX idx_reviews_recommended
    ON reviews (recommended);

CREATE INDEX idx_reviews_playtime
    ON reviews (playtime_at_review_hours);

CREATE INDEX idx_review_themes_theme
    ON review_themes (theme_id);
