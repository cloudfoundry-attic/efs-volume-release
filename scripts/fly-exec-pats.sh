#!/usr/bin/env bash
set -e

scripts_path=./$(dirname $0)

fly -t persi execute -c $scripts_path/ci/run_pats_efsvolume.build.yml -i efs-volume-release=/Users/pivotal/workspace/efs-volume-release --privileged
