#!/bin/bash
#generate_manifest.sh

set -e -x

usage () {
    echo "Usage: generate_manifest.sh cf-manifest director-stub iaas-stub efs-props-stub"
    echo " * default"
    exit 1
}

home="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
templates=${home}/templates

if [[  "$1" == "bosh-lite" || "$1" == "aws" || -z $1 ]]
  then
    usage
fi

MANIFEST_NAME=efsvolume-aws-manifest

spiff merge ${templates}/efsvolume-manifest-aws.yml \
$1 \
$2 \
$3 \
$4 \
${templates}/toplevel-manifest-overrides.yml \
> $PWD/$MANIFEST_NAME.yml

echo manifest written to $PWD/$MANIFEST_NAME.yml
