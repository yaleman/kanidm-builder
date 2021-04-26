# kanidm-builder

This is very very very very very early work on trying to make some standard build tools for kanidm to make releases I can use and probably even distribute.

Set the rust build version in `RUST_VERSION`.

This uses make and runs on operating systems with bash. Has been tested on Windows 10 WSL2 (ubuntu 20.04) and ... works OK. Works better in OpenSUSE Tumbleweed or another Linux variant.

## Usage

 1. clone the repo `git clone https://github.com/yaleman/kanidm-builder.git`
 2. copy template.env to .env and configure all your things
 2. run the thing `./build_in_docker.sh`

 ## I