# berb-droidian-kernel-build-docker-mgr
This is a bash script that can manage docker containers for use with the Droidian build tools docker image.

Additionally, it can create the debian packaging for Droidian files and the debconfig fragment files.

Also automates the debian/control recreation and releng execution.

### Usage
- The tool should be launched from a kernel source dir that also contains a .git dir
- Once the tool is executed, a options menú will be showed
- The docker container needs to be created and started with the corresponding menu options before performing any kernel operation.
- Is not needed to suply any information such a container or image name when using the docker management operations.
- The option \"Configure Droidian kernel\" will download the debian packaging and defconfig fragments files to the source tree if they not exist.
- The option \"Build kernel on container\" will execute the abobe config kernel feature, creates a caller script on kerneldir/compile-droidian-kernel.sh, and exec it inside the docker container.

ADVICE: The docker commit feature needs revision since lass update that enables multiple container for multiple kernel sources.

