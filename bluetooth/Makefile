# Out-of-tree build of the stock hci_uart driver with two extra options:
#   CONFIG_BT_HCIUART_3WIRE (H5 protocol) and CONFIG_BT_HCIUART_RTL (Realtek over UART),
# needed for the RTL8723BS Bluetooth (ACPI OBDA8723) on Digma CITI 1804.
# The source files are unmodified copies of drivers/bluetooth/ from the same kernel version.
# All other protocols stay exactly as in the Alpine linux-lts config
# (SERDEV, H4, BCSP, LL, ATH3K, INTEL, BCM, QCA, AG6XX are already =y in the kernel's autoconf).

obj-m := hci_uart.o
hci_uart-y := hci_ldisc.o hci_serdev.o hci_h4.o hci_bcsp.o hci_ll.o hci_ath.o \
              hci_h5.o hci_intel.o hci_bcm.o hci_qca.o hci_ag6xx.o
ccflags-y := -DCONFIG_BT_HCIUART_3WIRE -DCONFIG_BT_HCIUART_RTL

KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build

all:
	$(MAKE) -C $(KDIR) M=$(CURDIR) modules

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) clean
