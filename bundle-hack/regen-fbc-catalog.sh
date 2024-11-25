#!/bin/bash
set -eo pipefail
# TODO(jkyros): I used a template to generate the actual catalog, this script needs to be better/different but
# opm interrogates all the bundles in the template, snarfs out their details, and then renders a final catalog based on
# those details, so we can't do the catalog generation itself as part of a hermetic build (it uses the network to look up the images)
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
    # TODO(jkyros): originally I was referencing these straight out of stage, but the "proper" way now is to
    # is an ICSP to redirect to stage rather than reference stage directly
    #STAGE_PREFIX="registry.stage.redhat.io/custom-metrics-autoscaler"
    STAGE_PREFIX=$PROD_PREFIX

    if [ "$CATALOG_VERSION" == "catalogs/fbc" ]; then
        echo "rewriting prod images for $CATALOG_VERSION"
        sed -i "s|$APP_PREFIX/keda-adapter|$PROD_PREFIX/keda-adapter-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-operator|$PROD_PREFIX/keda-operator-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-webhooks|$PROD_PREFIX/keda-webhooks-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator-bundle|$PROD_PREFIX/custom-metrics-autoscaler-operator-bundle|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator|$PROD_PREFIX/custom-metrics-autoscaler-operator-$OSVER|g" $CATALOG_OUTPUT
    elif [ "$CATALOG_VERSION" == "catalogs/fbc-stage" ]; then
        echo "rewriting stage images for $CATALOG_VERSION"
        sed -i "s|$APP_PREFIX/keda-adapter|$STAGE_PREFIX/keda-adapter-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-operator|$STAGE_PREFIX/keda-operator-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-webhooks|$STAGE_PREFIX/keda-webhooks-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator-bundle|$STAGE_PREFIX/custom-metrics-autoscaler-operator-bundle|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator|$STAGE_PREFIX/custom-metrics-autoscaler-operator-$OSVER|g" $CATALOG_OUTPUT
    # TODO(jkyros): I cut a special release for a customer by pushing the pipeline to my personal quay. I really don't like these copy-paste blocks
    # but I don't have time right now to cook something good, and this is at least very straightforward, so this is what we get :)
    elif [ "$CATALOG_VERSION" == "catalogs/fbc-jkyros-quay" ]; then
      JKYROS_PREFIX="quay.io/jkyros"
      echo "rewriting quay images for $CATALOG_VERSION"
        sed -i "s|$APP_PREFIX/keda-adapter|$JKYROS_PREFIX/keda-adapter-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-operator|$JKYROS_PREFIX/keda-operator-$OSVER|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/keda-webhooks|$JKYROS_PREFIX/keda-webhooks-$OSVER|g" $CATALOG_OUTPUT
        # TODO(jkyros): This one is different because we need to build a different bundle image for a different target, and apparently the new
        # imagerepositories created with new components aren't nested under the application name anymore, so the path for this new bundle is different
        sed -i "s|quay.io/redhat-user-workloads/cma-podauto-tenant/custom-metrics-autoscaler-operator-bundle-jkyros-quay|$JKYROS_PREFIX/custom-metrics-autoscaler-konflux-operator-bundle|g" $CATALOG_OUTPUT
        sed -i "s|$APP_PREFIX/custom-metrics-autoscaler-operator|$JKYROS_PREFIX/custom-metrics-autoscaler-operator-$OSVER|g" $CATALOG_OUTPUT
    fi


    # This is for all the old brew builds if we keep them in our catalog:
    sed -i 's|brew.registry.redhat.io/custom-metrics-autoscaler/custom-metrics-autoscaler|registry.redhat.io/custom-metrics-autoscaler/custom-metrics-autoscaler|g' $CATALOG_OUTPUT
done
