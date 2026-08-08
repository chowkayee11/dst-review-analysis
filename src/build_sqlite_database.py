"""Build the SQLite database used by the SQL analysis module."""

from pathlib import Path
import sqlite3

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]

ENGLISH_DATA_PATH = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "dst_reviews_english_text.csv"
)

THEME_DATA_PATH = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "dst_reviews_with_themes.csv"
)

SCHEMA_PATH = (
    PROJECT_ROOT
    / "sql"
    / "01_create_tables.sql"
)

DATABASE_PATH = (
    PROJECT_ROOT
    / "data"
    / "database"
    / "dst_reviews.db"
)

THEME_COLUMNS = [
    "Fun and enjoyment",
    "Social and multiplayer",
    "Art and visual style",
    "Learning and challenge",
    "Onboarding and guidance",
    "Repetition and boredom",
    "Difficulty and punishment",
    "Time and value",
    "Progression and clarity",
]


def normalize_boolean(
    series: pd.Series,
    column_name: str,
) -> pd.Series:
    """Convert Boolean-like values to SQLite-compatible 0 and 1."""

    if pd.api.types.is_bool_dtype(series):
        return series.astype("int64")

    value_mapping = {
        "true": 1,
        "false": 0,
        "1": 1,
        "0": 0,
        "yes": 1,
        "no": 0,
    }

    normalized = (
        series.astype(str)
        .str.strip()
        .str.lower()
        .map(value_mapping)
    )

    if normalized.isna().any():
        invalid_values = (
            series[normalized.isna()]
            .drop_duplicates()
            .tolist()
        )

        raise ValueError(
            f"Column {column_name!r} contains invalid "
            f"Boolean values: {invalid_values}"
        )

    return normalized.astype("int64")


def check_required_columns(
    dataframe: pd.DataFrame,
    required_columns: list[str],
    dataframe_name: str,
) -> None:
    """Raise an error when required columns are missing."""

    missing_columns = [
        column
        for column in required_columns
        if column not in dataframe.columns
    ]

    if missing_columns:
        raise ValueError(
            f"{dataframe_name} is missing columns: "
            f"{missing_columns}"
        )


def validate_table_alignment(
    english_data: pd.DataFrame,
    theme_data: pd.DataFrame,
) -> None:
    """Confirm that both files contain the same reviews in the same order."""

    if len(english_data) != len(theme_data):
        raise ValueError(
            "The English data and theme data have different "
            "row counts."
        )

    same_reviews = (
        english_data["review"]
        .fillna("")
        .astype(str)
        .reset_index(drop=True)
        ==
        theme_data["review"]
        .fillna("")
        .astype(str)
        .reset_index(drop=True)
    )

    english_recommended = normalize_boolean(
        english_data["voted_up"],
        "english_data.voted_up",
    )

    theme_recommended = normalize_boolean(
        theme_data["voted_up"],
        "theme_data.voted_up",
    )

    same_recommendation = (
        english_recommended.reset_index(drop=True)
        ==
        theme_recommended.reset_index(drop=True)
    )

    same_word_count = (
        pd.to_numeric(
            english_data["review_word_count"],
            errors="raise",
        ).reset_index(drop=True)
        ==
        pd.to_numeric(
            theme_data["review_word_count"],
            errors="raise",
        ).reset_index(drop=True)
    )

    valid_rows = (
        same_reviews
        & same_recommendation
        & same_word_count
    )

    if not valid_rows.all():
        mismatch_count = int((~valid_rows).sum())

        raise ValueError(
            f"The two files are not aligned. "
            f"Mismatched rows: {mismatch_count}"
        )


def prepare_reviews(
    english_data: pd.DataFrame,
) -> pd.DataFrame:
    """Prepare the reviews table."""

    selected_columns = [
        "recommendation_id",
        "review",
        "voted_up",
        "votes_up",
        "votes_funny",
        "weighted_vote_score",
        "comment_count",
        "steam_purchase",
        "received_for_free",
        "written_during_early_access",
        "created_at",
        "review_date",
        "playtime_forever_hours",
        "playtime_at_review_hours",
        "num_games_owned",
        "author_num_reviews",
        "review_length_chars",
        "review_word_count",
        "review_length_category",
        "detected_language",
        "contains_non_latin_script",
    ]

    reviews = (
        english_data[selected_columns]
        .copy()
        .rename(
            columns={
                "review": "review_text",
                "voted_up": "recommended",
            }
        )
    )

    if reviews["recommendation_id"].isna().any():
        raise ValueError(
            "recommendation_id contains missing values."
        )

    if reviews["recommendation_id"].duplicated().any():
        duplicate_count = int(
            reviews["recommendation_id"]
            .duplicated()
            .sum()
        )

        raise ValueError(
            f"Duplicate recommendation IDs: "
            f"{duplicate_count}"
        )

    reviews["recommendation_id"] = pd.to_numeric(
        reviews["recommendation_id"],
        errors="raise",
    ).astype("int64")

    boolean_columns = [
        "recommended",
        "steam_purchase",
        "received_for_free",
        "written_during_early_access",
        "contains_non_latin_script",
    ]

    for column in boolean_columns:
        reviews[column] = normalize_boolean(
            reviews[column],
            column,
        )

    non_negative_integer_columns = [
        "votes_up",
        "votes_funny",
        "comment_count",
        "num_games_owned",
        "author_num_reviews",
        "review_length_chars",
        "review_word_count",
    ]

    for column in non_negative_integer_columns:
        reviews[column] = pd.to_numeric(
            reviews[column],
            errors="raise",
        )

    numeric_columns = [
        "weighted_vote_score",
        "playtime_forever_hours",
        "playtime_at_review_hours",
    ]

    for column in numeric_columns:
        reviews[column] = pd.to_numeric(
            reviews[column],
            errors="raise",
        )

    created_at = pd.to_datetime(
        reviews["created_at"],
        errors="raise",
        utc=True,
    )

    review_date = pd.to_datetime(
        reviews["review_date"],
        errors="raise",
    )

    reviews["created_at"] = created_at.dt.strftime(
        "%Y-%m-%d %H:%M:%S"
    )

    reviews["review_date"] = review_date.dt.strftime(
        "%Y-%m-%d"
    )

    reviews["review_month"] = review_date.dt.strftime(
        "%Y-%m"
    )

    reviews["review_text"] = (
        reviews["review_text"]
        .fillna("")
        .astype(str)
    )

    return reviews


def prepare_themes() -> pd.DataFrame:
    """Create the theme lookup table."""

    return pd.DataFrame(
        {
            "theme_id": range(
                1,
                len(THEME_COLUMNS) + 1,
            ),
            "theme_name": THEME_COLUMNS,
        }
    )


def prepare_review_themes(
    english_data: pd.DataFrame,
    theme_data: pd.DataFrame,
    themes: pd.DataFrame,
) -> pd.DataFrame:
    """Convert wide theme flags into a normalized association table."""

    theme_flags = theme_data[
        THEME_COLUMNS
    ].copy()

    for column in THEME_COLUMNS:
        theme_flags[column] = normalize_boolean(
            theme_flags[column],
            column,
        )

    theme_flags.insert(
        0,
        "recommendation_id",
        pd.to_numeric(
            english_data["recommendation_id"],
            errors="raise",
        ).astype("int64").to_numpy(),
    )

    long_data = theme_flags.melt(
        id_vars="recommendation_id",
        var_name="theme_name",
        value_name="theme_matched",
    )

    long_data = long_data.loc[
        long_data["theme_matched"] == 1
    ].copy()

    theme_id_mapping = dict(
        zip(
            themes["theme_name"],
            themes["theme_id"],
        )
    )

    long_data["theme_id"] = (
        long_data["theme_name"]
        .map(theme_id_mapping)
        .astype("int64")
    )

    review_themes = long_data[
        [
            "recommendation_id",
            "theme_id",
        ]
    ].drop_duplicates()

    return review_themes


def build_database() -> None:
    """Create and populate the SQLite database."""

    for required_path in [
        ENGLISH_DATA_PATH,
        THEME_DATA_PATH,
        SCHEMA_PATH,
    ]:
        if not required_path.exists():
            raise FileNotFoundError(
                f"Required file not found: "
                f"{required_path}"
            )

    english_data = pd.read_csv(
        ENGLISH_DATA_PATH
    )

    theme_data = pd.read_csv(
        THEME_DATA_PATH
    )

    english_required_columns = [
        "recommendation_id",
        "review",
        "voted_up",
        "review_word_count",
        "votes_up",
        "votes_funny",
        "weighted_vote_score",
        "comment_count",
        "steam_purchase",
        "received_for_free",
        "written_during_early_access",
        "created_at",
        "review_date",
        "playtime_forever_hours",
        "playtime_at_review_hours",
        "num_games_owned",
        "author_num_reviews",
        "review_length_chars",
        "review_length_category",
        "detected_language",
        "contains_non_latin_script",
    ]

    theme_required_columns = [
        "review",
        "voted_up",
        "review_word_count",
        *THEME_COLUMNS,
    ]

    check_required_columns(
        english_data,
        english_required_columns,
        "English data",
    )

    check_required_columns(
        theme_data,
        theme_required_columns,
        "Theme data",
    )

    validate_table_alignment(
        english_data,
        theme_data,
    )

    reviews = prepare_reviews(
        english_data
    )

    themes = prepare_themes()

    review_themes = prepare_review_themes(
        english_data,
        theme_data,
        themes,
    )

    DATABASE_PATH.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    schema_sql = SCHEMA_PATH.read_text(
        encoding="utf-8"
    )

    with sqlite3.connect(
        DATABASE_PATH
    ) as connection:
        connection.execute(
            "PRAGMA foreign_keys = ON;"
        )

        connection.executescript(
            schema_sql
        )

        reviews.to_sql(
            "reviews",
            connection,
            if_exists="append",
            index=False,
            chunksize=500,
        )

        themes.to_sql(
            "themes",
            connection,
            if_exists="append",
            index=False,
        )

        review_themes.to_sql(
            "review_themes",
            connection,
            if_exists="append",
            index=False,
            chunksize=500,
        )

        foreign_key_errors = connection.execute(
            "PRAGMA foreign_key_check;"
        ).fetchall()

        if foreign_key_errors:
            raise RuntimeError(
                "Foreign key validation failed: "
                f"{foreign_key_errors}"
            )

        review_count = connection.execute(
            "SELECT COUNT(*) FROM reviews;"
        ).fetchone()[0]

        theme_count = connection.execute(
            "SELECT COUNT(*) FROM themes;"
        ).fetchone()[0]

        review_theme_count = connection.execute(
            "SELECT COUNT(*) FROM review_themes;"
        ).fetchone()[0]

    print("SQLite database created successfully.")
    print(f"Database: {DATABASE_PATH}")
    print(f"Reviews: {review_count:,}")
    print(f"Themes: {theme_count:,}")
    print(
        f"Review-theme relationships: "
        f"{review_theme_count:,}"
    )


if __name__ == "__main__":
    build_database()
