#
# Include for all the Makefiles
#

SHELL=/bin/bash

default : 
	@echo 'Synopsis: make (' `perl -e 'print join( " | ", @ARGV );' $(TARGETS)` ')'
	@echo 'Workarea is' $(WORKAREA)

WORKAREA?=.
TESTVNCSECRET?=
TESTSCAFFOLD?=$(TESTSCAFFOLD_CONTAINER)
TESTVERBOSE?=-v
DEVICE?=pc
REQUIRED_PACKAGES=\
	arch-install-scripts \
	awk \
	binutils \
	dosfstools \
	file \
	findutils \
	gcc \
	gettext \
	git \
	grep \
	groff \
	gzip \
	jdk8-openjdk \
	libltdl \
	macrobuild \
	macrobuild-ubos \
	make \
	maven \
	multipath-tools \
	pacman \
	pacsane \
	perl-http-date \
	perl-log-journald \
	perl-www-curl \
	php \
	pkg-config \
	python2-setuptools \
	python2-virtualenv \
	rsync \
	sudo \
	texinfo \
	ubos-install \
	ubos-keyring \
	ubos-perl-utils \
	util-linux \
	virtualbox \
	webapptest \
	which

CONFIGDIR=config
GNUPGHOME=${HOME}/.gnupg
SHEPHERDSSHKEYDIR=${CURDIR}/shepherd-keys/ssh
#IMPERSONATEDEPOT?=
# IMPERSONATEDEPOT=:impersonatedepot=192.168.56.1
# (address of the host on the VirtualBox hostonly network)
USBDEVICE=/dev/sde

ARCH!=uname -m | sed -e 's/\(armv[67]\)l/\1h/'
    #replace armv6l with armv6h, armv7l with armv7h
ARCHUPSTREAMSITE_x86_64=http://mirror.us.leaseweb.net/archlinux
ARCHUPSTREAMSITE_arm=http://ca.us.mirror.archlinuxarm.org
UPLOADDEST?=
UPLOADSSHKEY?=
PACKAGESIGNKEY?=
DBSIGNKEY?=
SIGREQUIREDINSTALL?=--checkSignatures optional
# signing during install 

BUILDDIR=$(WORKAREA)/build
TESTLOGSDIR=$(WORKAREA)
REPODIR=$(WORKAREA)/repository/$(CHANNEL)

ifdef TESTVNCSECRET
    TESTVNCSECRETARG=:vncsecret=$(TESTVNCSECRET)
endif

TESTPLANSARG=--testplan default --testplan well-known --testplan redeploy 

TESTSCAFFOLD_HERE=here$(IMPERSONATEDEPOT)
TESTSCAFFOLD_VBOX=v-box:vmdktemplate=$(REPODIR)/$(ARCH)/uncompressed-images/ubos_$(CHANNEL)_vbox-pc_LATEST.vmdk:shepherd-public-key-file=$(SHEPHERDSSHKEYDIR)/id_rsa.pub:shepherd-private-key-file=$(SHEPHERDSSHKEYDIR)/id_rsa$(IMPERSONATEDEPOT)$(TESTVNCSECRETARG)
TESTSCAFFOLD_CONTAINER=container:directory=$(REPODIR)/$(ARCH)/uncompressed-images/ubos_$(CHANNEL)_container-pc_LATEST:shepherd-public-key-file=$(SHEPHERDSSHKEYDIR)/id_rsa.pub:shepherd-private-key-file=$(SHEPHERDSSHKEYDIR)/id_rsa$(IMPERSONATEDEPOT)


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

ifdef UPLOADDEST
ifdef UPLOADSSHKEY
upload :
	macrobuild UBOS::Macrobuild::BuildTasks::UploadChannel \
		--arch "$(ARCH)" \
		--repodir "$(REPODIR)" \
		--channel "$(CHANNEL)" \
		--uploadDest "$(UPLOADDEST)" \
		--uploadSshKey "$(UPLOADSSHKEY)" \
		$(VERBOSE)
else
upload :
	$(error Cannot upload without an UPLOADSSHKEY. Make sure it matches what the depot expects)
endif
else
upload :
	$(error Cannot upload without an UPLOADDEST)
endif

purge :
	macrobuild UBOS::Macrobuild::BuildTasks::PurgeChannel \
		--repodir "$(REPODIR)" \
		--arch "$(ARCH)" \
		--channel "$(CHANNEL)" \
		$(VERBOSE)
	
run-webapptests : run-webapptests-workout run-webapptests-hl

run-webapptests-workout : have-shepherd-ssh-keys
	macrobuild UBOS::Macrobuild::BuildTasks::RunWebAppTests \
		--arch "$(ARCH)" \
		--configdir "$(CONFIGDIR)" \
		--builddir "$(BUILDDIR)" \
		--db tools \
		$(TESTPLANSARG) \
		$(TESTSCAFFOLDARG) \
		$(TESTVERBOSEARG) \
		$(TESTLOGSARG) \
		$(VERBOSE)

run-webapptests-hl : have-shepherd-ssh-keys
	macrobuild UBOS::Macrobuild::BuildTasks::RunWebAppTests \
		--arch "$(ARCH)" \
		--configdir "$(CONFIGDIR)" \
		--builddir "$(BUILDDIR)" \
		--db hl \
		$(TESTPLANSARG) \
		$(TESTSCAFFOLDARG) \
		$(TESTVERBOSEARG) \
		$(TESTLOGSARG) \
		$(VERBOSE)

burn-to-usb :
	[ -b "$(USBDEVICE)" ]
	if mount | grep $(USBDEVICE) > /dev/null ; then echo ERROR: USBDEVICE $(USBDEVICE) is mounted and cannot be used to burn to; false;  fi
	sudo dd if=`ls -1 $(REPODIR)/$(ARCH)/uncompressed-images/ubos_*_$(DEVICE)*_LATEST.img` of=$(USBDEVICE) bs=1M
	sync

pacsane :
	( cd "$(REPODIR)/$(ARCH)"; \
		for repo in *; do \
			if [ -r "$$repo/$$repo.db.tar.xz" ]; then \
				pacsane $$repo/$$repo.db.tar.xz; \
			fi \
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
	sudo pacman -S $(REQUIRED_PACKAGES)

ifdef SHEPHERDSSHKEYDIR
have-shepherd-ssh-keys :
	if [ ! -d "$(SHEPHERDSSHKEYDIR)" ]; then mkdir -p $(SHEPHERDSSHKEYDIR); fi
	if [ ! -e "$(SHEPHERDSSHKEYDIR)/id_rsa" ]; then \
		echo Generating SSH keys in $(SHEPHERDSSHKEYDIR) to ssh into containers/vms under test as shepherd; \
		ssh-keygen -f "$(SHEPHERDSSHKEYDIR)/id_rsa" -P '' > /dev/null; \
	fi

else
have-shepherd-ssh-keys :

endif


.PHONY : $(TARGETS) default
