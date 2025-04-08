import pandas as pd

# Read the parquet file
df = pd.read_parquet('train.parquet')

# Print column names
print("Column names:")
print(df.columns.tolist())

# Print the first row
print("\nFirst row:")
# Use pd.set_option to display all content without truncation
pd.set_option('display.max_colwidth', None)
print(df.iloc[0].to_dict())
