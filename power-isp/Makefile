# Out-of-tree build of the stock drivers/platform/x86/intel/atomisp2/pm.c (unmodified).
obj-m := intel_atomisp2_pm.o
intel_atomisp2_pm-y := pm.o
KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build
all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules
clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
