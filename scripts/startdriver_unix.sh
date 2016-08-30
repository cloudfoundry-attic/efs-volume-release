#!/bin/bash

set -x

cd `dirname $0`

pkill -f efsdriver

mkdir -p ~/voldriver_plugins
rm ~/voldriver_plugins/efsdriver.*

mkdir -p ../mountdir

# temporarily create a sock file in order to find an absolute path for it
touch ~/voldriver_plugins/efsdriver.sock
listenAddr=$HOME/voldriver_plugins/efsdriver.sock
rm ~/voldriver_plugins/efsdriver.sock

~/efsdriver -listenAddr="${listenAddr}" -transport="unix" -mountDir="../mountdir" &
