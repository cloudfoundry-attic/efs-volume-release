#!/bin/bash
set -e

usage () {
    echo "Usage: generate-bosh-lite-manifest.sh"
    echo " * default"
    exit 1
}

templates=$(dirname $0)/../templates

cat > ${PWD}/director-uuid.yml << EOF
---
director_uuid: $(bosh status --uuid)
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

