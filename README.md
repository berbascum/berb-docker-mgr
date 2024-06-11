# berb-docker-mgr
Bash script to manage docker containers.

### Usage

## Tips

### Enable cross compile in container
This feature will use \"target_arch\" and \"cross_arch\" when enabling multiarch.

### Docker image tags:
There are two image tag configurable aspects, the suite and the arch to use.
And there are two contexts where can be applied

- Plugins default and build_debian_package:
  Can be configured in the \$HOME/.config/berb-docker-mgr/bdm-user-main.conf using the \"host_arch\" and \"host_suite\"
  
- Plugin build_droidiann_adaptation:
  Can be configured in the \$HOME/.config/berb-docker-mgr/bdm-user-droidian.conf using the \"droidian_host_arch\" and \"droidian_host_suite\"


### Plugin build_droidian_adaptation
- To build the adaptation for arm64 from amd64 on a docker container with multiarch enabled, just set the \"releng_host_arch\" var in \$HOME/.config/berb-docker-mgr/bdm-user-droidian.conf


ADVICE: The docker commit feature needs revision since lass update that enables multiple container for multiple kernel sources.

