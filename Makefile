###############################################################################
# Makefile by Carlo Wood (and others)

# Determine the machine type
ARCH := $(shell uname -m | sed -e s/i.86/i386/ -e s/sun4u/sparc64/ -e s/arm.*/arm/ -e s/sa110/arm/)

# Setup machine dependant compiler flags
ifeq ($(ARCH), i386)
CFLAGS ?= -O2 -mcpu=pentium -fomit-frame-pointer -fno-strength-reduce \
          -falign-loops=2 -falign-jumps=2 -falign-functions=2
endif

ifeq ($(ARCH), alpha)
CFLAGS ?= -O2 -mno-fp-regs -mcpu=ev4 -ffixed-8 -Wa,-mev6 \
          -fomit-frame-pointer -fno-strict-aliasing
endif

KHEADERS ?= /usr/include
KVERS ?= $(shell ./kinfo --UTS)
MODULES_DIR = $(DESTDIR)/lib/modules/$(KVERS)

ALL_CFLAGS := -DMODULE -D__KERNEL__ \
              -I$(KHEADERS) -I$(KHEADERS)/asm/mach-default \
              $(CFLAGS)

###############################################################################
# You should never need to change anything below.

all: sanity module

# Sanity checks
sanity:
	@( \
	if [ ! -r $(KHEADERS)/linux ]; then \
		echo "Expect readable headers in $(KHEADERS)/linux"; \
		exit -1; \
	fi; \
	if [ ! -r $(KHEADERS)/linux/version.h ]; then \
		echo "Missing $(KHEADERS)/linux/version.h"; \
		echo "Configure and install the kernel first"; \
		exit -1; \
	fi; \
	if [ ! -e /proc/cpuinfo ]; then \
		echo "You need the /proc file system"; \
		echo "Reconfigure kernel and say Yes to CONFIG_PROC_FS"; \
		exit -1; \
	fi; \
	)

config: kinfo
	@( \
	KVER_MAJOR=`echo $(KVERS) | cut -d. -f1`; \
	KVER_MINOR=`echo $(KVERS) | cut -d. -f2`; \
	if [ "$$KVER_MAJOR" = 2 -a "$$KVER_MINOR" -ge 6 ]; then \
	  echo MODULE_TDFX = 3dfx.ko; \
	else \
	  echo MODULE_TDFX = 3dfx.o; \
	fi; \
	) > config
	@$(MAKE) $(MAKECMDGOALS) configured-target=1

kinfo: kinfo.c
	$(CC) -I$(KHEADERS) -o kinfo kinfo.c

kinfo.h: kinfo
	@echo Generating kernel information header.
	@./kinfo

###############################################################################
# kernel 2.1+

-include config

ifeq ($(configured-target),0)
module: config
else
module: $(MODULE_TDFX)
endif

3dfx.o 3dfx.ko: kinfo.h 3dfx_driver.c Makefile
	$(CC) $(ALL_CFLAGS) -c -o $@ 3dfx_driver.c

###############################################################################

install_modules: module
	mkdir -p $(MODULES_DIR)/misc
	cp $(MODULE_TDFX) $(MODULES_DIR)/misc/

install: install_modules
	@( \
	if [ -e $(MODULES_DIR)/modules.dep ]; then \
		indep=`grep 'misc/$(MODULE_TDFX):' $(MODULES_DIR)/modules.dep`; \
		if [ -z "$$indep" ]; then \
			echo "$(MODULES_DIR)/misc/$(MODULE_TDFX):" >> $(MODULES_DIR)/modules.dep; \
			echo "" >> $(MODULES_DIR)/modules.dep; \
		fi; \
	fi; \
	if [ ! -e $(DESTDIR)/dev/.devfsd -a ! -c $(DESTDIR)/dev/3dfx ]; then \
		mknod $(DESTDIR)/dev/3dfx c 107 0; \
		chmod go+w $(DESTDIR)/dev/3dfx; \
	fi; \
	if [ "$(RPM_INSTALL)" = "1" ]; then \
		echo "$(MODULES_DIR)/misc/$(MODULE_TDFX)"; \
	else \
		inconf=`grep 'alias char-major-107 3dfx' $(DESTDIR)/etc/modules.conf`; \
		if [ -z "$$inconf" ]; then \
			echo "alias char-major-107 3dfx" >> $(DESTDIR)/etc/modules.conf; \
		fi; \
	fi; \
	)

###############################################################################
# This is for debugging purposes by the developers:

clean:
	rm -f *.o *.ko *.s
	rm -f kinfo kinfo.h
	rm -f config

3dfx.s: 3dfx_driver.c Makefile
	$(CC) $(ALL_CFLAGS) -S -c 3dfx_driver.c

tar:
	tar czf ../../SOURCES/Dev3Dfx-2.5.tar.gz 3dfx_driver.c Makefile

debug:
	$(MAKE) CFLAGS="-g -Wall -Wstrict-prototypes -DDEBUG"

.PHONY: all sanity module install_modules install clean tar debug

