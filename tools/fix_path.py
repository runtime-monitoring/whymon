#!/usr/bin/env python3

import os
import sys

with open("vis/public/index.html") as infile:
    with open("vis/public/index_fixed.html", 'w') as outfile:

        for line in infile:

            if "whymon/whymon.bc.js" in line:
                line = line.replace("whymon/whymon.bc.js", "whymon.bc.js")
            elif "whymon.bc.js" in line:
                line = line.replace("whymon.bc.js", "whymon/whymon.bc.js")

            outfile.write(line)

        outfile.close()

    infile.close()

    os.remove("vis/public/index.html")
    os.rename("vis/public/index_fixed.html", "vis/public/index.html")
    print("Successfully fixed WhyMon's JS path in vis/public/index.html")
