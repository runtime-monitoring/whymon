#!/usr/bin/env python
# coding: utf-8

# Generating SSO Monitoring Trace

import pandas as pd
import matplotlib.pyplot as plt
import random
import subprocess, sys

# Importing the data

# Data from: https://www.kaggle.com/datasets/dasgroup/rba-dataset?resource=download
file_path = './rba-dataset.csv'
df = pd.read_csv(file_path)

# Display shape and the name of the columns about the data
print("DataFrame Shape:", df.shape)
print("DataFrame Columns:", df.columns)

# Filtering, sorting, and formatting the data

################################################################
# According to DATA_README.md:
# The data is mostly from Norway, and `City` is more useful for us -> Remove 'Country', and 'Region'.
# 'Country', 'Region', 'City', and 'ASN' come from 'IP Address' -> Remove them
# 'Browser Name and Version', 'OS Name and Version', and 'Device Type' come from 'User Agent String' -> Remove them
################################################################
to_remove = ['Country', 'Region', 'City', 'ASN', 'Browser Name and Version', 'OS Name and Version', 'Device Type']

# Do not remove rows with NaN because many of those contain successful 'Is Account Takeover's
filtered_df = df.drop(columns=to_remove)#.dropna()

# Rename 'Login Timestamp' to simpler 'Datetime'
filtered_df.rename(columns={"Login Timestamp": "Datetime"}, inplace = True)

# Display basic information about the data
# filtered_df.info()

# Turning 'Datetime' entries into 'datetime64'
filtered_df['Datetime'] = pd.to_datetime(filtered_df['Datetime'])

# Adding timestamps
timestamps = (filtered_df['Datetime'].apply(lambda x: x.value).astype(int)).rename("Timestamp", inplace = True)
sorted_df = pd.concat([filtered_df.iloc[:, :2], timestamps, filtered_df.iloc[:, 2:]], axis=1)

# Sorting
sorted_df = sorted_df.sort_values(by='Datetime')

# Substract the lowest timestamp to all timestamps
lowest = sorted_df['Timestamp'].iloc[0]
sorted_df['Timestamp'] = sorted_df['Timestamp'].apply(lambda x: x - lowest)

# sorted_df.info()

# To have more manageable 'Timestamp's, we find the smallest differences between 'Datetime' entries
# and filter those entries that have less than 10 miliseconds between them.
x=0.01 # 10 miliseconds
time_diff = sorted_df['Datetime'].diff().rename("Diffs", inplace = True)
within_x = (time_diff < pd.Timedelta(seconds=x)).rename("Within10ms", inplace = True)
df_within_x = sorted_df[within_x]
df_within_x = pd.concat([df_within_x.iloc[:, :2], time_diff[within_x], within_x, df_within_x.iloc[:, 2:]], axis=1)

# All those values within 10 miliseconds
# df_within_x[df_within_x['Within10ms']==True]

# Cheating dividing by 10**6 to convert from nanoseconds to miliseconds
df_within_x['Diffs'] = df_within_x['Diffs'].apply(lambda x: x.value/(10**6)).astype(int)
df_within_x['Timestamp'] = df_within_x['Timestamp'].apply(lambda x: x/(10**6))

# Minimal value (other than 0) is 1 milisecond
df_within_x[df_within_x['Within10ms']==True]['Diffs'].where(lambda x: x != 0).min()

# Alternative, more informative but less efficient approach for code above
# expanded_df = pd.concat([sorted_df.iloc[:, :2], time_diff, within_x, sorted_df.iloc[:, 2:]], axis=1)
# expanded_df[expanded_df['Within10ms'] == True]['Diffs'].where(lambda x: x != 0).min()

# Since 1*10**3 secs is the minimal difference (other than 0) and timestamps are in nanoseconds (10**9),
# we divide by (10**6)
sorted_df['Timestamp'] = sorted_df['Timestamp'].apply(lambda x: x/(10**6)).astype(int)

sorted_df.head()

# Printing the data as a log
seen_ids = []
start_index = 0 #482000 # searching for ip: 2.56.166.10 with successful takeover at index 482034
with open('rba-dataset.log', 'w') as file:
    # for index, row in sorted_df.iloc[start_index:start_index+200].iterrows():
    for index, row in sorted_df.iterrows():
        user_id = row['User ID']
        if user_id in seen_ids:
            id_to_print = seen_ids.index(user_id)
        else:
            id_to_print = len(seen_ids)
            seen_ids.append(user_id)
        row_data = f"@{row['Timestamp']} attempt({id_to_print}, \"{row['IP Address']}\", \"{row['Login Successful']}\")"
        # row_data = f"@{row['Timestamp']} attempt({id_to_print}, {row['IP Address']}, {row['Login Successful']}, {row['Is Account Takeover']})"
        file.write(row_data + '\n')
