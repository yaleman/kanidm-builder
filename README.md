# kanidm-builder

This is very very very very very early work on trying to make some standard build tools for kanidm to make releases I can use and probably even distribute.

Set the rust build version in `RUST_VERSION`.

This uses make and runs on operating systems with bash. Has been tested on Windows 10 WSL2 (ubuntu 20.04) and ... works OK. Works better in OpenSUSE Tumbleweed or another Linux variant.

It's designed to be able to push the artifacts to an S3 bucket

## Usage

 1. clone the repo `git clone https://github.com/yaleman/kanidm-builder.git`
 2. copy template.env to .env and configure all your things
 2. run the thing `./build_in_docker.sh`

 ## In case of failure

 `recovery_mode.sh` will mount the volume with the last build, with the image it was generated with - if you used the build tooling... the volume will be mounted at `/data` to avoid stepping on the default clone path of `/source`
 
 For example, run `recovery_mode.sh kanidm_build_ubuntu_focal`. Running it without specifying a unit will list the available volumes.