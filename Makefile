
#VIVADO_VERSION ?= 2020.1
#VIVADO_VERSION ?= 2022.1
export ADI_IGNORE_VERSION_CHECK = 1
SKIP_LEGAL=1
# Use Buildroot External Linaro GCC 7.3-2018.05 arm-linux-gnueabihf Toolchain
#CROSS_COMPILE = arm-linux-gnueabihf-
CROSS_COMPILE = arm-none-linux-gnueabihf-
TOOLS_PATH = PATH="$(CURDIR)/buildroot/output/host/bin:$(CURDIR)/buildroot/output/host/sbin:$(PATH)"
TOOLCHAIN = $(CURDIR)/buildroot/output/host/bin/$(CROSS_COMPILE)gcc
ABSOLUTE_PATH=$(shell cd `dirname "${BASH_SOURCE[0]}"` && pwd)
BOARD=$(ABSOLUTE_PATH/board)/datv/board
BR2_EXTERNAL=$(ABSOLUTE_PATH)/datv
BR2_PACKAGE_BUSYBOX_CONFIG=$(BR2_EXTERNAL)/datv/board/pluto/busybox-1.25.0.config

BR2_EXTERNAL_PLUTOSDR_PATH=$(shell cd `dirname "${BASH_SOURCE[0]}"` && pwd)/datv
NCORES = $(shell grep -c ^processor /proc/cpuinfo)
VIVADO_SETTINGS ?= /opt/Xilinx/Vivado/$(VIVADO_VERSION)/settings64.sh
VSUBDIRS = maia-sdr buildroot linux u-boot-xlnx

#VERSION=$(shell git describe --abbrev=4 --always --tags)
PATCH=$(shell cd datv && ./applypatch.sh )
$(shell git log --pretty=format:"%h - %ad : %s" > datv/board/pluto/overlay/root/fwhistory.txt)
#LATEST_TAG=$(shell git describe --abbrev=0 --tags)
LATEST_TAG=maia-sdr-v0.4.1
UBOOT_VERSION=$(shell echo -n "PlutoSDR " && cd u-boot-xlnx && git describe --abbrev=0 --dirty --always --tags)
HAVE_VIVADO= $(shell bash -c "source $(VIVADO_SETTINGS) > /dev/null 2>&1 && vivado -version > /dev/null 2>&1 && echo 1 || echo 0")
#XSA_URL ?= http://github.com/maia-sdr/plutosdr-fw/releases/download/${LATEST_TAG}/system_top.xsa

ifeq (1, ${HAVE_VIVADO})
	VIVADO_INSTALL= $(shell bash -c "source $(VIVADO_SETTINGS) > /dev/null 2>&1 && vivado -version | head -1 | awk '{print $2}'")
	ifeq (, $(findstring $(VIVADO_VERSION), $(VIVADO_INSTALL)))
$(warning *** This repository has only been tested with $(VIVADO_VERSION),)
$(warning *** and you have $(VIVADO_INSTALL))
$(warning *** Please 1] set the path to Vivado $(VIVADO_VERSION) OR)
$(warning ***        2] remove $(VIVADO_INSTALL) from the path OR)
$(error "      3] export VIVADO_VERSION=v20xx.x")
	endif
endif

##PATCH COMMAND NEED TO BE INVOCATED  
ifneq (1, ${PATCH})
    $(warning patch granted $(PATCH))
endif

TARGET ?= pluto
SUPPORTED_TARGETS:=pluto sidekiqz2 plutoplus e200
XSA_FILE ?= datv/bitstream/${TARGET}/system_top.xsa

$(warning *** Building target $(TARGET),)

# Include target specific constants
include scripts/$(TARGET).mk

ifeq (, $(shell which dfu-suffix))
$(warning "No dfu-utils in PATH consider doing: sudo apt-get install dfu-util")
TARGETS = build/pluto.frm build/boot.frm sdimg
else
TARGETS = build/$(TARGET).dfu build/uboot-env.dfu build/pluto.frm  build/boot.dfu build/boot.frm sdimg
endif

ifeq ($(findstring $(TARGET),$(SUPPORTED_TARGETS)),)
all:
	@echo "Invalid `TARGET variable ; valid values are: pluto, sidekiqz2, plutoplus" &&
	exit 1
else
all: clean-build $(TARGETS) zip-all legal-info
endif

.NOTPARALLEL: all

TARGET_DTS_FILES:=$(foreach dts,$(TARGET_DTS_FILES),build/$(dts))

TOOLCHAIN:
	make BR2_EXTERNAL=$(ABSOLUTE_PATH)/datv -C buildroot ARCH=arm zynq_plutodatv_defconfig
	make -C buildroot toolchain

build:
	mkdir -p $@

%: build/%
	cp $< $@


### u-boot ###

u-boot-xlnx/u-boot u-boot-xlnx/tools/mkimage: TOOLCHAIN
#	$(TOOLS_PATH) make -C u-boot-xlnx ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zynq_$(TARGET)_defconfig
	$(TOOLS_PATH) make -C u-boot-xlnx ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zynq_$(TARGET)_defconfig
	$(TOOLS_PATH) make -C u-boot-xlnx ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) UBOOTVERSION="$(UBOOT_VERSION)"

.PHONY: u-boot-xlnx/u-boot

build/u-boot.elf: u-boot-xlnx/u-boot | build
	cp $< $@

build/uboot-env.txt: u-boot-xlnx/u-boot TOOLCHAIN | build
	$(TOOLS_PATH) CROSS_COMPILE=$(CROSS_COMPILE) scripts/get_default_envs.sh > $@

build/uboot-env.bin: build/uboot-env.txt
	u-boot-xlnx/tools/mkenvimage -s 0x20000 -o $@ $<

### Linux ###

linux/arch/arm/boot/zImage: TOOLCHAIN
	$(TOOLS_PATH) make -C linux -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zynq_$(TARGET)_linux_defconfig zImage UIMAGE_LOADADDR=0x8000
	$(TOOLS_PATH) make -C linux -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zynq_$(TARGET)_linux_defconfig uImage UIMAGE_LOADADDR=0x8000
##	$(TOOLS_PATH) make -C linux ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) defconfig zynq_$(TARGET)_defconfig
##$(TOOLS_PATH) make BR2_LINUX_KERNEL_CUSTOM_CONFIG_FILE=$(ABSOLUTE_PATH)/datv/configs/zynq_$(TARGET)datv_linux_defconfig -C linux -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) zImage UIMAGE_LOADADDR=0x8000

.PHONY: linux/arch/arm/boot/zImage
.PHONY: linux/arch/arm/boot/uImage

build/zImage: linux/arch/arm/boot/zImage | build
	cp $< $@

build/uImage: linux/arch/arm/boot/uImage | build
	cp $< $@


### Device Tree ###

linux/arch/arm/boot/dts/%.dtb: TOOLCHAIN linux/arch/arm/boot/dts/%.dts  linux/arch/arm/boot/dts/zynq-pluto-sdr.dtsi linux/arch/arm/boot/dts/zynq-pluto-sdr-maiasdr.dtsi
	$(TOOLS_PATH) DTC_FLAGS=-@ make -C linux -j $(NCORES) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) $(notdir $@)

build/%.dtb: linux/arch/arm/boot/dts/%.dtb | build
	dtc -q -@ -I dtb -O dts $< | sed 's/axi {/amba {/g' | dtc -q -@ -I dts -O dtb -o $@

### maia-kmod ###
maia-sdr/maia-kmod/maia-sdr.ko: TOOLCHAIN
	$(TOOLS_PATH) make -C linux ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) modules_prepare
	$(TOOLS_PATH) make -C maia-sdr/maia-kmod ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) KERNEL_SRC=../../linux

.PHONY: maia-sdr/maia-kmod/maia-sdr.ko

buildroot/board/$(TARGET)/maia-sdr.ko: maia-sdr/maia-kmod/maia-sdr.ko | build
	cp $< $@

### maia-httpd ###
#
maia-sdr/maia-httpd/target/armv7-unknown-linux-gnueabihf/release/maia-httpd: TOOLCHAIN
	cd maia-sdr/maia-httpd && \
		$(TOOLS_PATH) cargo build --release --target armv7-unknown-linux-gnueabihf \
		--config target.armv7-unknown-linux-gnueabihf.linker=\"arm-linux-gnueabihf-gcc\"

.PHONY: maia-sdr/maia-httpd/target/armv7-unknown-linux-gnueabihf/release/maia-httpd

buildroot/board/$(TARGET)/maia-httpd: maia-sdr/maia-httpd/target/armv7-unknown-linux-gnueabihf/release/maia-httpd | build
	cp $< $@

### maia-wasm ###
maia-sdr/maia-wasm/pkg:
	cd maia-sdr/maia-wasm && wasm-pack build --target web

.PHONY: maia-sdr/maia-wasm/pkg

buildroot/board/$(TARGET)/maia-wasm:
	mkdir $@

buildroot/board/$(TARGET)/maia-wasm/pkg: maia-sdr/maia-wasm/pkg | build buildroot/board/$(TARGET)/maia-wasm
	cp -r $< buildroot/board/$(TARGET)/maia-wasm/

buildroot/board/$(TARGET)/maia-wasm/assets: maia-sdr/maia-wasm/assets | build buildroot/board/$(TARGET)/maia-wasm
	cp -r $< buildroot/board/$(TARGET)/maia-wasm/

maia-wasm: buildroot/board/$(TARGET)/maia-wasm/pkg buildroot/board/$(TARGET)/maia-wasm/assets

.PHONY: maia-wasm

### DATV 
### nco-kmod ###
linux_driver/nco_counter_core/nco_counter_core.ko: TOOLCHAIN
	$(TOOLS_PATH) make -C linux ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) modules_prepare
	$(TOOLS_PATH)  make -C linux_driver/nco_counter_core ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) KERNEL_SRC=../../linux

.PHONY: linux_driver/nco_counter_core/nco_counter_core.ko

$(BR2_EXTERNAL)/board/pluto/overlay/lib/modules/nco_counter_core.ko: linux_driver/nco_counter_core/nco_counter_core.ko | build
	cp $< $@

## Plutostream 
pluto-ori-ps/pluto_stream: TOOLCHAIN
	$(TOOLS_PATH)  make pluto_stream -C pluto-ori-ps VER=$(VERSION) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE)

.PHONY: pluto-ori-ps/pluto_stream

$(BR2_EXTERNAL)/board/pluto/overlay/root/pluto_stream: pluto-ori-ps/pluto_stream | build
	cp $< $@

## Plutomqttctrl
pluto-ori-ps/pluto_mqtt_ctrl: TOOLCHAIN
	$(TOOLS_PATH) make pluto_mqtt_ctrl -C pluto-ori-ps ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE)
	$(TOOLS_PATH) PAPR_ORI=$(BR2_EXTERNAL)/board/pluto/overlay/root make install -C pluto-ori-ps ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE)
.PHONY: pluto-ori-ps/pluto_mqtt_ctrl

$(BR2_EXTERNAL)/board/pluto/overlay/root/pluto_mqtt_ctrl: pluto-ori-ps/pluto_mqtt_ctrl | build
	cp $< $@

## Longmynd
longmynd/longmynd: TOOLCHAIN
	$(TOOLS_PATH)  env=local make longmynd -C longmynd ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE)

.PHONY: longmynd/longmynd

$(BR2_EXTERNAL)/board/pluto/overlay/root/datv/longmynd: longmynd/longmynd | build
	cp $< $@	

### Buildroot ###

buildroot/output/images/rootfs.cpio.gz: 
	@echo device-fw $(VERSION)> $(BR2_EXTERNAL)/board/pluto/VERSIONS
	@$(foreach dir,$(VSUBDIRS),echo $(dir) $(shell cd $(dir) && git describe --abbrev=4 --dirty --always --tags) >> $(BR2_EXTERNAL)/board/pluto/VERSIONS;)
	make BR2_EXTERNAL=$(ABSOLUTE_PATH)/datv -C buildroot ARCH=arm zynq_plutodatv_defconfig
##	make -C buildroot ARCH=arm zynq_$(TARGET)_defconfig

ifneq (1, ${SKIP_LEGAL})
	make -C buildroot legal-info
	scripts/legal_info_html.sh "$(COMPLETE_NAME)" "$(CURDIR)/buildroot/board/pluto/VERSIONS"
	cp build/LICENSE.html buildroot/board/pluto/msd/LICENSE.html
endif

	make -C buildroot BUSYBOX_CONFIG_FILE=$(BR2_EXTERNAL)/board/pluto/busybox-1.25.0.config all

.PHONY: buildroot/output/images/rootfs.cpio.gz


## Invoke again buildroot to add datv bin in rootfs
build/rootfs.cpio.gz: buildroot/output/images/rootfs.cpio.gz $(BR2_EXTERNAL)/board/pluto/overlay/lib/modules/nco_counter_core.ko $(BR2_EXTERNAL)/board/pluto/overlay/root/pluto_mqtt_ctrl $(BR2_EXTERNAL)/board/pluto/overlay/root/pluto_stream $(BR2_EXTERNAL)/board/pluto/overlay/root/datv/longmynd | build
	make -C buildroot BUSYBOX_CONFIG_FILE=$(BR2_EXTERNAL)/board/pluto/busybox-1.25.0.config all
	cp $< $@

build/$(TARGET).itb: u-boot-xlnx/tools/mkimage build/zImage build/rootfs.cpio.gz $(TARGET_DTS_FILES) build/system_top.bit
	u-boot-xlnx/tools/mkimage -f scripts/$(TARGET).its $@

build/system_top.xsa:  | build
ifneq ($(XSA_FILE),)
	cp $(XSA_FILE) $@
else ifneq ($(XSA_URL),)
	wget -T 3 -t 1 -N --directory-prefix build $(XSA_URL)
else ifeq (1, ${HAVE_VIVADO})
#bash -c "source $(VIVADO_SETTINGS) && make -C maia-sdr/maia-hdl/projects/$(TARGET) && cp maia-sdr/maia-hdl/projects/$(TARGET)/$(TARGET).sdk/system_top.xsa $@"
#unzip -l $@ | grep -q ps7_init || cp maia-sdr/maia-hdl/projects/$(TARGET)/$(TARGET).srcs/sources_1/bd/system/ip/system_sys_ps7_0/ps7_init* build/
ifeq ($(TARGET),pluto)
	bash -c "source $(VIVADO_SETTINGS) && make -C ../hdl/projects/pluto-ori && cp ../hdl/projects/pluto-ori/pluto.sdk/system_top.xsa $@"
	unzip -l $@ | grep -q ps7_init || cp ../hdl/projects/pluto-ori/pluto.srcs/sources_1/bd/system/ip/system_sys_ps7_0/ps7_init* build/
endif	
ifeq ($(TARGET),plutoplus)
	bash -c "source $(VIVADO_SETTINGS) && make -C ../hdl/projects/pluto-ori-plus && cp ../hdl/projects/pluto-ori-plus/pluto.sdk/system_top.xsa $@"
	unzip -l $@ | grep -q ps7_init || cp ../hdl/projects/pluto-ori-plus/pluto.srcs/sources_1/bd/system/ip/system_sys_ps7_0/ps7_init* build/
endif
ifeq ($(TARGET),e200)
	bash -c "source $(VIVADO_SETTINGS) && make -C ../hdl/projects/pluto-ori-e200 && cp ../hdl/projects/pluto-ori-e200/e200.sdk/system_top.xsa $@"
	unzip -l $@ | grep -q ps7_init || cp ../hdl/projects/pluto-ori-e200/e200.srcs/sources_1/bd/system/ip/system_sys_ps7_0/ps7_init* build/
endif	
#bash -c "source $(VIVADO_SETTINGS) && make -C ../hdl/projects/pluto-ori-plus"
endif

### TODO: Build system_top.xsa from src if dl fails ...

build/fsbl.elf build/system_top.bit : build/system_top.xsa
	rm -Rf build/sdk
ifeq (1, ${HAVE_VIVADO})
	bash -c "source $(VIVADO_SETTINGS) && xsct scripts/create_fsbl_project.tcl"
else
	unzip -o build/system_top.xsa system_top.bit -d build
endif

build/boot.bin: build/fsbl.elf build/u-boot.elf
	@echo img:{[bootloader] $^ } > build/boot.bif
ifeq (1, ${HAVE_VIVADO})
	bash -c "source $(VIVADO_SETTINGS) && bootgen -image build/boot.bif -w -o $@"
	cp build/sdk/fsbl/Release/fsbl.elf build/fsbl.elf
else
	cp datv/bitstream/$(TARGET)/fsbl.elf build/fsbl.elf
	bash -c "bootgen -image build/boot.bif -w -o $@"
endif
### MSD update firmware file ###

build/pluto.frm: build/$(TARGET).itb
	md5sum $< | cut -d ' ' -f 1 > $@.md5
	cat $< $@.md5 > $@

build/boot.frm: build/boot.bin build/uboot-env.bin scripts/target_mtd_info.key
	cat $^ | tee $@ | md5sum | cut -d ' ' -f1 | tee -a $@

### DFU update firmware file ###

build/%.dfu: build/%.bin
	cp $< $<.tmp
	dfu-suffix -a $<.tmp -v $(DEVICE_VID) -p $(DEVICE_PID)
	mv $<.tmp $@

build/$(TARGET).dfu: build/$(TARGET).itb
	cp $< $<.tmp
	dfu-suffix -a $<.tmp -v $(DEVICE_VID) -p $(DEVICE_PID)
	mv $<.tmp $@

SDIMGDIR = build/sdimg
sdimg: build | build/rootfs.cpio.gz
	mkdir -p $(SDIMGDIR)
	cp datv/bitstream/$(TARGET)/fsbl.elf 	$(SDIMGDIR)/fsbl.elf  
	cp build/system_top.bit 	$(SDIMGDIR)/system_top.bit
	cp build/u-boot.elf 			$(SDIMGDIR)/u-boot.elf
	cp linux/arch/arm/boot/uImage	$(SDIMGDIR)/uImage

ifeq ($(TARGET),pluto)
	cp build/zynq-pluto-sdr-maiasdr.dtb 	$(SDIMGDIR)/devicetree.dtb
endif	
ifeq ($(TARGET),plutoplus)
	cp build/zynq-plutoplus-maiasdr.dtb 	$(SDIMGDIR)/devicetree.dtb
endif	
ifeq ($(TARGET),e200)
	cp build/zynq-e200.dtb 	$(SDIMGDIR)/devicetree.dtb
endif	
	cp build/uboot-env.txt  		$(SDIMGDIR)/uEnv.txt
	cp build/rootfs.cpio.gz  		$(SDIMGDIR)/ramdisk.image.gz
	mkimage -A arm -T ramdisk -C gzip -d $(SDIMGDIR)/ramdisk.image.gz $(SDIMGDIR)/uramdisk.image.gz
	touch 	$(SDIMGDIR)/boot.bif
	echo "img : {[bootloader] $(SDIMGDIR)/fsbl.elf  $(SDIMGDIR)/system_top.bit  $(SDIMGDIR)/u-boot.elf}" >  $(SDIMGDIR)/boot.bif
	bootgen -image $(SDIMGDIR)/boot.bif -w -o i $(SDIMGDIR)/BOOT.bin
	rm $(SDIMGDIR)/fsbl.elf
	rm $(SDIMGDIR)/system_top.bit
	rm $(SDIMGDIR)/u-boot.elf
	rm $(SDIMGDIR)/ramdisk.image.gz 
	rm $(SDIMGDIR)/boot.bif


clean-build:
	rm -f $(notdir $(wildcard build/*))
	rm -rf build/*

clean:
	make -C u-boot-xlnx clean
	make -C linux clean
	make -C buildroot clean
	make -C maia-sdr/maia-hdl clean
	cd maia-sdr/maia-httpd; cargo clean
	cd maia-sdr/maia-wasm; cargo clean
	rm -f $(notdir $(wildcard build/*))
	rm -rf build/*

zip-all: $(TARGETS)
	mkdir -p Release && cd build &&	zip -r ../Release/$(ZIP_ARCHIVE_PREFIX)-fw-$(VERSION).zip *.dfu *.frm sdimg

dfu-$(TARGET): build/$(TARGET).dfu
	dfu-util -D build/$(TARGET).dfu -a firmware.dfu
	dfu-util -e

dfu-sf-uboot: build/boot.dfu build/uboot-env.dfu
	echo "Erasing u-boot be careful - Press Return to continue... " && read key  && \
		dfu-util -D build/boot.dfu -a boot.dfu && \
		dfu-util -D build/uboot-env.dfu -a uboot-env.dfu
	dfu-util -e

dfu-all: build/$(TARGET).dfu build/boot.dfu build/uboot-env.dfu
	echo "Erasing u-boot be careful - Press Return to continue... " && read key && \
		dfu-util -D build/$(TARGET).dfu -a firmware.dfu && \
		dfu-util -D build/boot.dfu -a boot.dfu  && \
		dfu-util -D build/uboot-env.dfu -a uboot-env.dfu
	dfu-util -e

dfu-ram: build/$(TARGET).dfu
	sshpass -p analog ssh root@$(TARGET) '/usr/sbin/device_reboot ram;'
	sleep 7
	dfu-util -D build/$(TARGET).dfu -a firmware.dfu
	dfu-util -e

jtag-bootstrap: build/u-boot.elf build/ps7_init.tcl build/system_top.bit scripts/run.tcl scripts/run-xsdb.tcl
	$(TOOLS_PATH) $(CROSS_COMPILE)strip build/u-boot.elf
	zip -j build/$(ZIP_ARCHIVE_PREFIX)-$@-$(VERSION).zip $^

sysroot: buildroot/output/images/rootfs.cpio.gz
	tar czfh build/sysroot-$(VERSION).tar.gz --hard-dereference --exclude=usr/share/man --exclude=dev --exclude=etc -C buildroot/output staging

legal-info: buildroot/output/images/rootfs.cpio.gz
ifneq (1, ${SKIP_LEGAL})
	tar czvf build/legal-info-$(VERSION).tar.gz -C buildroot/output legal-info
endif


git-update-all:
	git submodule update --recursive --remote

git-pull:
	git pull --recurse-submodules
