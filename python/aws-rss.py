#!/usr/bin/env python3

import argparse
import requests
import re

aws_status_page = "https://status.aws.amazon.com"
rss_filename_pattern = "rss-urls-{{region}}.txt"

parser = argparse.ArgumentParser(description="AWS RSS Status Feed URL Dumper")
parser.add_argument("--local_index", "-l")
args = parser.parse_args()

index_data = None
if args.local_index:
    with open(args.local_index, "rt") as f:
        index_data = f.read()
else:
    index_data = requests.get(aws_status_page, allow_redirects=true).text

rss_feeds = set(re.findall(r"/rss/.*\.rss", index_data))
services_per_region = set([feed[5:-4] for feed in rss_feeds])

regions = dict()
for ec2_region in list(filter(re.compile(r"^ec2-").match, services_per_region)):
    regions[ec2_region[4:]] = set([ec2_region[4:]])
regions["us-east-1"].add("us-standard")

regional_services = set()
global_services = services_per_region.copy()
for region, aliases in regions.items():
    services = set()
    for alias in aliases:
        services.update(filter(re.compile(f"{alias}$").search, services_per_region))
    rss_file = open(re.sub("{{region}}", region, rss_filename_pattern), "wt")
    for service in sorted(list(services)):
        rss_file.write(f"{aws_status_page}/rss/{service}.rss\n")
        global_services.remove(service)
    rss_file.close()
rss_file = open(re.sub("{{region}}", "global", rss_filename_pattern), "wt")
for service in sorted(list(global_services)):
    rss_file.write(f"{aws_status_page}/rss/{service}.rss\n")
rss_file.close()
rss_file = open(re.sub("{{region}}", "all", rss_filename_pattern), "wt")
for rss_feed in sorted(list(rss_feeds)):
    rss_file.write(f"{aws_status_page}{rss_feed}\n")
rss_file.close()
