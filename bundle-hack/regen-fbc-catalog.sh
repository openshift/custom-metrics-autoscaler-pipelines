#!/bin/bash
# TODO(jkyros): I used a template to generate the actual catalog, this script needs to be better/different but 
# opm interrogates all the bundles in the template, snarfs out their details, and then renders a final catalog based on 
# those details  
# TODO(jkyros): What is the downside if I do this generation inside the catalog dockerfile and never commit it back?  It would save a manual step. i'd
# really like to be able to just have something automatically regen the catalog.yaml and PR it back with renovate or something
for CATALOG_VERSION in catalogs/*; do
opm alpha render-template basic ${CATALOG_VERSION}/catalog-template.yaml -o yaml > ${CATALOG_VERSION}/catalog/custom-metrics-autoscaler-operator/catalog.yaml
done
