#!/bin/bash

# 1. Go through the list of all the releases in the CMA 
# 2. Find the most recent one (or take one from the CLI if we're doing a point release) 
# 3. Add an entry in the release template for it (maybe increment by 1 if we're actually releasing it)  
# 4. generate the fbc catalog from it
# 5. The build will handle the rest of it 
#     -- we might be able to do 3/4 in the build itself but I'm worried about the pull secret because it needs to retireve stuff  
NEWVERSION=2.15.1
NEW_BUNDLE_IMAGE=quay.io/stuff
# Get the last version we released 
FIRSTVERSION=2.7.1
PREVIOUSVERSION=$(yq eval '.entries[1].entries[-1].name' ./catalog-template.yaml)

yq eval ".entries[1].entries += [{\"name\":\"custom-metrics-autoscaler-v$NEWVERSION\",\"replaces\":\"custom-metrics-autoscaler.v$PREVIOSUVERSION\",\"skipRange\":\">=$FIRSTVERSION <$NEWVERSION\"}]" ./catalog-template.yaml
yq eval ".entries += [{\"image\":\"$NEW_BUNDLE_IMAGE\",\"schema\":\"olm.bundle\"}]" ./catalog-template.yaml
