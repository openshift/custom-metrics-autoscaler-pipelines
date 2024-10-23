#!/bin/bash
# TODO(jkyros): I used a template to generate the actual catalog, this script needs to be better/different but
# opm interrogates all the bundles in the template, snarfs out their details, and then renders a final catalog based on
# those details
# TODO(jkyros): What is the downside if I do this generation inside the catalog dockerfile and never commit it back?  It would save a manual step. i'd
# really like to be able to just have something automatically regen the catalog.yaml and PR it back with renovate or something
for CATALOG_VERSION in catalogs/*; do
    echo "found catalog $CATALOG_VERSION"
    CATALOG_OUTPUT=${CATALOG_VERSION}/catalog/custom-metrics-autoscaler-operator/catalog.yaml
    # This is basically "generate the catalog, and then rewrite the pullspecs to match their final resting place". You can't do it beforehand in the
    # template because render-template pulls all those images to check them to include them in the catalog (and the new ones won't be there yet because they
    # haven't shipped)
    opm alpha render-template basic ${CATALOG_VERSION}/catalog-template.yaml -o yaml > $CATALOG_OUTPUT
    #  --- Comet Mangling ---
    # Version of RHEL we ship on top of, corresponds to comet repository names which have os version suffixes.
    # We have to do this here because the pipeline is signed and sealed, so we can't change anything after it's built.
    OSVER="rhel9"
    APP_PREFIX="quay.io/redhat-user-workloads/cma-podauto-tenant/custom-metrics-autoscaler-operator"
    PROD_PREFIX="registry.redhat.io/custom-metrics-autoscaler"
    STAGE_PREFIX="registry.stage.redhat.io/custom-metrics-autoscaler"
    if [ "$CATALOG_VERSION" == "catalogs/fbc" ]; then
        echo "rewriting prod images for $CATALOG_VERSION"
        sed -i "s|$APP_PREFIX/keda-adapter|$PROD_PREFIX/keda-adapter-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-operator|$PROD_PREFIX/keda-operator-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-webhooks|$PROD_PREFIX/keda-webhook-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator-bundle|$PROD_PREFIX/custom-metrics-autoscaler-konflux-operator-bundle|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator|$PROD_PREFIX/custom-metrics-autoscaler-operator-$OSVER|g" $CATALOG_OUTPUT
    elif [ "$CATALOG_VERSION" == "catalogs/fbc-stage" ]; then
        echo "rewriting stage images for $CATALOG_VERSION"
        sed -i "s|$APP_PREFIX/keda-adapter|$STAGE_PREFIX/keda-adapter-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-operator|$STAGE_PREFIX/keda-operator-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-webhooks|$STAGE_PREFIX/keda-webhook-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator-bundle|$STAGE_PREFIX/custom-metrics-autoscaler-konflux-operator-bundle|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator|$STAGE_PREFIX/custom-metrics-autoscaler-operator-$OSVER|g" $CATALOG_OUTPUT
    fi

    # This is for all the old brew builds if we keep them in our catalog:
    sed -i 's|brew.registry.redhat.io/custom-metrics-autoscaler/custom-metrics-autoscaler|registry.redhat.io/custom-metrics-autoscaler/custom-metrics-autoscaler|g' $CATALOG_OUTPUT
done
