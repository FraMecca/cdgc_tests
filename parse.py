import pandas as pd
pd.options.display.float_format= '{:.6f}'.format

import sys

for s in sys.argv[1:]:
    df = pd.read_csv(s)
    df = df.drop('Unnamed: 4', axis=1)
    print(s+ ':')
    with pd.option_context('display.max_rows', None, 'display.max_columns', None):
        print(df)
    print()
