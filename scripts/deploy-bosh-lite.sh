#!/bin/bash

set -e -x

pushd ~/workspace/cf-release
    ./scripts/generate-bosh-lite-dev-manifest
    sed -i -e 's/default_to_diego_backend: false/default_to_diego_backend: true/g' bosh-lite/deployments/cf.yml
popd

pushd ~/workspace/diego-release
#    USE_VOLDRIVER=true ./scripts/generate-bosh-lite-manifests
    ./scripts/generate-bosh-lite-manifests
popd

bosh -n -d ~/workspace/cf-release/bosh-lite/deployments/cf.yml deploy

bosh -n -d ~/workspace/diego-release/bosh-lite/deployments/diego.yml deploy

pushd ~/workspace/efs-volume-release
    ./scripts/generate-bosh-lite-manifest.sh $(bosh status --uuid) https://192.168.50.4:25555 admin admin admin admin
    bosh create release --force && bosh upload release
popd

bosh -n -d ~/workspace/efs-volume-release/efs-boshlite-manifest.yml deploy
