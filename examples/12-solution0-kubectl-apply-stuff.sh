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
source .env.sh || fatal 'Couldnt source this'
set -e

############################################################
# [RICC01] sol0 SetUp #MultiAppK8sRefactoring
###########################################################
DEFAULT_APP="app01"                                # app01 / app02
#DEFAULT_APP_IMAGE="skaf-app01-python-buildpacks"   # skaf-app01-python-buildpacks // ricc-app02-kuruby-skaffold
DEFAULT_APP_SELECTOR="app01-kupython"     # app01-kupython / app02-kuruby

APP_NAME="${1:-$DEFAULT_APP}"
export K8S_APP_SELECTOR="${2:-$DEFAULT_APP_SELECTOR}"
############################################################
# [RICC01] Troubleshooting info..
###########################################################

#if /bin/false ; then # restore when part 2 works :) and re_add when its too slow or youre in debug mode.

    # Cluster 1
    #yellow Lets recall that: CLUSTER_1="$CLUSTER_1"
    #yellow Lets recall that: CLUSTER_2="$CLUSTER_2"
    #yellow "Try now for cluster1=$CLUSTER_1 kubectl apply -f  $GKE_SOLUTION0_ILB_SETUP_DIR/cluster1/"
    #kubectl config get-contexts
    #_kubectl_on_both_canary_and_prod get gatewayclass
    bin/kubectl-triune get gatewayclass

#fi
############################################################
# [RICC02] HYDRATE TEMPLATES the hard way :)
###########################################################
#APPNAME="This should fail !! @ ~ argh" # otherwise takes .env/sh which is a good string :)
for CLUSTER in cluster1 cluster2 ; do
    # In case I get it wrong.. :)
    APPNAME="$APP_NAME"
    APP_SELECTOR="$K8S_APP_SELECTOR"
    # apply smart substitutions..
    smart_apply_k8s_templates_with_envsubst \
        "$GKE_SOLUTION0_ILB_SETUP_DIR/templates/$CLUSTER/" \
        "$GKE_SOLUTION0_ILB_SETUP_DIR/out/$CLUSTER/"
done
#envsubst


red "WARNING: The ILB selector just uses canary-or-prod, not appname. Once it works and OVER reaches I can then specify. This fix is for another day."

set -x

############################################################
# [RICC03] APPLY
###########################################################
# Step 6. Apply the GW Config on Cluster 1.
DELETE_K8S_STUFF_BEFORE_APPLY="false"

if "$DELETE_K8S_STUFF_BEFORE_APPLY" ; then
    # DELETE ALL BEFORE applying in case something is stuck
    yellow "Deleting cluster config and re-applying.."
    kubectl --context="$GKE_CANARY_CLUSTER_CONTEXT" delete -f "$GKE_SOLUTION0_ILB_SETUP_DIR/out/cluster1/" ||
        echo Might fail but still good to run it.
    kubectl --context="$GKE_PROD_CLUSTER_CONTEXT"   delete -f "$GKE_SOLUTION0_ILB_SETUP_DIR/out/cluster2/" ||
        echo Might fail but still good to run it.
    sleep 5
fi

# this is the STATIC by Daniel, not the multitenant from jul15: #MultiAppK8sRefactoring
kubectl --context="$GKE_CANARY_CLUSTER_CONTEXT" apply -f "$GKE_SOLUTION0_ILB_SETUP_DIR/out/cluster1/"
kubectl --context="$GKE_PROD_CLUSTER_CONTEXT"   apply -f "$GKE_SOLUTION0_ILB_SETUP_DIR/out/cluster2/"

echo Restoring cluster 1.
gcloud container clusters get-credentials "$CLUSTER_1"  --region "$GCLOUD_REGION" --project "$PROJECT_ID"

# white "Solution0 - related endpoints:"
# make endpoints-show | grep "sol0" ||
#     _fatal "No SOL0 endpoints found. Exiting"

# This means that app01 ILB diverts traffic to both app01 and app02 apps. And same for app02 ILB.
# Until I get this to work its pointless to restrict thje traffic further as having more endpoints ultimately helps.
red "WARNING: The ILB hasnt been tested yet. TODO(ricc): Try creating a GCE vm and curl the internal ILB IP: "
gcloud compute forwarding-rules list |grep ilb | lolcat

# End of your code here
_allgood_post_script
echo Everything is ok.
