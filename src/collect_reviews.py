import argparse
from pathlib import Path
import time

import pandas as pd
import requests


DEFAULT_APP_ID = 322330
DEFAULT_TARGET_REVIEWS = 5000
DEFAULT_LANGUAGE = "english"
DEFAULT_OUTPUT_PATH = Path("data/raw/dst_reviews_english_5000.csv")
STEAM_REVIEW_URL = "https://store.steampowered.com/appreviews/{app_id}"


def fetch_reviews(
    app_id: int = DEFAULT_APP_ID,
    target_count: int = DEFAULT_TARGET_REVIEWS,
    language: str = DEFAULT_LANGUAGE,
    delay_seconds: float = 1.0,
) -> pd.DataFrame:
    """Collect recent Steam reviews from the public review endpoint."""

    collected_reviews = []
    seen_review_ids = set()
    cursor = "*"
    base_url = STEAM_REVIEW_URL.format(app_id=app_id)

    with requests.Session() as session:
        while len(collected_reviews) < target_count:
            params = {
                "json": 1,
                "filter": "recent",
                "language": language,
                "review_type": "all",
                "purchase_type": "all",
                "num_per_page": 100,
                "cursor": cursor,
            }

            try:
                response = session.get(
                    BASE_URL,
                    params=params,
                    timeout=30,
                )
                response.raise_for_status()
                data = response.json()

            except requests.RequestException as error:
                print(f"Request failed: {error}")
                break

            except ValueError:
                print("Steam returned invalid JSON data.")
                break

            if data.get("success") != 1:
                print("Steam API returned an unsuccessful response.")
                break

            reviews = data.get("reviews", [])

            if not reviews:
                print("No additional reviews were returned.")
                break

            for item in reviews:
                review_id = str(item.get("recommendationid", ""))

                if not review_id or review_id in seen_review_ids:
                    continue

                seen_review_ids.add(review_id)

                author = item.get("author", {})

                collected_reviews.append(
                    {
                        "recommendation_id": review_id,
                        "language": item.get("language"),
                        "review": item.get("review"),
                        "voted_up": item.get("voted_up"),
                        "votes_up": item.get("votes_up"),
                        "votes_funny": item.get("votes_funny"),
                        "weighted_vote_score": item.get(
                            "weighted_vote_score"
                        ),
                        "comment_count": item.get("comment_count"),
                        "steam_purchase": item.get("steam_purchase"),
                        "received_for_free": item.get(
                            "received_for_free"
                        ),
                        "written_during_early_access": item.get(
                            "written_during_early_access"
                        ),
                        "timestamp_created": item.get(
                            "timestamp_created"
                        ),
                        "timestamp_updated": item.get(
                            "timestamp_updated"
                        ),
                        "playtime_forever_minutes": author.get(
                            "playtime_forever"
                        ),
                        "playtime_at_review_minutes": author.get(
                            "playtime_at_review"
                        ),
                        "num_games_owned": author.get(
                            "num_games_owned"
                        ),
                        "author_num_reviews": author.get(
                            "num_reviews"
                        ),
                    }
                )

                if len(collected_reviews) >= target_count:
                    break

            print(
                f"Collected {len(collected_reviews)} "
                f"of {target_count} reviews"
            )

            new_cursor = data.get("cursor")

            if not new_cursor or new_cursor == cursor:
                print("No new pagination cursor was returned.")
                break

            cursor = new_cursor
            if delay_seconds > 0:
                time.sleep(delay_seconds)

    dataframe = pd.DataFrame(collected_reviews)

    if dataframe.empty:
        return dataframe

    dataframe["created_at"] = pd.to_datetime(
        dataframe["timestamp_created"],
        unit="s",
        utc=True,
        errors="coerce",
    )

    dataframe["updated_at"] = pd.to_datetime(
        dataframe["timestamp_updated"],
        unit="s",
        utc=True,
        errors="coerce",
    )

    dataframe["playtime_forever_hours"] = (
        dataframe["playtime_forever_minutes"] / 60
    )

    dataframe["playtime_at_review_hours"] = (
        dataframe["playtime_at_review_minutes"] / 60
    )

    return dataframe


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect recent Steam reviews into a CSV file."
    )
    parser.add_argument(
        "--app-id",
        type=int,
        default=DEFAULT_APP_ID,
        help="Steam AppID to collect reviews for.",
    )
    parser.add_argument(
        "--target-reviews",
        type=int,
        default=DEFAULT_TARGET_REVIEWS,
        help="Maximum number of unique reviews to collect.",
    )
    parser.add_argument(
        "--language",
        default=DEFAULT_LANGUAGE,
        help="Steam review language filter.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT_PATH,
        help="CSV output path.",
    )
    parser.add_argument(
        "--delay-seconds",
        type=float,
        default=1.0,
        help="Delay between paginated requests.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)

    dataframe = fetch_reviews(
        app_id=args.app_id,
        target_count=args.target_reviews,
        language=args.language,
        delay_seconds=args.delay_seconds,
    )

    if dataframe.empty:
        print("No reviews were collected.")
        return

    dataframe.to_csv(
        args.output,
        index=False,
        encoding="utf-8-sig",
    )

    print("\nCollection completed.")
    print(f"Rows: {len(dataframe)}")
    print(f"Columns: {len(dataframe.columns)}")
    print(f"Saved to: {args.output}")
    print("\nPreview:")
    print(
        dataframe[
            [
                "review",
                "voted_up",
                "playtime_at_review_hours",
                "created_at",
            ]
        ].head()
    )


if __name__ == "__main__":
    main()
