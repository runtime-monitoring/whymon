#!/usr/bin/env python3

import sys
import csv
import math
from datetime import datetime

def quit():
    print('usage: python convert_rba.py file_name.csv')
    exit(1)


if (len(sys.argv)) < 2:
    quit()

file_name = sys.argv[1]
out_file_name = file_name.split('.')[0] + '.log'

# try:
with open(file_name) as csvfile:
    with open(out_file_name, 'w') as writer:

        reader = csv.reader(csvfile, delimiter=',')
        header = next(reader)

        for row in reader:

            # timestamp
            _datetime = row[1].split(' ')
            _date = _datetime[0].split('-')
            _time = (_datetime[1].split('.'))[0].split(':')
            ts1 = datetime(int(_date[0]), int(_date[1]), int(_date[2]), int(_time[0]), int(_time[1]), int(_time[2]))
            ts2 = datetime(1970, 1, 1)
            ts = (ts1 - ts2).total_seconds()

            # attempt: user, ip, login successful
            user = row[2]
            ip = row[4]
            successful = row[13]

            # event
            writer.write('@' + str(int(ts)) + ' attempt(\"' + user + '\",\"' + ip + '\",' + successful + ')\n')

# except:
#     quit()
