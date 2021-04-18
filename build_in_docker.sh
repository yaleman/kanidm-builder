#!/bin/bash

# builds the packages in docker
mkdir -p ./output

if [ ! -f ".env" ]; then
    echo "Couldn't find a .env file, making a blank one"
    touch .env
fi

echo "###########################"
echo "Building images"
echo "###########################"
docker-compose build || {
    echo "Failed to build docker imags, quitting"
    exit 1
}
echo "###########################"
echo "Building kanidm"
echo "###########################"

docker-compose up -d --force-recreate || {
    echo "Couldn't bring up instances"
    exit 1
}

docker-compose logs -f
