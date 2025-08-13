#!/bin/bash
set -eo pipefail
# TODO(jkyros): I used a template to generate the actual catalog, this script needs to be better/different but
# opm interrogates all the bundles in the template, snarfs out their details, and then renders a final catalog based on
# those details, so we can't do the catalog generation itself as part of a hermetic build (it uses the network to look up the images)
for CATALOG_VERSION in catalogs/*; do
    echo "found catalog $CATALOG_VERSION"
    # For OpenShift <= 4.16 we need the olm.bundle object catalog, which we'll output as json, and for 4.17+ we need the csv format, which we'll output as yaml
    CATALOG_OUTPUT=${CATALOG_VERSION}/catalog/openshift-custom-metrics-autoscaler-operator/catalog.yaml

    # TODO(jkyros): right now I just have a dummy pullspec in the template that I swap with the real one, but this should probably be better. Konflux
    # could be told to rewrite this as part of a nudge but there will come a point where we want to "archive" a pullspec and keep it in the bundle and we
    # won't want it to touch it after that, so until we figure out how we want to do that, this is what we get
    CURRENT_BUNDLE=$(cat bundle-hack/imagerefs/custom-metrics-autoscaler-operator-bundle.pullspec)
    sed -i "s|quay.io/redhat-user-workloads/cma-podauto-tenant/custom-metrics-autoscaler-operator/custom-metrics-autoscaler-operator-bundle@sha256.*|$CURRENT_BUNDLE|g" ${CATALOG_VERSION}/catalog-template.yaml
    # This is basically "generate the catalog, and then rewrite the pullspecs to match their final resting place". You can't do it beforehand in the
    # template because render-template pulls all those images to check them to include them in the catalog (and the new ones won't be there yet because they
    # haven't shipped)
    opm alpha render-template basic --migrate-level bundle-object-to-csv-metadata ${CATALOG_VERSION}/catalog-template.yaml -o yaml > $CATALOG_OUTPUT
    opm alpha render-template basic --migrate-level none ${CATALOG_VERSION}/catalog-template.yaml -o json > ${CATALOG_OUTPUT%.yaml}.json
    #  --- Comet Mangling ---
    # Version of RHEL we ship on top of, corresponds to comet repository names which have os version suffixes.
    # We have to do this here because the pipeline is signed and sealed, so we can't change anything after it's built.
    OSVER="rhel9"
    APP_PREFIX="quay.io/redhat-user-workloads/cma-podauto-tenant"
    PROD_PREFIX="registry.redhat.io/custom-metrics-autoscaler"
    # TODO(jkyros): originally I was referencing these straight out of stage, but the "proper" way now is to
    # is an ICSP to redirect to stage rather than reference stage directly
    #STAGE_PREFIX="registry.stage.redhat.io/custom-metrics-autoscaler"
    STAGE_PREFIX=$PROD_PREFIX

    if [ "$CATALOG_VERSION" == "catalogs/fbc" ]; then
        echo "rewriting prod images for $CATALOG_VERSION"
        # TODO(jkyros): The names for imagerepos now don't include the app, so if you regenerate a component, you won't have 
        # the app name in the path, so this will try to match both/either
        sed -Ei "s|$APP_PREFIX/(custom-metrics-autoscaler-operator/)?custom-metrics-autoscaler-operator-bundle|$PROD_PREFIX/custom-metrics-autoscaler-operator-bundle|g" ${CATALOG_OUTPUT%.yaml}.*
    elif [ "$CATALOG_VERSION" == "catalogs/fbc-stage" ]; then
        echo "rewriting stage images for $CATALOG_VERSION"
        sed -Ei "s|$APP_PREFIX/(custom-metrics-autoscaler-operator/)?custom-metrics-autoscaler-operator-bundle|$STAGE_PREFIX/custom-metrics-autoscaler-operator-bundle|g" ${CATALOG_OUTPUT%.yaml}.*
    # TODO(jkyros): I cut a special release for a customer by pushing the pipeline to my personal quay, we should think about how we want to do pre-release
    # stuff for the future
    elif [ "$CATALOG_VERSION" == "catalogs/fbc-jkyros-quay" ]; then
      JKYROS_PREFIX="quay.io/jkyros"
      echo "rewriting quay images for $CATALOG_VERSION"
        # TODO(jkyros): This one is different because we need to build a different bundle image for a different target, and apparently the new
        # imagerepositories created with new components aren't nested under the application name anymore, so the path for this new bundle is different
        sed -i "s|quay.io/redhat-user-workloads/cma-podauto-tenant/custom-metrics-autoscaler-operator-bundle-jkyros-quay|$JKYROS_PREFIX/custom-metrics-autoscaler-konflux-operator-bundle|g" ${CATALOG_OUTPUT%.yaml}.*
    fi
    # This is for all the old brew builds if we keep them in our catalog:
    sed -i 's|brew.registry.redhat.io/custom-metrics-autoscaler/custom-metrics-autoscaler|registry.redhat.io/custom-metrics-autoscaler/custom-metrics-autoscaler|g' ${CATALOG_OUTPUT%.yaml}.*
done
