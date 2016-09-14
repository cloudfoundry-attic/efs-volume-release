#!/bin/bash
#generate_manifest.sh

set -e -x

usage () {
    echo "Usage: generate_manifest.sh cf-manifest director-stub bosh-target bosh-username bosh-password efs-props-stub"
    echo " * default"
    exit 1
}

templates=$(dirname $0)

if [[  "$1" == "bosh-lite" || "$1" == "aws" || -z $1 ]]
  then
    usage
fi

MANIFEST_NAME=efsvolume-aws-manifest

spiff merge ${templates}/efsvolume-manifest-aws.yml \
$1 \
$2 \
$6 \
${templates}/toplevel-manifest-overrides.yml \
> $PWD/$MANIFEST_NAME.yml

echo manifest written to $PWD/$MANIFEST_NAME.yml
