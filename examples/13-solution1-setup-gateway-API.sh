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
#set -x
set -e

########################################################################
# RICC00. ARGV -> vars for MultiAppK8sRefactoring
########################################################################
# TODO: array of 2 or maybe even better bash hash: https://stackoverflow.com/questions/1494178/how-to-define-hash-tables-in-bash
DEFAULT_APP="app01"                       # app01 / app02
DEFAULT_APP_SELECTOR="app01-kupython"     # app01-kupython / app02-kuruby
DEFAULT_APP_IMAGE="skaf-app01-python-buildpacks"   # skaf-app01-python-buildpacks // ricc-app02-kuruby-skaffold

APP_NAME="${1:-$DEFAULT_APP}"

K8S_APP_SELECTOR="${AppsInterestingHash["$APP_NAME-SELECTOR"]}"
K8S_APP_IMAGE="${AppsInterestingHash["$APP_NAME-IMAGE"]}"

export URLMAP_NAME_SOL1="${APP_NAME}-sol1-$URLMAP_NAME_MTSUFFIX"        # eg: "app02-sol1-BLAHBLAH"
export FWD_RULE_SOL1="${APP_NAME}-sol1-${FWD_RULE_MTSUFFIX}"            # eg: "app02-sol1-BLAHBLAH"
export CLUSTER_DEV="cicd-dev"
########################################################################
# Add your code here:
########################################################################

echo "##############################################"
yellow "WORK IN PROGRESS! huge multi-tennant refactor in progress"
#yellow "TODO(ricc): everything is multi-tennant except the FWD RULE part. Shouls have app01/02 in it.."
#yellow "Deploy the GKE manifests. This needs to happen first as it creates the NEGs which this script depends upon."

echo "APP_NAME:         $APP_NAME"
echo "URLMAP_NAME_SOL1: $URLMAP_NAME_SOL1"
echo "FWD_RULE_SOL1:    $FWD_RULE_SOL1"
echo "K8S_APP_SELECTOR: $K8S_APP_SELECTOR (useless in sol1)"
echo "K8S_APP_IMAGE:    $K8S_APP_IMAGE    (useless in sol1)"
echo "GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR:       $GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR"
echo "##############################################"

yellow "Usage (as I want it): $0 [app01|app02]"
white "Now I proceed to apply solution 1 for: $APP_NAME. If wrong, call me with proper usage."

##################################################
## dmarzi001 enable required APIs (project level)
##################################################

# Refactored in 00-init.

# gcloud services enable \
#     container.googleapis.com \
#     gkehub.googleapis.com \
#     multiclusterservicediscovery.googleapis.com \
#     multiclusteringress.googleapis.com \
 #   trafficdirector.googleapis.com

##################################################
## dmarzi001.5 SetUp Workload ~Identity
##################################################

gcloud container clusters update cicd-dev \
    --region=$REGION \
    --workload-pool=$PROJECT_ID.svc.id.goog

# gcloud container clusters update cicd-prod \
#     --region=$REGION \
#     --workload-pool=$PROJECT_ID.svc.id.goog
# gcloud container clusters update cicd-canary \
#     --region=$REGION \
#     --workload-pool=$PROJECT_ID.svc.id.goog
# green 'To update your current NodePools to use WokkLoadIdendity use this magic and breaking command (note GKE_METADATA doesnt need change):'
# echo gcloud container node-pools update NODEPOOL_NAME_CHANGEME \
#     --cluster=$CLUSTER_NAME \
#     --workload-metadata=GKE_METADATA

##################################################
## dmarzi002 register clusters to the fleet (cluster level)
##################################################

#white "Skipping step2 since it was already done for Solution0."
# Actually lets get it back since... SOL0 might go to sleep :)
_gcloud_container_fleet_memberships_register_if_needed cicd-dev
_gcloud_container_fleet_memberships_register_if_needed "$CLUSTER_1"
_gcloud_container_fleet_memberships_register_if_needed "$CLUSTER_2"
# gcloud container fleet memberships register "$CLUSTER_1" \
#      --gke-cluster "$GCLOUD_REGION/$CLUSTER_1" \
#      --enable-workload-identity \
#      --project="$PROJECT_ID" --quiet

# gcloud container fleet memberships register "$CLUSTER_2" \
#      --gke-cluster "$GCLOUD_REGION/$CLUSTER_2" \
#      --enable-workload-identity \
#      --project="$PROJECT_ID" --quiet

# # only for the New Generation SOL1 which uses also DEV.
# gcloud container fleet memberships register "$CLUSTER_DEV" \
#      --gke-cluster "$GCLOUD_REGION/$CLUSTER_DEV" \
#      --enable-workload-identity \
#      --project="$PROJECT_ID" --quiet


# default to PROD #CanProd2Dev4debug
gcloud container clusters get-credentials "cicd-prod" --region "$REGION" # --project "$PROJECT_ID"

# Fixing #CanProd2Dev4debug
# #CanProd2Dev4debug
bin/kubectl-dev auth can-i '*' '*' --all-namespaces | grep yes
bin/kubectl-canary auth can-i '*' '*' --all-namespaces | grep yes
bin/kubectl-prod   auth can-i '*' '*' --all-namespaces | grep yes

##################################################
## dmarzi003 enable multi-cluster services
##################################################
gcloud container fleet multi-cluster-services enable

##################################################
## dmarzi003.5 from https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services
##################################################
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
     --member "serviceAccount:$PROJECT_ID.svc.id.goog[gke-mcs/gke-mcs-importer]" \
     --role "roles/compute.networkViewer" \
     --project=$PROJECT_ID

# Makling sure its active: https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services
gcloud container fleet multi-cluster-services describe | grep "state: ACTIVE"


##################################################
## dmarzi004 enable gateway apis (in prod)
##################################################
##CanProd2Dev4debug
bin/kubectl-dev  apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.4.3"
bin/kubectl-staging  apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.4.3"
# I should see FOUR not TWO: #CanProd2Dev4debug
bin/kubectl-dev get gatewayclass
bin/kubectl-staging get gatewayclass

##################################################
## dmarzi005 enable GKE gateway controller just in GKE01.
##################################################
# UNLESS `gcloud container fleet ingress describe | ... greps both canary and prod`
gcloud container fleet ingress enable \
    --config-membership=/projects/$PROJECT_ID/locations/global/memberships/cicd-dev \
    --project=$PROJECT_ID # ||        echo OK if this gives error
# gcloud container fleet ingress enable \
#     --config-membership=/projects/$PROJECT_ID/locations/global/memberships/cicd-prod \
#     --project=$PROJECT_ID


################################################################################
# Now we do our k8s manifests. Since we're multi-app we need to do some manual plumbing on the manifests
# I'll use sed, but hopefully I'll kustomize it later.
################################################################################

# ensure out dir exists..
mkdir -p "$GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR/out/"
white This grep output should be null:
egrep "store|v2" $GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR/templates/[a-z]*yaml | egrep -v '^#'

###############################################
# set up additional variables for the for cycle
REGION="${GCLOUD_REGION}"
#SHORT_REGION="$(_shorten_region "$REGION")"
PREFIX="${APP_NAME}-${DEFAULT_SHORT_REGION}" # maybe in the future PREFIX = APP-REGION
export IMAGE_NAME="${K8S_APP_IMAGE}"
###############################################

SOLUTION1_TEMPLATING_VER="1.1"
###############################################
# 1.1 14jul22 Added support for short regions which def acto changed the naming convention!
# 1.0 13jul22 Initial stesure.
###############################################

# MultiAppK8sRefactoring: first script (just ported to obsolete script 2)
make clean
# huge "kubectl apply":
smart_apply_k8s_templates "$GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR"

#yellow Now we can issue a kubectl on the out dir..
#echo "TODO:  kubectl apply -f $GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR/out/"

# #CanProd2Dev4debug
bin/kubectl-dev     apply -f "$GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR/out/"
bin/kubectl-staging apply -f "$GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR/out/"
#bin/kubectl-canary apply -f "$GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR/out/"
#bin/kubectl-prod   apply -f "$GKE_SOLUTION1_XLB_PODSCALING_SETUP_DIR/out/"

# Check everything ok:
bin/kubectl-triune get all | grep "sol1sc"

#######################
# End of your code here
#######################
_allgood_post_script
echo Everything is ok.
