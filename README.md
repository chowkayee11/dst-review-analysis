# Steam Review Analysis: Don't Starve Together

A game data analytics project based on Steam reviews for *Don't Starve Together*, covering data collection, exploratory analysis, SQL analytics, player segmentation, statistical testing, text analysis, and machine learning.

## Project Overview

Steam reviews contain both recommendation labels and detailed player behaviour data. This project analyses recent reviews to answer the following questions:

- What is the overall positive review rate?
- How have review volume and positive rate changed over time?
- Do positive and negative reviewers differ in playtime?
- Are negative reviews longer or more detailed?
- Which review topics are associated with positive and negative feedback?
- Can review text be used to predict whether a player recommends the game?

## Dataset

- Game: Don't Starve Together
- Steam AppID: `322330`
- Raw reviews collected: `5,000`
- Valid reviews after cleaning: `4,974`
- Reviews used for English text analysis: `4,511`
- Review period: 25 November 2025 to 5 August 2026
- Overall positive rate: `90.71%`

The data was collected using the Steam review endpoint. For public sharing, the raw review-text files can be excluded and regenerated with the collection script.

## Project Workflow

1. Collect recent Steam reviews using a paginated request script
2. Validate raw data quality and check duplicate review IDs
3. Clean review data and engineer time, playtime, and text-length features
4. Detect and filter non-English text for NLP analysis
5. Perform exploratory data analysis
6. Compare positive and negative review themes
7. Build and evaluate TF-IDF logistic regression models
8. Inspect classification errors and important model features
9. Build a normalized SQLite database
10. Analyse monthly metrics, playtime segments, and review themes with SQL
11. Apply statistical tests and confidence intervals to validate EDA findings
12. Compare analytical results and document business implications

## Key Findings

### 1. Review Distribution

The cleaned dataset contains 4,974 reviews. Of these, 4,512 recommend the game and 462 do not.

![Review distribution](./outputs/figures/01_review_distribution.png)

The recommendation labels are strongly imbalanced. Positive reviews account for 90.71% of the sample.

### 2. Monthly Review Activity

Review volume was relatively stable from December 2025 to May 2026. It increased to 890 reviews in June and remained high at 777 reviews in July.

![Monthly review volume](outputs/figures/02_monthly_review_volume.png)

November 2025 and August 2026 are incomplete months and should not be directly compared with complete months.

### 3. Monthly Positive Rate

The positive rate remained close to 90% during most complete months. It declined from 91.1% in April 2026 to 88.9% in July 2026.

![Monthly positive rate](outputs/figures/03_monthly_positive_rate.png)

The chart identifies a recent change in review sentiment but does not establish its cause.

### 4. Playtime and Recommendation Behaviour

Positive reviewers had substantially more playtime when submitting their reviews.

| Review category | Median playtime at review |
|---|---:|
| Recommended | 32.84 hours |
| Not recommended | 7.79 hours |

![Playtime by recommendation](outputs/figures/04_playtime_by_review_category.png)

The median playtime of positive reviewers was approximately 4.2 times that of negative reviewers. This suggests that negative feedback was more common during the earlier player experience.

### 5. Review Length

Negative reviews were generally more detailed.

| Review category | Median review length |
|---|---:|
| Recommended | 6 words |
| Not recommended | 13 words |

![Review length](outputs/figures/05_review_length_by_category.png)

The positive rate also decreased as review length increased.

![Positive rate by review length](outputs/figures/06_positive_rate_by_review_length.png)

Very short reviews had a positive rate of 93.7%, compared with 77.6% for very long reviews. This is an association and should not be interpreted as a causal relationship.

### 6. Helpful Votes

Negative reviews were more likely to receive at least one helpful vote.

| Review category | Reviews with helpful votes |
|---|---:|
| Recommended | 13.9% |
| Not recommended | 38.5% |

![Helpful votes](outputs/figures/07_helpful_vote_rate_by_category.png)

The higher rate may partly reflect the greater length and detail of negative reviews. Review age and visibility may also affect helpful-vote counts.

## Text Theme Analysis

Keyword rules were used to identify major themes in the English review data. A review could contain more than one theme.

![Theme comparison](outputs/figures/10_review_theme_comparison.png)

### Positive Themes

The strongest positive themes were:

- Fun and enjoyment: 34.35% of positive reviews
- Social and multiplayer experience: 17.44%
- Learning and challenge: 3.74%
- Art and visual style: 2.93%

![Positive themes](outputs/figures/12_positive_review_themes.png)

### Negative Issues

The most common issues in negative reviews were:

- Repetition and boredom: 9.81%
- Onboarding and guidance: 9.33%
- Progression and clarity: 9.09%
- Difficulty and punishment: 6.46%
- Time and value: 2.87%

![Negative issues](outputs/figures/11_negative_review_issues.png)

The results suggest that difficulty is not always viewed negatively. Challenge appeared in both positive and negative reviews, while insufficient guidance and unclear progression were more strongly associated with negative feedback.

## SQL Analysis

A SQLite analysis module was added to demonstrate practical SQL skills using the processed English-language review dataset.

The database contains three normalized tables:

- `reviews`
- `themes`
- `review_themes`

The SQL analysis includes:

- Data quality checks
- Monthly review metrics
- Playtime-based review segmentation
- Theme analysis using multi-table joins
- Common Table Expressions
- Conditional aggregation
- Window functions including `LAG`, `RANK`, and `DENSE_RANK`

### Key SQL Findings

The SQL analysis was conducted on 4,511 English-language reviews.

- The overall recommendation rate was 90.73%.
- June 2026 had the highest review volume with 799 reviews.
- Recommendation rate increased from 58.78% among reviews submitted before two hours of playtime to 96.19% among reviews submitted after 200 hours.
- Negative reviews were more strongly associated with repetition, unclear progression, and onboarding problems.
- `Repetition and boredom` had a negative-rate lift of 4.42.
- `Progression and clarity` had a negative-rate lift of 3.54.
- `Onboarding and guidance` had a negative-rate lift of 3.16.

The SQL files are available in the `sql/` directory, while `notebooks/06_sql_analysis.ipynb` presents selected queries and interpretations.

## Statistical Testing

Statistical tests were used to evaluate whether several patterns identified during exploratory analysis were statistically meaningful.

The tests were conducted on the full cleaned dataset of 4,974 reviews.

### Main Results

| Analysis | Test | Result | Effect size |
|---|---|---|---|
| Playtime by recommendation | Mann–Whitney U | p < 0.001 | Rank-biserial = 0.397 |
| Review length by recommendation | Mann–Whitney U | p < 0.001 | Rank-biserial = -0.259 |
| Helpful vote by recommendation | Chi-square | p < 0.001 | Cramér's V = 0.193 |
| Recommendation rate by month | Chi-square | p = 0.916 | Cramér's V = 0.024 |

### Interpretation

Recommended reviews were submitted after a median of 32.84 hours of playtime, compared with 7.79 hours for non-recommended reviews.

Non-recommended reviews were longer, with a median of 13 words compared with 6 words for recommended reviews.

Negative reviews were also more likely to receive at least one helpful vote, with rates of 38.53% and 13.90% respectively.

However, monthly recommendation rates did not differ significantly after incomplete months were excluded. This suggests that visible month-to-month fluctuations should not be interpreted as evidence of a systematic change in player sentiment.

![Monthly positive rate confidence intervals](outputs/figures/17_monthly_positive_rate_confidence_intervals.png)

The full statistical analysis is available in `notebooks/07_statistical_testing.ipynb`.

## Text Classification

A TF-IDF logistic regression model was trained to predict whether a review was recommended. A separate training script also compares this model with a majority baseline, Multinomial Naive Bayes, and Linear SVM.

The dataset was split into an 80% training set and a 20% test set using stratified sampling. Balanced class weights were applied because negative reviews were the minority class.

### Model Performance

| Metric | Baseline | TF-IDF Logistic Regression |
|---|---:|---:|
| Accuracy | 0.91 | 0.87 |
| Macro F1 | 0.48 | 0.71 |
| Negative recall | 0.00 | 0.68 |
| Negative F1 | 0.00 | 0.50 |

![Model comparison](outputs/figures/16_model_comparison.png)

The baseline model achieved high accuracy by predicting every review as positive. It failed to identify any negative reviews.

The logistic regression model correctly identified 57 of the 84 negative reviews in the test set. Its negative recall reached 67.9%, and its macro F1-score increased to 0.712.

In the scripted model comparison, Linear SVM achieved the strongest holdout macro F1 among the tested text models, while Logistic Regression achieved the highest negative-review recall. This trade-off is useful because missing negative reviews is more costly for product-feedback analysis than misclassifying some positive reviews.

![Confusion matrix](outputs/figures/13_logistic_regression_confusion_matrix.png)

### Model Interpretation

Important positive features included `fun`, `good`, `love`, `friends`, and `great`.

![Positive model features](outputs/figures/14_model_positive_features.png)

Important negative features included `not`, `boring`, `no`, `trash`, `bad`, and `worst`.

![Negative model features](outputs/figures/15_model_negative_features.png)

Logistic regression coefficients indicate the direction and relative strength of a text feature. They should not be interpreted as probabilities or causal effects.

## Error Analysis

The model misclassified:

- 88 positive reviews as negative
- 27 negative reviews as positive

Common causes included:

- Very short reviews with limited context
- Mixed positive and negative opinions
- Sarcasm and humour
- Indirect expressions of dissatisfaction
- Review labels that did not match the written text
- Symbols and expressions removed during text preprocessing

The error analysis shows that TF-IDF logistic regression can identify common sentiment expressions but has limited understanding of context, irony, and implicit meaning.

## Project Structure

```text
dst-review-analysis/
├── data/
│   ├── database/
│   ├── processed/
│   └── raw/
├── notebooks/
│   ├── 01_data_quality_check.ipynb
│   ├── 02_data_cleaning.ipynb
│   ├── 03_exploratory_analysis.ipynb
│   ├── 04_text_analysis.ipynb
│   ├── 05_text_classification.ipynb
│   ├── 06_sql_analysis.ipynb
│   └── 07_statistical_testing.ipynb
├── outputs/
│   ├── figures/
│   └── tables/
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_data_quality_checks.sql
│   ├── 03_monthly_metrics.sql
│   ├── 04_player_segmentation.sql
│   └── 05_theme_analysis.sql
├── src/
│   ├── build_sqlite_database.py
│   ├── collect_reviews.py
│   └── train_models.py
├── .gitignore
├── README.md
└── requirements.txt
```

## Technologies

- Python 3.9
- SQL / SQLite
- pandas
- NumPy
- SciPy
- matplotlib
- scikit-learn
- requests
- langdetect
- JupyterLab


## Reproducing the Project

The raw review dataset, processed review-text datasets, and local SQLite database are not included in the repository. They are generated locally by following the steps below.

### 1. Clone the Repository

```bash
git clone https://github.com/chowkayee11/dst-review-analysis.git
cd dst-review-analysis
```

### 2. Create a Virtual Environment

Create a Python virtual environment:

```bash
python3 -m venv .venv
```

Activate it on macOS or Linux:

```bash
source .venv/bin/activate
```

On Windows:

```bash
.venv\Scripts\activate
```

### 3. Install Dependencies

```bash
python -m pip install -r requirements.txt
```

### 4. Collect Steam Reviews

Run the data collection script:

```bash
python src/collect_reviews.py
```

The script collects recent Steam reviews for *Don't Starve Together* and stores the raw review data locally under:

```text
data/raw/
```

Raw review data is excluded from Git because it can be regenerated using the collection script.

### 5. Start JupyterLab

```bash
jupyter lab
```

Open the `notebooks/` directory and run the following notebooks in order.

### 6. Data Quality Check

```text
01_data_quality_check.ipynb
```

This notebook checks the raw dataset for:

- duplicate review IDs
- missing review text
- missing values
- recommendation distribution
- basic data-quality issues

### 7. Data Cleaning and Feature Engineering

```text
02_data_cleaning.ipynb
```

This notebook:

- removes invalid or empty reviews
- converts timestamps to readable dates
- converts playtime from minutes to hours
- creates review-length features
- creates monthly date fields
- detects review language
- filters data for English-language text analysis

Processed datasets are written locally under:

```text
data/processed/
```

### 8. Exploratory Data Analysis

```text
03_exploratory_analysis.ipynb
```

This notebook analyses:

- overall recommendation distribution
- monthly review volume
- monthly recommendation rate
- playtime by recommendation category
- review length
- helpful votes
- Steam purchase status
- free-copy status

Figures and summary tables are saved under:

```text
outputs/figures/
outputs/tables/
```

### 9. Text and Theme Analysis

```text
04_text_analysis.ipynb
```

This notebook performs:

- word-frequency analysis
- positive and negative term comparison
- bigram analysis
- contextual review inspection
- rule-based review theme identification
- positive-theme and negative-issue comparison

The resulting review-theme dataset is saved locally for later SQL analysis.

### 10. Text Classification

```text
05_text_classification.ipynb
```

This notebook:

- creates a most-frequent baseline classifier
- converts review text to TF-IDF features
- trains a class-weighted logistic regression model
- evaluates the model using accuracy, recall, F1-score, and macro F1
- analyses the confusion matrix
- examines important positive and negative text features
- inspects misclassified reviews

The classification analysis is designed to account for the strong class imbalance between recommended and non-recommended reviews.

### 11. Build the SQLite Database

After notebooks `01` through `05` have been completed, build the local SQLite database:

```bash
python src/build_sqlite_database.py
```

The script creates:

```text
data/database/dst_reviews.db
```

The database uses three normalized tables:

```text
reviews
themes
review_themes
```

The script also validates the table relationships using SQLite foreign-key checks.

The `.db` file is excluded from Git and is regenerated locally when needed.

### 12. Run the SQL Analysis

Open and run:

```text
06_sql_analysis.ipynb
```

The SQL analysis covers:

- SQL-based data-quality validation
- monthly review metrics
- conditional aggregation
- playtime-based review segmentation
- multi-table joins
- review-theme analysis
- Common Table Expressions
- `CASE WHEN`
- `LAG`
- `RANK`
- `DENSE_RANK`
- running totals
- rolling metrics

The complete SQL queries are also available under:

```text
sql/
├── 01_create_tables.sql
├── 02_data_quality_checks.sql
├── 03_monthly_metrics.sql
├── 04_player_segmentation.sql
└── 05_theme_analysis.sql
```

### 13. Run the Statistical Analysis

Open and run:

```text
07_statistical_testing.ipynb
```

This notebook validates key findings from the exploratory analysis using:

- Mann–Whitney U tests
- chi-square tests of independence
- rank-biserial correlation
- Cramér's V
- 95% confidence intervals

The statistical analysis evaluates differences in:

- playtime between recommended and non-recommended reviews
- review length
- helpful-vote rates
- monthly recommendation behaviour

### 14. Recommended Execution Order

The complete workflow is:

```text
python src/collect_reviews.py

01_data_quality_check.ipynb
02_data_cleaning.ipynb
03_exploratory_analysis.ipynb
04_text_analysis.ipynb
05_text_classification.ipynb

python src/build_sqlite_database.py

06_sql_analysis.ipynb
07_statistical_testing.ipynb
```

### 15. Generated Files

The workflow generates local data and analysis outputs under:

```text
data/raw/
data/processed/
data/database/
outputs/figures/
outputs/tables/
```

Raw review data, processed review-text datasets, and the SQLite database are intentionally excluded from version control where appropriate. The analysis code, SQL queries, figures, and aggregated result tables remain available in the repository.

### 16. Reproducibility Check

For each notebook, use:

```text
Restart Kernel and Run All Cells
```

to verify that the notebook can run from start to finish without relying on variables left in memory from previous sessions.

## Scripted Model Reproduction

The modeling step can be reproduced without opening Jupyter:

```bash
python src/train_models.py \
  --input data/processed/dst_reviews_english_text.csv \
  --tables-dir outputs/tables \
  --test-size 0.20 \
  --cv-folds 5
```

This script trains and compares:

- Majority-class baseline
- TF-IDF Multinomial Naive Bayes
- TF-IDF Linear SVM
- TF-IDF Logistic Regression with balanced class weights

It exports:

- `outputs/tables/engineered_model_comparison.csv`
- `outputs/tables/engineered_logistic_regression_report.csv`
- `outputs/tables/engineered_logistic_regression_features.csv`
- `outputs/tables/engineered_misclassified_reviews.csv`

This scripted path makes the classification result easier to reproduce and gives the project a clearer engineering workflow beyond exploratory notebooks.

## Limitations

- The dataset contains recent reviews rather than all historical reviews.
- The first and final months are incomplete.
- Steam language labels do not guarantee that every review is written in English.
- Automatic language detection may misclassify short reviews.
- Rule-based theme analysis depends on manually defined keyword patterns.
- Helpful votes may be affected by review age and visibility.
- The classification model has limited ability to understand sarcasm, humour, and complex context.
- The dataset is strongly imbalanced, with substantially fewer negative reviews.

## Possible Improvements

Future work could include:

- Collecting a larger historical dataset
- Connecting review trends with game update dates
- Comparing reviews across several survival games
- Adding regression-based controls for review age, visibility, and playtime when analysing helpful votes
- Testing transformer-based text classification models
- Using topic modelling to identify themes automatically
- Developing an interactive dashboard with Streamlit or Power BI
