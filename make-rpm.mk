PKGNAME=$(shell basename *.spec .spec)
VERSION?=0.0.0# assign zeros only if not specified from cmdline by make {target} VERSION=1.2.3
GROUP?=com.example # used when uploading to artifact repository
WORKDIR:=/tmp/
RELEASE=$(shell grep -oP '(?<=^Release: ).*' $(PKGNAME).spec | xargs rpm --eval)
BUILDARCH=$(shell grep -oP '(?<=^BuildArch: ).*' $(PKGNAME).spec)
RPMDIR=$(shell rpm --eval %{_rpmdir})
prefix=$(DESTDIR)$(shell rpm --eval %{_prefix})
bindir=$(DESTDIR)$(shell rpm --eval %{_bindir})
datadir_short=$(shell rpm --eval %{_datadir})
datadir=$(DESTDIR)$(datadir_short)
pkgdatadir_short=$(datadir_short)/$(PKGNAME)
pkgdatadir=$(datadir)/$(PKGNAME)
libdir=$(DESTDIR)$(shell rpm --eval %{_libdir})
defaultdocdir=$(DESTDIR)$(shell rpm --eval %{_defaultdocdir})
initrddir=$(DESTDIR)$(shell rpm --eval %{_initrddir})
sysconfdir:=$(DESTDIR)$(shell rpm --eval %{_sysconfdir})
pythonsitedir:=$(DESTDIR)$(shell python -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())")
DISTTAG=$(shell rpm --eval '%{dist}' | tr -d '.')
SRPMDIR=$(shell rpm --eval '%{_srcrpmdir}')
TARGETS='6 7'

# takes the content of current working directory and packs it to tgz
define do-distcwd
	# make --no-print-directory -s changelog | grep -v '^$$' > ChangeLog
	rm -f $(WORKDIR)/$(PKGNAME).tgz
	tar cvzf $(WORKDIR)/$(PKGNAME).tgz --transform "s,^\.,$(PKGNAME)-$(VERSION)," .
endef

# requires repository-tools for uploading to Sonatype Nexus
define do-upload
	artifact upload $(UPLOAD_OPTIONS) $(RPMDIR)/$(BUILDARCH)/$(PKGNAME)-$(VERSION)-$(RELEASE).$(BUILDARCH).rpm packages-$(DISTTAG) $(GROUP)
endef

distcwd:
	$(do-distcwd)

rpm: distcwd
	rpmbuild --define "VERSION $(VERSION)" -ta $(WORKDIR)/$(PKGNAME).tgz

srpm: distcwd
	rpmbuild -ts ${WORKDIR}/$(PKGNAME).tgz

# RPMs for all distributions - TBD
rpmscwd: srpm
	for target in TARGETS; do \
	    mock --rebuild -r epel-$(TARGET)-x86_64 $(SRPMDIR)/*.src.rpm \
	done

upload: rpm
	$(do-upload)

changelog:
	git log --pretty=format:"%d%n    * %s [%an, %ad]"  --date=short

installChangelog:
	mkdir -p $(defaultdocdir)/$(PKGNAME)-$(VERSION)
	install -m 644 ChangeLog $(defaultdocdir)/$(PKGNAME)-$(VERSION)
