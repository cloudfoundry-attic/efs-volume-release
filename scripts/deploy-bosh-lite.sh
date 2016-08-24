#!/bin/bash

set -e -x

pushd ~/workspace/cf-release
    ./scripts/generate-bosh-lite-dev-manifest
    sed -i -e 's/default_to_diego_backend: false/default_to_diego_backend: true/g' bosh-lite/deployments/cf.yml
popd

pushd ~/workspace/diego-release
    #modify the default drivers.yml stub for diego so that it picks up our driver instead of localdriver
    cp -f manifest-generation/bosh-lite-stubs/experimental/voldriver/drivers.yml ./drivers.yml.backup
    sed -i -e 's/local/efs/g' manifest-generation/bosh-lite-stubs/experimental/voldriver/drivers.yml

    USE_VOLDRIVER=true ./scripts/generate-bosh-lite-manifests

    cp -f ./drivers.yml.backup manifest-generation/bosh-lite-stubs/experimental/voldriver/drivers.yml
    rm -f ./drivers.yml.backup
popd

bosh -n -d ~/workspace/cf-release/bosh-lite/deployments/cf.yml deploy

bosh -n -d ~/workspace/diego-release/bosh-lite/deployments/diego.yml deploy

pushd ~/workspace/efs-volume-release
    ./scripts/generate-bosh-lite-manifest.sh
    bosh create release --force && bosh upload release
popd

bosh -n -d ~/workspace/efs-volume-release/efs-boshlite-manifest.yml deploy
