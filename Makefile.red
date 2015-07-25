#
# Makefile for the red channel
#

VERBOSE=-v
# VERBOSE=-v -v -i
CHANNEL=red
FROMCHANNEL=dev

-include local.mk
include common.mk

FROMDEPOTAPPCONFIGID!=sudo ubos-admin showappconfig --brief --host depot.ubos.net --context /$(FROMCHANNEL) 2>/dev/null

ifdef FROMDEPOTAPPCONFIGID
	FROMREPODIR=/var/lib/ubos-repo/$(FROMDEPOTAPPCONFIGID)
else
	FROMREPODIR=$(WORKAREA)/repository/$(FROMCHANNEL)
endif


## Public targets

TARGETS=\
    promote-from-dev \
	build-images \
	burn-to-usb \
	code-is-current \
	compress-images \
	delete-all-vms-on-account \
	have-shepherd-ssh-keys \
	upload \
	pacsane \
	purge \
	run-webapptests \
	run-webapptests-hl \
	run-webapptests-workout

promote-from-dev : check-sign-dbs-setup
	macrobuild UBOS::Macrobuild::BuildTasks::PromoteChannel \
		--configdir "$(CONFIGDIR)" \
		--archUpstreamDir "$(ARCHUPSTREAMDIR)" \
		--arch "$(ARCH)" \
		--fromRepodir "$(FROMREPODIR)" \
		--fromChannel "$(FROMCHANNEL)" \
		--toRepodir "$(REPODIR)" \
		--toChannel "$(CHANNEL)" \
		$(SIGNDBSARG) \
		$(VERBOSE)

