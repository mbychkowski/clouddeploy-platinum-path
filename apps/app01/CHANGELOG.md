* 2022-10-03 v2.26 [DEV] Someone forgot to update this from 22 to 25Croatia. Well time for a cleanup :)
* 2022-07-19 v2.22 [DEV] Statusz with trailing \n and link from home to statusz.
* 2022-07-19 v2.21 [DEV] Cleaned up CTarget and made it smaller in kustomize and header and /statusz
* 2022-07-19 ....  [OPS] Somewhere in between Alex fixed skaffold and now it builds it correctly. Back to business.
* 2022-07-19 v2.20 [DEV] Added statusz
* 2022-07-18 v2.19 [DEV] also FAV_COLOR _COMMON in UI.
* 2022-07-18 v2.18 [OPS] surfacing from common component CLOUD_DEPLOY_TARGET_COMMON in UI.
* 2022-07-18 v2.17 [OPS] simple ver bump to inherit new COMMON components.
* 2022-07-18 v2.16 [OPS] Making skaffold laxxer waiting 5min for deployment to stabilize. See b/239385876
* 2022-07-18 v2.14 [DEV] rstrip for version - usefuil in the curler on script 16 :) Also for [OPS]
* 2022-07-16 v2.10 [DEV] fixed a bug Ive introduced yesterday dammit. Now it back to compile. Also introduced a simple
                         ` make flask-run-on-my-mac` which works at home
* 2022-07-15 v2.5 [OPS] moved prod -> production in skaffold stage to match CloudDeploy.yaml
* 2022-07-14 v2.4 [OPS] removed namespaces from all targets (just DEV)!
