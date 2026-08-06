from pathlib import Path
import time

import pandas as pd
import requests


APP_ID = 322330
# TARGET_REVIEWS = 200
TARGET_REVIEWS = 5000
LANGUAGE = "english"

# OUTPUT_PATH = Path("data/raw/dst_reviews_english_200.csv")
OUTPUT_PATH = Path("data/raw/dst_reviews_english_5000.csv")
BASE_URL = f"https://store.steampowered.com/appreviews/{APP_ID}"


def fetch_reviews(target_count: int = 200) -> pd.DataFrame:
    """Collect Steam reviews for Don't Starve Together."""

    collected_reviews = []
    seen_review_ids = set()
    cursor = "*"

    with requests.Session() as session:
        while len(collected_reviews) < target_count:
            params = {
                "json": 1,
                "filter": "recent",
                "language": LANGUAGE,
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
            time.sleep(1)

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


def main() -> None:
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    dataframe = fetch_reviews(TARGET_REVIEWS)

    if dataframe.empty:
        print("No reviews were collected.")
        return

    dataframe.to_csv(
        OUTPUT_PATH,
        index=False,
        encoding="utf-8-sig",
    )

    print("\nCollection completed.")
    print(f"Rows: {len(dataframe)}")
    print(f"Columns: {len(dataframe.columns)}")
    print(f"Saved to: {OUTPUT_PATH}")
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

