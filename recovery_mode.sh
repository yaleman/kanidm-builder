#!/bin/bash

if [ -z "$1" ]; then
        echo "Didn't specify a volume to recover, here's a list"
        docker volume ls | awk '{print $2}' | grep -E '^kanidm_'
        exit 1
fi

echo "######################################"
echo " RECOVERY COMMANDS"
echo "######################################"

# shellcheck disable=SC1091
source .env

#shellcheck disable=SC2016,SC1004
echo 'aws --endpoint-url "${S3_HOSTNAME}" \
        --no-verify-ssl \
        s3 sync \
        "/data/${OSID}/${VERSION}/target/release" \
        "s3://${BUILD_ARTIFACT_BUCKET}/${OSID}/${VERSION}/$(uname -m)/" 2>&1'

if [ "$(docker volume ls | grep -cE "$1\$")" -eq 0 ]; then
        echo "User specified recovery on $1, no volumes found. List of volumes:"
        docker volume ls
        exit 1
elif [ "$(docker volume ls | grep -cE "$1\$")" -ne 1 ]; then
        echo "User specified recovery on $1, result of searching for volume was invalid (matches != 1), found:"
        docker volume ls | grep -cE "$1\$"
        exit 1
fi

echo "######################################"
echo " RUNNING CONTAINER ${1}"
echo "######################################"

docker run --rm -it --env-file=.env -e "RECOVERY_MODE=1" --volume "$1:/data" "$1"  bash

