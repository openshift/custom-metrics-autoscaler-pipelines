#!/usr/bin/env bash

# TODO(jkyros): Fish this out of the operator repo, maybe "most recent manifest version in keda/ or something" 
# TODO(jkyros): Somehow we need to add that to the FBC also and populate our CI_SPEC_RELEASE
export VERSION=$(ls custom-metrics-autoscaler-operator/keda/ | sort -rV | head -n1)
mv /custom-metrics-autoscaler-operator/keda/${VERSION}/manifests/ /manifests/
mv /custom-metrics-autoscaler-operator/keda/${VERSION}/metadata/ /metadata/

# TODO(jkyros): I really want to find a way to increment this automatically
export CI_SPEC_RELEASE=$(cat /releaseNum)
echo "CI SPEC RELEASE IS $CI_SPEC_RELEASE"

# We used to keep these variables in the script itself, but that caused some weird conflict issues when
# konflux PRs stacked up, so now we put them each in their own file so they're safe to bump asynchronusly
export CMA_OPERATOR_PULLSPEC=$(<"imagerefs/custom-metrics-autoscaler-operator.pullspec")
export KEDA_OPERATOR_PULLSPEC=$(<"imagerefs/keda-operator.pullspec")
export KEDA_WEBHOOK_PULLSPEC=$(<"imagerefs/keda-webhooks.pullspec")
export KEDA_ADAPTER_PULLSPEC=$(<"imagerefs/keda-adapter.pullspec")

# This is just so we don't build a bogus bundle with an empty image and then only figure it out when we deploy it :)
[[ -z "$CMA_OPERATOR_PULLSPEC" ]] && { echo "CMA operator pullspec is empty"; exit 1;}
[[ -z "$KEDA_OPERATOR_PULLSPEC" ]] && { echo "keda operator pullspec is empty"; exit 1;}
[[ -z "$KEDA_WEBHOOK_PULLSPEC" ]] && { echo "keda webhook pullspec is empty"; exit 1;}
[[ -z "$KEDA_ADAPTER_PULLSPEC" ]] && { echo "keda adapter pullspec is empty"; exit 1;}


# TODO(jkyros): we probably need multiple dockerfiles with different targets that feed an arg into this script, e.g. "push to stage", "push to prod", "push to quay"
# TODO(jkyros): oh, also, for fun, apparently the stage policy wants you to use registry.redhat.io also, and the intent is that you use like an ICSP to
# re-map the images, and NOTHING TELLS YOU THAT ANYWHERE.
echo "REWRITE REPOS IS $REWRITE_REPOS"
APP_PREFIX="quay.io/redhat-user-workloads/cma-podauto-tenant/custom-metrics-autoscaler-operator"
PROD_PREFIX="registry.redhat.io/custom-metrics-autoscaler"
STAGE_PREFIX="registry.stage.redhat.io/custom-metrics-autoscaler"
REWRITE_PREFIX=$PROD_PREFIX
OSVER="rhel9"

if [ -n "$REWRITE_REPOS" ]; then
   CMA_OPERATOR_PULLSPEC=$( echo $CMA_OPERATOR_PULLSPEC | sed -e "s#quay.io/redhat-user-workloads/cma-podauto-tenant/#$REWRITE_REPOS/#" )
   KEDA_OPERATOR_PULLSPEC=$( echo $KEDA_OPERATOR_PULLSPEC | sed -e "s#quay.io/redhat-user-workloads/cma-podauto-tenant/#$REWRITE_REPOS/#" )
   KEDA_WEBHOOK_PULLSPEC=$( echo $KEDA_WEBHOOK_PULLSPEC | sed -e "s#quay.io/redhat-user-workloads/cma-podauto-tenant/#$REWRITE_REPOS/#" )
   KEDA_ADAPTER_PULLSPEC=$( echo $KEDA_ADAPTER_PULLSPEC | sed -e "s#quay.io/redhat-user-workloads/cma-podauto-tenant/#$REWRITE_REPOS/#" )
else
   CMA_OPERATOR_PULLSPEC=$( echo $CMA_OPERATOR_PULLSPEC | sed -e "s#$APP_PREFIX/custom-metrics-autoscaler-operator#$REWRITE_PREFIX/custom-metrics-autoscaler-$OSVER-operator#" )
   KEDA_OPERATOR_PULLSPEC=$( echo $KEDA_OPERATOR_PULLSPEC | sed -e "s#$APP_PREFIX/keda-operator#$REWRITE_PREFIX/custom-metrics-autoscaler-$OSVER#" )
   KEDA_WEBHOOK_PULLSPEC=$( echo $KEDA_WEBHOOK_PULLSPEC | sed -e "s#$APP_PREFIX/keda-webhooks#$REWRITE_PREFIX/custom-metrics-autoscaler-admission-webhooks-$OSVER#" )
   KEDA_ADAPTER_PULLSPEC=$( echo $KEDA_ADAPTER_PULLSPEC | sed -e "s#$APP_PREFIX/keda-adapter#$REWRITE_PREFIX/custom-metrics-autoscaler-adapter-$OSVER#" )
fi

# Since we moved the versioned manifest to /manifests, we can just use it from there
export CSV_FILE=/manifests/cma.v${VERSION}.clusterserviceversion.yaml


# CPaaS used to do this for us, but now we have to do it ourselves
cat << EOF >> ${CSV_FILE}
  relatedImages:
    - name: keda-operator
      image: ${KEDA_OPERATOR_PULLSPEC}
    - name: keda-adapter
      image: ${KEDA_ADAPTER_PULLSPEC}
    - name: keda-webhooks
      image: ${KEDA_WEBHOOK_PULLSPEC}
    - name: cma-operator
      image: ${CMA_OPERATOR_PULLSPEC}
EOF

# Update image references to use brew-built images
# Put the allowed repositories: OSBS proxy and registry.redhat.io.
# The pinning to SHA1 will happen after thanks to the config in container.yaml.
# TODO(jkyros): I think the FBC will take care of the replaces, etc based on the catalog so we don't have to do it
sed -i -e "s#ghcr.io/kedacore/keda-olm-operator:\(main\|[0-9.]*\)#${CMA_OPERATOR_PULLSPEC}#g" \
       -e "s#CMA_OPERAND_PLACEHOLDER_1\$#${KEDA_OPERATOR_PULLSPEC}#g" \
       -e "s#CMA_OPERAND_PLACEHOLDER_2\$#${KEDA_ADAPTER_PULLSPEC}#g" \
       -e "s#CMA_OPERAND_PLACEHOLDER_3\$#${KEDA_WEBHOOK_PULLSPEC}#g" \
       -e "s/^\(  *\)olm.skipRange: '>=2.7.1 <[0-9.-]*'/\1olm.skipRange: '>=2.7.1 <${VERSION}-${CI_SPEC_RELEASE}'/" \
       -e '/^metadata:$/,/^spec:$/ s/^\(  name: custom-metrics-autoscaler\.v\)[0-9.]*$/\1'"${VERSION}-${CI_SPEC_RELEASE}"'/' \
       -e '/^spec:$/,$ s/^\(  version: \)[0-9.]*$/\1'"${VERSION}-${CI_SPEC_RELEASE}"'/' \
       "${CSV_FILE}"
cat "${CSV_FILE}"


# TODO(jkyros): check all the images probably so we don't have an odd one out that's missing on a platform, e.g. CMA
# built for arm, but the webhook only built for x86_64, etc.
export AMD64_BUILT=$(skopeo inspect --raw docker://${CMA_OPERATOR_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="amd64")')
export ARM64_BUILT=$(skopeo inspect --raw docker://${CMA_OPERATOR_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="arm64")')
export PPC64LE_BUILT=$(skopeo inspect --raw docker://${CMA_OPERATOR_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="ppc64le")')
export S390X_BUILT=$(skopeo inspect --raw docker://${CMA_OPERATOR_PULLSPEC} | jq -e '.manifests[] | select(.platform.architecture=="s390x")')

export EPOC_TIMESTAMP=$(date +%s)
# time for some direct modifications to the csv
python3 - << CSV_UPDATE
import os
from collections import OrderedDict
from sys import exit as sys_exit
from datetime import datetime
from ruamel.yaml import YAML
yaml = YAML()
def load_manifest(pathn):
   if not pathn.endswith(".yaml"):
      return None
   try:
      with open(pathn, "r") as f:
         return yaml.load(f)
   except FileNotFoundError:
      print("File can not found")
      exit(2)

def dump_manifest(pathn, manifest):
   with open(pathn, "w") as f:
      yaml.dump(manifest, f)
   return
timestamp = int(os.getenv('EPOC_TIMESTAMP'))
datetime_time = datetime.fromtimestamp(timestamp)
gatekeeper_csv = load_manifest(os.getenv('CSV_FILE'))
# Add arch support labels
gatekeeper_csv['metadata']['labels'] = gatekeeper_csv['metadata'].get('labels', {})
if os.getenv('AMD64_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.amd64'] = 'supported'
if os.getenv('ARM64_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.arm64'] = 'supported'
if os.getenv('PPC64LE_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.ppc64le'] = 'supported'
if os.getenv('S390X_BUILT'):
	gatekeeper_csv['metadata']['labels']['operatorframework.io/arch.s390x'] = 'supported'
gatekeeper_csv['metadata']['labels']['operatorframework.io/os.linux'] = 'supported'
gatekeeper_csv['metadata']['annotations']['createdAt'] = datetime_time.strftime('%d %b %Y, %H:%M')
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/disconnected'] = 'true'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/fips-compliant'] = 'true'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/proxy-aware'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/tls-profiles'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-aws'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-azure'] = 'false'
gatekeeper_csv['metadata']['annotations']['features.operators.openshift.io/token-auth-gcp'] = 'false'
gatekeeper_csv['metadata']['annotations']['repository'] = 'https://github.com/openshift/custom-metrics-autoscaler-operator'
gatekeeper_csv['metadata']['annotations']['containerImage'] = os.getenv('CMA_OPERATOR_PULLSPEC', '')

dump_manifest(os.getenv('CSV_FILE'), gatekeeper_csv)
CSV_UPDATE

cat $CSV_FILE

