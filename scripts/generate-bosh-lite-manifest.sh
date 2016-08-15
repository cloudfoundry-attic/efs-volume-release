#!/bin/bash
set -e

usage () {
    echo "Usage: generate-bosh-lite-manifest.sh"
    echo " * default"
    exit 1
}

if [ -z $AWS_ACCESS_KEY_ID ]; then
  echo "FAILED: your AWS_ACCESS_KEY_ID is unset"
  exit 1
fi

if [ -z $AWS_SECRET_ACCESS_KEY ]; then
  echo "FAILED: your AWS_SECRET_ACCESS_KEY is unset"
  exit 1
fi

templates=$(dirname $0)/../templates

cat > ${PWD}/director-uuid.yml << EOF
---
director_uuid: $(bosh -t "https://192.168.50.4:25555" status --uuid)
EOF


cat > ${PWD}/efsbroker-creds.yml << EOF
---
properties:
  efsbroker:
    username: admin
    password: admin
    aws-access-key-id: $AWS_ACCESS_KEY_ID
    aws-secret-access-key: $AWS_SECRET_ACCESS_KEY
EOF


$templates/generate_manifest.sh bosh-lite \
    /dev/null \
    ${PWD}/director-uuid.yml \
    "https://192.168.50.4:25555" \
    admin \
    admin \
    ${PWD}/efsbroker-creds.yml

rm ${PWD}/director-uuid.yml
rm ${PWD}/efsbroker-creds.yml

