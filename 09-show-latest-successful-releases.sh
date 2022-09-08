#!/bin/bash
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Created with codelabba.rb v.1.4a
source .env.sh || fatal "Config doesnt exist please create .env.sh"
#set -x
#set -e

PIPELINE="${1:-dunno}"
VERBOSE="false"
AUTO_PROMOTE_DEV_TO_STAGING="true"
MAX_ROWS="50"

if echo $PIPELINE | grep -q dunno ; then
    echo 'WARNING. Give me "app01" or "app02" in ARGV1 or for both just call: make show-latest-succesful-releases'
    exit 102
fi

# Add your code here:
echo 10. INSPECTING CD PIPELINE="$PIPELINE"
gcloud deploy releases list --delivery-pipeline "$PIPELINE" \
    --region "$REGION" \
    --filter renderState=SUCCEEDED \
    --format="table[box,title='Latest Successful Releases for $PIPELINE'](createTime:sort=1, name:label=LongBoringName, renderState, skaffoldVersion, skaffoldConfigPath)" \
    --sort-by=~createTime \
    --limit="$MAX_ROWS"
#    --format yaml # 'multi(targetRenders.*.renderingState)'

# this teaches how to sort subfields iwthin an item not how to sort items. https://stackoverflow.com/questions/69527048/trying-to-reverse-the-sequence-of-values-returned-by-my-gcloud-query
# useless here
#gcloud deploy releases list --delivery-pipeline "$RELEASE" --filter renderState=SUCCEEDED \
#    --format="value(createTime, name)" --sort-by=createTime
# A field to sort by, if applicable. To perform a descending-order sort, prefix the value with a tilde ("~").
# https://cloud.google.com/compute/docs/gcloud-compute/tips
# BINGO!

yellow 20. Lets now print out just the release name..
#gcloud deploy releases list --delivery-pipeline app02 --filter renderState=SUCCEEDED  # --format 'multi(targetRenders.canary.renderingState)'
# gcloud deploy releases list --delivery-pipeline "$PIPELINE" --filter renderState=SUCCEEDED \
#    --format="value(name.split.7)"

# this gets the last release, eg 'projects/cicd-platinum-test001/locations/europe-west1/deliveryPipelines/app02/releases/app02-20220603-1621'
# then gcloud tokenizes it into semicolons, ive tried hard to do name.split()[7] but didnt work and couldnt find gcloud documentation on other functions like split.
LATEST_SUCCESSFUL_RELEASE=$(
    gcloud deploy releases list --delivery-pipeline "$PIPELINE" \
    --filter renderState=SUCCEEDED \
    --format="value(name.split())" \
    --sort-by=~createTime --limit 100 |
    cut -d';' -f 8 |
    head -1
    )
# I care about:
# 1. createTime: '2022-06-03T16:21:20.718745Z'
echo "the LATEST_SUCCESSFUL_RELEASE for this PIPELINE $PIPELINE is: '$LATEST_SUCCESSFUL_RELEASE' !!"

if $VERBOSE ; then
    gcloud deploy releases list --delivery-pipeline "$PIPELINE" --filter renderState=SUCCEEDED
    #--limit "$MAX_ROWS"
fi


# End of your code here
_allgood_post_script
echo Everything is ok.
