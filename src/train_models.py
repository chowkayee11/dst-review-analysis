import argparse
from pathlib import Path

import pandas as pd
from sklearn.dummy import DummyClassifier
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import StratifiedKFold, cross_validate, train_test_split
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import Pipeline
from sklearn.svm import LinearSVC


DEFAULT_INPUT_PATH = Path("data/processed/dst_reviews_english_text.csv")
DEFAULT_TABLES_DIR = Path("outputs/tables")
RANDOM_STATE = 42


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Train and compare text classifiers for Steam reviews."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT_PATH,
        help="Cleaned review CSV used for modeling.",
    )
    parser.add_argument(
        "--tables-dir",
        type=Path,
        default=DEFAULT_TABLES_DIR,
        help="Directory for generated model tables.",
    )
    parser.add_argument(
        "--test-size",
        type=float,
        default=0.20,
        help="Holdout test-set proportion.",
    )
    parser.add_argument(
        "--cv-folds",
        type=int,
        default=5,
        help="Number of stratified cross-validation folds.",
    )
    return parser.parse_args()


def load_model_data(path: Path) -> tuple[pd.Series, pd.Series, pd.DataFrame]:
    dataframe = pd.read_csv(path)

    if "review" not in dataframe.columns or "voted_up" not in dataframe.columns:
        raise ValueError("Input CSV must contain 'review' and 'voted_up' columns.")

    dataframe = dataframe.dropna(subset=["review", "voted_up"]).copy()
    dataframe["review"] = dataframe["review"].astype(str).str.strip()
    dataframe = dataframe[dataframe["review"].ne("")].copy()

    if not pd.api.types.is_bool_dtype(dataframe["voted_up"]):
        dataframe["voted_up"] = (
            dataframe["voted_up"]
            .astype(str)
            .str.strip()
            .str.lower()
            .map(
                {
                    "true": True,
                    "false": False,
                    "1": True,
                    "0": False,
                }
            )
        )

    dataframe = dataframe.dropna(subset=["voted_up"]).copy()
    dataframe["target"] = dataframe["voted_up"].astype(bool).astype(int)

    return dataframe["review"], dataframe["target"], dataframe


def build_tfidf_classifier(classifier) -> Pipeline:
    return Pipeline(
        steps=[
            (
                "tfidf",
                TfidfVectorizer(
                    lowercase=True,
                    token_pattern=r"(?u)\b[a-zA-Z][a-zA-Z']+\b",
                    ngram_range=(1, 2),
                    min_df=3,
                    max_df=0.95,
                    sublinear_tf=True,
                ),
            ),
            ("classifier", classifier),
        ]
    )


def build_models() -> dict[str, object]:
    return {
        "Majority baseline": DummyClassifier(strategy="most_frequent"),
        "Multinomial NB": build_tfidf_classifier(MultinomialNB()),
        "Linear SVM": build_tfidf_classifier(
            LinearSVC(
                class_weight="balanced",
                random_state=RANDOM_STATE,
                max_iter=5000,
            )
        ),
        "TF-IDF Logistic Regression": build_tfidf_classifier(
            LogisticRegression(
                class_weight="balanced",
                max_iter=2000,
                random_state=RANDOM_STATE,
            )
        ),
    }


def score_predictions(y_true: pd.Series, y_pred) -> dict[str, float]:
    return {
        "accuracy": accuracy_score(y_true, y_pred),
        "macro_f1": f1_score(y_true, y_pred, average="macro", zero_division=0),
        "negative_precision": precision_score(
            y_true,
            y_pred,
            pos_label=0,
            zero_division=0,
        ),
        "negative_recall": recall_score(
            y_true,
            y_pred,
            pos_label=0,
            zero_division=0,
        ),
        "negative_f1": f1_score(y_true, y_pred, pos_label=0, zero_division=0),
        "positive_f1": f1_score(y_true, y_pred, pos_label=1, zero_division=0),
    }


def cross_validation_scores(model, X: pd.Series, y: pd.Series, folds: int) -> dict:
    cv = StratifiedKFold(
        n_splits=folds,
        shuffle=True,
        random_state=RANDOM_STATE,
    )
    scoring = {
        "accuracy": "accuracy",
        "macro_f1": "f1_macro",
        "negative_recall": "recall",
        "negative_f1": "f1",
    }

    y_for_negative_scores = 1 - y
    scores = cross_validate(
        model,
        X,
        y_for_negative_scores,
        cv=cv,
        scoring=scoring,
        n_jobs=None,
    )

    return {
        "cv_accuracy_mean": scores["test_accuracy"].mean(),
        "cv_accuracy_std": scores["test_accuracy"].std(),
        "cv_macro_f1_mean": scores["test_macro_f1"].mean(),
        "cv_macro_f1_std": scores["test_macro_f1"].std(),
        "cv_negative_recall_mean": scores["test_negative_recall"].mean(),
        "cv_negative_recall_std": scores["test_negative_recall"].std(),
        "cv_negative_f1_mean": scores["test_negative_f1"].mean(),
        "cv_negative_f1_std": scores["test_negative_f1"].std(),
    }


def fit_and_compare_models(
    X: pd.Series,
    y: pd.Series,
    test_size: float,
    cv_folds: int,
) -> tuple[pd.DataFrame, Pipeline, pd.Series, pd.Series, pd.Series]:
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=test_size,
        random_state=RANDOM_STATE,
        stratify=y,
    )

    rows = []
    fitted_logistic_model = None
    logistic_predictions = None

    for model_name, model in build_models().items():
        model.fit(X_train, y_train)
        predictions = model.predict(X_test)

        row = {"model": model_name}
        row.update(score_predictions(y_test, predictions))
        row.update(cross_validation_scores(model, X, y, cv_folds))
        rows.append(row)

        if model_name == "TF-IDF Logistic Regression":
            fitted_logistic_model = model
            logistic_predictions = pd.Series(
                predictions,
                index=y_test.index,
                name="prediction",
            )

    comparison = pd.DataFrame(rows).set_index("model")
    return comparison, fitted_logistic_model, logistic_predictions, X_test, y_test


def export_logistic_outputs(
    model: Pipeline,
    predictions: pd.Series,
    X_test: pd.Series,
    y_test: pd.Series,
    source_dataframe: pd.DataFrame,
    tables_dir: Path,
) -> None:
    report = pd.DataFrame(
        classification_report(
            y_test,
            predictions,
            target_names=["Not recommended", "Recommended"],
            output_dict=True,
            zero_division=0,
        )
    ).transpose()
    report.to_csv(tables_dir / "engineered_logistic_regression_report.csv")

    vectorizer = model.named_steps["tfidf"]
    classifier = model.named_steps["classifier"]
    features = pd.DataFrame(
        {
            "term": vectorizer.get_feature_names_out(),
            "coefficient": classifier.coef_[0],
        }
    ).sort_values("coefficient")

    negative_features = features.head(20).assign(direction="Not recommended")
    positive_features = (
        features.tail(20)
        .sort_values("coefficient", ascending=False)
        .assign(direction="Recommended")
    )
    feature_table = pd.concat([positive_features, negative_features])
    feature_table.to_csv(
        tables_dir / "engineered_logistic_regression_features.csv",
        index=False,
    )

    error_rows = source_dataframe.loc[X_test.index].copy()
    error_rows["actual_label"] = y_test.map(
        {0: "Not recommended", 1: "Recommended"}
    )
    error_rows["predicted_label"] = predictions.map(
        {0: "Not recommended", 1: "Recommended"}
    )
    error_rows = error_rows[
        error_rows["actual_label"].ne(error_rows["predicted_label"])
    ]
    error_rows.to_csv(
        tables_dir / "engineered_misclassified_reviews.csv",
        index=False,
        encoding="utf-8-sig",
    )


def main() -> None:
    args = parse_args()
    args.tables_dir.mkdir(parents=True, exist_ok=True)

    X, y, dataframe = load_model_data(args.input)
    comparison, logistic_model, logistic_predictions, X_test, y_test = (
        fit_and_compare_models(
            X=X,
            y=y,
            test_size=args.test_size,
            cv_folds=args.cv_folds,
        )
    )

    comparison.round(4).to_csv(
        args.tables_dir / "engineered_model_comparison.csv"
    )
    export_logistic_outputs(
        model=logistic_model,
        predictions=logistic_predictions,
        X_test=X_test,
        y_test=y_test,
        source_dataframe=dataframe,
        tables_dir=args.tables_dir,
    )

    print("Model comparison")
    print(comparison.round(4))
    print(f"\nSaved tables to: {args.tables_dir}")


if __name__ == "__main__":
    main()
