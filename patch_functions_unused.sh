fn_patch_kernel_snippet_cross_32() {
# Requires "CROSS_COMPILE_32 = arm-linux-gnueabi-" on kernel-info.mk
    ## Patch kenel-snippet.mk to fix vdso32 compilation for selected devices
    ## CURRENTLY not used since the Droidian packaging configures the 32 bit compiler
    if [ "$DEVICE_MODEL" == "vayu" ]; then
	echo; echo "Patching kernel-snippet.mk to avoid vdso32 build error on some devices"
	replace_pattern='s/CROSS_COMPILE_ARM32=$(CROSS_COMPILE)/CROSS_COMPILE_ARM32=$(CROSS_COMPILE_32)/g'
	CMD="sed -i ${replace_pattern} /usr/share/linux-packaging-snippets/kernel-snippet.mk"
	fn_cmd_on_container
    fi
}
fn_patch_kernel_snippet_python275b_path() {
    ## Patch kenel-snippet.mk to add te python275b path to the FULL_PATH var
    if [ "$DEVICE_MODEL" == "vayu" ]; then
	echo; echo "Patching kernel-snippet.mk to add te python275b path to the FULL_PATH var"
	# WORKS replace_pattern='s|debian/path-override:|debian/path-override:/buildd/sources/droidian/python/2.7.5/bin:|g'
	replace_pattern='s|$(BUILD_PATH):$(CURDIR)/debian/path-override:|$(BUILD_PATH):$(CURDIR)/debian/path-override:/buildd/sources/droidian/python/2.7.5/bin:|g'
	#replace_pattern="s|FULL_PATH = \$\(BUILD_PATH\)\:\$\(CURDIR\)\/debian\/path-override\:\$\{PATH\}|FULL_PATH = \$\(BUILD_PATH\)\:\$\(CURDIR\)\/debian\/path-override\:\/buildd\/sources\/droidian\/python\/2\.7\.5\/bin\:\$\{PATH\}|g"
	CMD="sed -i "${replace_pattern}" /usr/share/linux-packaging-snippets/kernel-snippet.mk"
	fn_cmd_on_container
    fi
}
