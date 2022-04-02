#!/bin/bash

if [ ! -d venv ]; then
	echo "Couldn't find virtualenv, creating"
	virtualenv venv

	# shellcheck disable=SC1091
	source venv/bin/activate
	python3 -m pip install -r requirements.txt pylint black
fi

# shellcheck disable=SC1091
source venv/bin/activate
python3 -m pylint build_with_docker.py --disable=W0511
