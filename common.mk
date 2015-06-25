#
# Include for all the Makefiles
#

SHELL=/bin/bash

default : 
	@echo 'Synopsis: make (' `perl -e 'print join( " | ", @ARGV );' $(TARGETS)` ')'
	@echo 'Workarea is' $(WORKAREA)

WORKAREA?=.
TESTVNCSECRET=
TESTSCAFFOLD=$(TESTSCAFFOLD_HERE)
TESTVERBOSE=-v
DEVICE=pc

CONFIGDIR=config
GNUPGHOME=${HOME}/.gnupg
SSHDIR=keys/ubos/ubos-admin/ssh
IMPERSONATEDEPOT=
# IMPERSONATEDEPOT=:impersonatedepot=192.168.56.1
# (address of the host on the VirtualBox hostonly network)
USBDEVICE=/dev/sde

ARCH!=uname -m | sed -e 's/\(armv[67]\)l/\1h/'
    #replace armv6l with armv6h, armv7l with armv7h
ARCHUPSTREAMSITE_x86_64=http://mirror.us.leaseweb.net/archlinux
ARCHUPSTREAMSITE_arm=http://ca.us.mirror.archlinuxarm.org
UPLOADDEST=
UPLOADSSHKEY=
PACKAGESIGNKEY=
DBSIGNKEY=
SIGREQUIREDINSTALL=--checkSignatures optional
# signing during install 

BUILDDIR=$(WORKAREA)/build
TESTLOGSDIR=$(WORKAREA)

TESTPLANSARG=--testplan default --testplan well-known --testplan redeploy 

TESTSCAFFOLD_HERE=here$(IMPERSONATEDEPOT)
TESTSCAFFOLD_VBOX=v-box:vmdktemplate=$(REPODIR)/$(ARCH)/images/ubos_$(CHANNEL)_vbox-pc_x86_64_LATEST.vmdk:shepherd-public-key-file=$(SSHDIR)/id_rsa.pub:shepherd-private-key-file=$(SSHDIR)/id_rsa$(IMPERSONATEDEPOT)
 
DEPOTAPPCONFIGID!=sudo ubos-admin showappconfig --brief --host depot.ubos.net --context /$(CHANNEL) 2>/dev/null

ifdef DEPOTAPPCONFIGID
    REPODIR=/var/lib/ubos-repo/$(DEPOTAPPCONFIGID)
else
    REPODIR=$(WORKAREA)/repository/$(CHANNEL)
endif

ifdef PACKAGESIGNKEY
    SIGNPACKAGESARG=--packageSignKey $(PACKAGESIGNKEY)

check-sign-packages-setup :
	GNUPGHOME=$(GNUPGHOME) gpg --list-secret-keys $(PACKAGESIGNKEY) > /dev/null

else
check-sign-packages-setup :

endif

ifdef DBSIGNKEY
    SIGNDBSARG=--dbSignKey $(DBSIGNKEY)

check-sign-dbs-setup :
	GNUPGHOME=$(GNUPGHOME) gpg --list-secret-keys $(DBSIGNKEY) > /dev/null

else
check-sign-dbs-setup :

endif

ifdef IMAGESIGNKEY
    SIGNIMAGESSARG=--imageSignKey $(IMAGESIGNKEY)

check-sign-images-setup :
	GNUPGHOME=$(GNUPGHOME) gpg --list-secret-keys $(IMAGESIGNKEY) > /dev/null

else
check-sign-images-setup :

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


build-images :
	for d in `echo $(DEVICE) | sed -e 's/,/ /g'`; do \
		macrobuild UBOS::Macrobuild::BuildTasks::CreateAllImages_$${d} \
			--arch "$(ARCH)" \
			--repodir "$(REPODIR)" \
			--channel "$(CHANNEL)" \
			$(SIGNIMAGESARG) \
			$(SIGREQUIREDINSTALL) \
			$(VERBOSE); \
	done

# This is a separate task, because it can take a long time
compress-images :
	macrobuild UBOS::Macrobuild::BuildTasks::CompressImages \
		--arch "$(ARCH)" \
		--repodir "$(REPODIR)" \
		--channel "$(CHANNEL)" \
		$(VERBOSE)

purge :
	macrobuild UBOS::Macrobuild::BuildTasks::PurgeChannel \
		--repodir "$(REPODIR)" \
		--arch "$(ARCH)" \
		--channel "$(CHANNEL)" \
		$(VERBOSE)
	
run-webapptests : run-webapptests-workout run-webapptests-hl

run-webapptests-workout :
	macrobuild UBOS::Macrobuild::BuildTasks::RunWebAppTests \
		--arch "$(ARCH)" \
		--configdir "$(CONFIGDIR)" \
		--builddir "$(BUILDDIR)" \
		--db tools \
		$(TESTPLANSARG) \
		$(TESTSCAFFOLDARG)$(TESTVNCSECRETARG) \
		$(TESTVERBOSEARG) \
		$(TESTLOGSARG) \
		$(VERBOSE)

run-webapptests-hl :
	macrobuild UBOS::Macrobuild::BuildTasks::RunWebAppTests \
		--arch "$(ARCH)" \
		--configdir "$(CONFIGDIR)" \
		--builddir "$(BUILDDIR)" \
		--db hl \
		$(TESTPLANSARG) \
		$(TESTSCAFFOLDARG)$(TESTVNCSECRETARG) \
		$(TESTVERBOSEARG) \
		$(TESTLOGSARG) \
		$(VERBOSE)

burn-to-usb :
	[ -b "$(USBDEVICE)" ]
	if mount | grep $(USBDEVICE) > /dev/null ; then echo ERROR: USBDEVICE $(USBDEVICE) is mounted and cannot be used to burn to; false;  fi
	sudo dd if=`ls -1 $(REPODIR)/$(ARCH)/images/ubos_*_$(DEVICE)*_LATEST.img` of=$(USBDEVICE) bs=1M
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
	echo sudo pacman -S arch-install-scripts base-devel dosfstools git jdk8-openjdk maven multipath-tools perl-http-date perl-www-curl php python2-setuptools rsync
	[ -d "$(WORKAREA)/git/github.com/uboslinux" ] || mkdir -p "$(WORKAREA)/git/github.com/uboslinux"
	( cd "$(WORKAREA)/git/github.com/uboslinux"; \
		for p in ubos-admin macrobuild macrobuild-ubos ubos-perl ubos-tools; do \
			if [ -d "$$p" ]; then \
				( cd "$$p"; git pull | grep 'Already up-to-date' > /dev/null || rm -f *pkg* */*pkg* ); \
			else \
				git clone "https://github.com/uboslinux/$$p"; \
			fi; \
		done )
	( cd "$(WORKAREA)/git/github.com/uboslinux"; \
		for p in ubos-admin/ubos-perl-utils ubos-admin/ubos-keyring ubos-admin/ubos-admin ubos-admin/ubos-install ubos-perl/perl-log-journald macrobuild macrobuild-ubos ubos-tools/webapptest ubos-tools/pacsane; do \
			( cd "$$p"; ls -d *pkg* > /dev/null 2>&1 || ( env -i makepkg -c -f && sudo pacman -U --noconfirm *pkg* )) \
		done )


.PHONY : $(TARGETS) default
