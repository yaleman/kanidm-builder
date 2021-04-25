#!/bin/bash

echo "######################################"
echo " RECOVERY COMMANDS"
echo "######################################"

#shellcheck disable=SC2016


echo 'aws --endpoint-url "${S3_HOSTNAME}" \
        --no-verify-ssl \
        s3 sync \
        "/data/${OSID}/${VERSION}/target/release" \
        "s3://kanidm-builds/${OSID}/${VERSION}/$(uname -m)/" 2>&1'

echo "######################################"
echo " RUNNING CONTAINER"
echo "######################################"
docker run --rm -it --env-file=.env --volume "$1:/data" $1  bash

