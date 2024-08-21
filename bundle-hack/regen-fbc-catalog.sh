#!/bin/bash
# TODO(jkyros): I used a template to generate the actual catalog, this script needs to be better/different but 
# opm interrogates all the bundles in the template, snarfs out their details, and then renders a final catalog based on 
# those details  
opm alpha render-template basic fbc-template/catalog-template.yaml -o yaml > fbc/catalog.yaml 
