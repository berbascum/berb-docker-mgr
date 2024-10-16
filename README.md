# berb-docker-mgr
Bash script to manage docker containers.

## Design
- The main script contain the general docker commands.

- There are plugins to enable different type of containers.

- Container types are primarily classified by the image to use.

- Some plugins may have subplugins as plugin subtypes.

## Plugins
Currently there are two plugins

### 1- Default:
As is the default plugin, it will be used if no any plugin is specified as script argument.

This plugin creates a container using the berb base image "berb-linux-env" and a generic container name, both currently defined in bdm_plugin_default.sh.

But if there is a file named docker-custom.conf in the current dir, the vars defined on it will ebe used instead.

### 2- Build:
When this plugin is enabled the script bdm_plugin_build_main.sh will be loaded.
Depending on the current dir content, the needed sub-plugin will be automatically selected.

This plugin sets the as the current directory name as container_name.

Currently there are next subplugins:
- Build Debian standard package
- Build Droidian adaptation
- Build Droidian kernel

## Installation
Add the berb-apt-git-repo and apt-get install berb-docker-mgr

## Usage
### Default plugin
berb-docker-mgr [--log-level=1]
### Build plugin
berb-docker-mgr [--log-level=1] --plugin=build
 
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

