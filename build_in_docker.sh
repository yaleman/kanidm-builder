#!/bin/bash

# builds the packages in docker
mkdir -p ./output

if [ ! -f ".env" ]; then
    echo "Couldn't find a .env file, making a blank one"
    touch .env
fi

docker-compose build
docker-compose up
