#!/bin/bash

set -e

cd `dirname $0`
cd ..

go build -o "$HOME/efsdriver" "src/code.cloudfoundry.org/efsdriver/cmd/efsdriver/main.go"

go get -t code.cloudfoundry.org/volume_driver_cert

# UNIX SOCKET TESTS
export FIXTURE_FILENAME=$PWD/scripts/fixtures/certification_unix.json
/bin/bash scripts/startdriver_unix.sh
pushd src/code.cloudfoundry.org/volume_driver_cert
    ginkgo
popd
/bin/bash scripts/stopdriver.sh


rm -rf $HOME/certs
rm $HOME/efsdriver
