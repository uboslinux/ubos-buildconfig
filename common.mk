#
# Include for all the Makefiles
#

SHELL=/bin/bash


ADMINHASROOT=
# ADMINHASROOT=--adminHasRoot 1

WORKAREA=.
TESTVNCSECRET=
TESTSCAFFOLD=$(TESTSCAFFOLD_HERE)
TESTVERBOSE=-v
DEVICE=pc

CONFIGDIR=config
GNUPGHOME=keys/ubos/buildmaster@ubos.net/gpg/
SSHDIR=keys/ubos/ubos-admin/ssh
IMPERSONATEDEPOT=
# IMPERSONATEDEPOT=:impersonatedepot
USBDEVICE=/dev/sde

ARCH!=uname -m | sed -e 's/armv6l/armv6h/'
ARCHUPSTREAMSITE_x86_64=http://mirror.us.leaseweb.net/archlinux
ARCHUPSTREAMSITE_arm=http://ca.us.mirror.archlinuxarm.org
UPLOADDEST=
UPLOADSSHKEY=
PACKAGESIGNKEY=
DBSIGNKEY=
SIGREQUIREDINSTALL=
# SIGREQUIREDINSTALL=--sigRequiredInstall 1
# signing is optional

BUILDDIR=$(WORKAREA)/build
TESTLOGSDIR=$(WORKAREA)

TESTSCAFFOLD_HERE=here$(IMPERSONATEDEPOT)
TESTSCAFFOLD_VBOX=v-box:vmdktemplate=$(IMAGESDIR)/$(ARCH)/images/ubos_$(CHANNEL)_x86_64_LATEST-vbox.vmdk:ubos-admin-public-key-file=$(SSHDIR)/id_rsa.pub:ubos-admin-private-key-file=$(SSHDIR)/id_rsa$(IMPERSONATEDEPOT)

DEPOTAPPCONFIGID!=sudo ubos-admin showappconfig --brief --host depot.ubos.net --context /$(CHANNEL) 2>/dev/null

ifdef DEPOTAPPCONFIGID
	IMAGESDIR=/var/lib/ubos-repo/$(DEPOTAPPCONFIGID)
	REPODIR=/var/lib/ubos-repo/$(DEPOTAPPCONFIGID)
else
	IMAGESDIR=$(WORKAREA)/images/$(CHANNEL)
	REPODIR=$(WORKAREA)/repository/$(CHANNEL)
endif

ifdef PACKAGESIGNKEY
	SIGNPACKAGESARG=--packageSignKey $(PACKAGESIGNKEY)
endif
ifdef DBSIGNKEY
	SIGNDBSARG=--dbSignKey $(DBSIGNKEY)
endif
ifdef TESTVNCSECRET
    TESTVNCSECRETARG=:vncsecret=$(TESTVNCSECRET)
endif
ifdef IMPERSONATEDEPOT
	ifndef DEPOTAPPCONFIGID
        $(error Cannot impersonate depot.ubos.net: host does not run the depot in channel $(CHANNEL))
	endif
endif

ifdef TESTSCAFFOLD
	TESTSCAFFOLDARG=--scaffold $(TESTSCAFFOLD)
endif
ifdef TESTVERBOSE
    TESTVERBOSEARG=--testverbose "$(TESTVERBOSE)"
endif
ifdef TESTLOGSDIR
	TESTLOGSARG=--testLogsDir $(TESTLOGSDIR)
endif

ifeq "$(ARCH)" "x86_64"
    ARCHUPSTREAMDIR=$(ARCHUPSTREAMSITE_x86_64)/$${db}/os/$${arch}
else
    ARCHUPSTREAMDIR=$(ARCHUPSTREAMSITE_arm)/$${arch}/$${db}
endif


default : 
	@echo 'Synopsis: make (' `perl -e 'print join( " | ", @ARGV );' $(TARGETS)` ')'

build-images :
	macrobuild UBOS::Macrobuild::BuildTasks::CreateAllImages_$(DEVICE) \
		--arch "$(ARCH)" \
		--repodir "$(REPODIR)" \
		--channel "$(CHANNEL)" \
		--imagesdir "$(IMAGESDIR)" \
		$(SIGREQUIREDINSTALL) \
		$(ADMINHASROOT) \
		$(VERBOSE)

run-webapptests : run-webapptests-workout run-webapptests-hl

run-webapptests-workout :
	macrobuild UBOS::Macrobuild::BuildTasks::RunWebAppTests \
		--configdir "$(CONFIGDIR)" \
		--builddir "$(BUILDDIR)" \
		--db tools \
		$(TESTSCAFFOLDARG)$(TESTVNCSECRETARG) \
		$(TESTVERBOSEARG) \
		$(TESTLOGSARG) \
		$(VERBOSE)

run-webapptests-hl :
	macrobuild UBOS::Macrobuild::BuildTasks::RunWebAppTests \
		--configdir "$(CONFIGDIR)" \
		--builddir "$(BUILDDIR)" \
		--db hl \
		$(TESTSCAFFOLDARG)$(TESTVNCSECRETARG) \
		$(TESTVERBOSEARG) \
		$(TESTLOGSARG) \
		$(VERBOSE)

burn-to-usb :
	[ -b "$(USBDEVICE)" ]
	sudo dd if=$(IMAGESDIR)/$(ARCH)/images/ubos_$(CHANNEL)_$(ARCH)_LATEST.img of=$(USBDEVICE) bs=1M
	sync

pacsane :
	( cd "$(REPODIR)/$(ARCH)"; \
		for repo in *; do \
			pacsane $$repo/$$repo.db.tar.xz; \
		done )

delete-all-vms-on-account :
	for vm in $(VBoxManage list vms | perl -p -e 's/^.*{(.*)}.*$/$1/'); do \
		VBoxManage controlvm $$vm poweroff > /dev/null 2>&1 || true;
		sleep 2; \
		VBoxManage unregistervm $$vm --delete > /dev/null 2>&1 || true; \
	done

# Check out code from git. Rebuild, and re-install, but only if there have been updates
# This is not a dependency so the user can decide whether they want to update the code
code-is-current :
	[ -d "$(WORKAREA)/git/github.com/indiebox" ] || mkdir -p "$(WORKAREA)/git/github.com/indiebox"
	( cd "$(WORKAREA)/git/github.com/indiebox"; \
		for p in ubos-admin macrobuild macrobuild-ubos perl tools; do \
			if [ -d "$$p" ]; then \
				( cd "$$p"; git pull | grep 'Already up-to-date' > /dev/null || rm -f *pkg* */*pkg* ); \
			else \
				git clone "https://github.com/indiebox/$$p"; \
			fi; \
		done )
	( cd "$(WORKAREA)/git/github.com/indiebox"; \
		for p in ubos-admin/ubos-perl-utils ubos-admin/ubos-keyring ubos-admin/ubos-admin perl/perl-log-journald macrobuild macrobuild-ubos tools/webapptest tools/pacsane; do \
			( cd "$$p"; ls -d *pkg* > /dev/null 2>&1 || ( env -i makepkg -c -f && sudo pacman -U --noconfirm *pkg* )) \
		done )


.PHONY : $(TARGETS) default
