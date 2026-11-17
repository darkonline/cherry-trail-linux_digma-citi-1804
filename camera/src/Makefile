# Out-of-tree build of the stock atomisp staging driver + ipu-bridge + ov2680 + gc0310 (sources of kernel 6.18.63).
# Changes against the kernel tree: the include path in atomisp/Makefile (ATOMISP_DIR) and a test parameter
# in ov2680.c (invert_gpio) / gc0310.c (invert_gpios) that inverts the sensor GPIO polarity; default 0 = unchanged.
obj-m := ipu-bridge.o ov2680.o gc0310.o atomisp/
export CONFIG_VIDEO_ATOMISP := m
export ATOMISP_DIR := $(CURDIR)/atomisp
ccflags-y := -DCONFIG_IPU_BRIDGE_MODULE=1 -DCONFIG_VIDEO_ATOMISP_MODULE=1
KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build
all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) CONFIG_VIDEO_ATOMISP=m modules
clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
