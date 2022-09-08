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

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

################################################################################################################
# This script sets the foundations for Solution 0/3 (Internal Load Balancer with Traffic Splitting)
#
# Daniel says: WORKS ONLY WITH MULTIPLE CLUSTERS IN THE SAME REGION
# Enable (multi-cluster Gateways)[https://cloud.google.com/kubernetes-engine/docs/how-to/enabling-multi-cluster-gateways]
# Blue-Green https://cloud.google.com/kubernetes-engine/docs/how-to/deploying-multi-cluster-gateways#blue-green
################################################################################################################


# CREATING IN region XXX
# NOTE: Even though this is regional, you can have only one of this in a reg
# Changed dmarzi_proxy to "platinum-proxy-$GCLOUD_REGION" in case you want to change region after starting this :)
proceed_if_error_matches "already exists" \
     gcloud compute networks subnets create "platinum-proxy" \
     --purpose=REGIONAL_MANAGED_PROXY \
     --role=ACTIVE \
     --region="$GCLOUD_REGION" \
     --network='default' \
     --enable-private-ip-google-access \
     --range='192.168.1.0/24' # changed after dmarzi_-_proxy (192.168.0.0/24) rename..

# wont work with enable Pvt IP from above :/ but it DOES work
#gcloud compute networks subnets update platinum-proxy --enable-private-ip-google-access
# bingo! https://screenshot.googleplex.com/h5ZXAUgy5wWrvqh
# but useless: I cant create anything inside it. It's just a private space for Envoy-based GFEs

# 1. # enable required APIs (project level) => refactored into 00

#1.5 Enable Workload Identity [missing from marzini]
# TODO(ricc): remove me once testing the creation of GKE clusters with WrklId.
# Note that in AutoPilot this is not needed.
gcloud container clusters update "$CLUSTER_1" \
    --region="$GCLOUD_REGION" \
    --workload-pool="$PROJECT_ID.svc.id.goog"
gcloud container clusters update "$CLUSTER_2" \
    --region="$GCLOUD_REGION" \
    --workload-pool="$PROJECT_ID.svc.id.goog"

#2. register clusters to the fleet (cluster level)
# gcloud container fleet memberships register "$CLUSTER_1" \
#      --gke-cluster "$GCLOUD_REGION/$CLUSTER_1" \
#      --enable-workload-identity \
#      --project="$PROJECT_ID" --quiet

# gcloud container fleet memberships register "$CLUSTER_2" \
#      --gke-cluster "$GCLOUD_REGION/$CLUSTER_2" \
#      --enable-workload-identity \
#      --project="$PROJECT_ID" --quiet
_gcloud_container_fleet_memberships_register_if_needed "$CLUSTER_1"
_gcloud_container_fleet_memberships_register_if_needed "$CLUSTER_2"
# Cluster 1
_deb "Cluster mapping: CANARY CLUSTER_1=$CLUSTER_1"
_deb "Cluster mapping: PROD   CLUSTER_2=$CLUSTER_2"

#yellow "Try now for cluster1=$CLUSTER_1 kubectl apply -f  $GKE_SOLUTION0_ILB_SETUP_DIR/cluster1/"

#3. enable multi-cluster services
gcloud container fleet multi-cluster-services enable \
    --project $PROJECT_ID

#3.5 from https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-services
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
     --member "serviceAccount:$PROJECT_ID.svc.id.goog[gke-mcs/gke-mcs-importer]" \
     --role "roles/compute.networkViewer" \
     --project="$PROJECT_ID"

#4.  enable gateway apis
kubectl --context="$GKE_CANARY_CLUSTER_CONTEXT" apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.4.3"
kubectl --context="$GKE_PROD_CLUSTER_CONTEXT"   apply -k "github.com/kubernetes-sigs/gateway-api/config/crd?ref=v0.4.3"

#4a. TEST. I should see FOUR not TWO:
_deb "TEST: This command should show you TWO entries for TWO clusters: total 4 lines."
_kubectl_on_both_canary_and_prod get gatewayclass
# TODO assert(wc -l == 4)


#5. enable GKE gateway controller just in GKE01.
gcloud container fleet ingress enable \
    --config-membership="/projects/$PROJECT_ID/locations/global/memberships/$CLUSTER_1" \
     --project="$PROJECT_ID"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
     --member "serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-multiclusteringress.iam.gserviceaccount.com" \
     --role "roles/container.admin" \
     --project="$PROJECT_ID"

green "one-off Configuration is Done. Now proceed to 11b to execute upon kubectl on two clusters: ./11b-kubectl-apply-stuff.sh"

# End of your code here
_allgood_post_script
echo Everything is ok.
