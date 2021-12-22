include /usr/share/dpkg/pkg-info.mk
include /usr/share/dpkg/architecture.mk

PACKAGE = pve-qemu-kvm

SRCDIR := qemu
BUILDDIR ?= ${PACKAGE}-${DEB_VERSION_UPSTREAM}

GITVERSION := $(shell git rev-parse HEAD)

DEB = ${PACKAGE}_${DEB_VERSION_UPSTREAM_REVISION}_${DEB_BUILD_ARCH}.deb
DEB_DBG = ${PACKAGE}-dbg_${DEB_VERSION_UPSTREAM_REVISION}_${DEB_BUILD_ARCH}.deb
DEBS = $(DEB) $(DEB_DBG)

all: $(DEBS)

.PHONY: submodule
submodule:
	test -f "${SRCDIR}/configure" || git submodule update --init --recursive

$(BUILDDIR): keycodemapdb | submodule
	# check if qemu/ was used for a build
	# if so, please run 'make distclean' in the submodule and try again
	test ! -f $(SRCDIR)/build/config.status
	rm -rf $(BUILDDIR)
	cp -a $(SRCDIR) $(BUILDDIR)
	cp -a debian $(BUILDDIR)/debian
	rm -rf $(BUILDDIR)/ui/keycodemapdb
	cp -a keycodemapdb $(BUILDDIR)/ui/
	echo "git clone git@github.com:proxmox-ve-allcpu/pve-qemu-allvms.git\\ngit checkout $(GITVERSION)" > $(BUILDDIR)/debian/SOURCE

.PHONY: deb kvm
deb kvm: $(DEBS)
$(DEB_DBG): $(DEB)
$(DEB): $(BUILDDIR)
	cd $(BUILDDIR); dpkg-buildpackage -b -us -uc -j
	lintian $(DEBS)

.PHONY: update
update:
	cd $(SRCDIR) && git submodule deinit ui/keycodemapdb || true
	rm -rf $(SRCDIR)/ui/keycodemapdb
	mkdir $(SRCDIR)/ui/keycodemapdb
	cd $(SRCDIR) && git submodule update --init ui/keycodemapdb
	rm -rf keycodemapdb
	mkdir keycodemapdb
	cp -R $(SRCDIR)/ui/keycodemapdb/* keycodemapdb/
	git add keycodemapdb

.PHONY: upload
upload: $(DEBS)
	tar cf - ${DEBS} | ssh repoman@repo.proxmox.com upload --product pve --dist bullseye

.PHONY: distclean clean
distclean: clean
clean:
	rm -rf $(BUILDDIR) $(PACKAGE)*.deb *.buildinfo *.changes

.PHONY: dinstall
dinstall: $(DEBS)
	dpkg -i $(DEBS)
