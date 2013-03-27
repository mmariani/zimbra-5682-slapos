PHP_ROOT := $(shell pwd)
P4_ROOT ?= $(shell cd $(PHP_ROOT)/../..; pwd)
MAKE ?= make
MAKEARGS ?= -j2

BUILD_PLATFORM ?= $(shell sh $(P4_ROOT)/ZimbraBuild/rpmconf/Build/get_plat_tag.sh)

ifeq ($(BUILD_PLATFORM), )
	BUILD_PLATFORM := "UNKNOWN"
endif

PATCH	:=
ifdef BETA
	include $(PHP_ROOT)/../beta_versions.def
	PATCH	:= 
else
	include $(PHP_ROOT)/../versions.def
	PATCH	:= 
endif

SED := sed -i .bak -e 's|-lxml2|$(ZIMBRA_HOME)/libxml2-$(XML_VERSION)/lib/libxml2.a|g' Makefile

PHP_TGZ_TARGET := \
	$(P4_ROOT)/ThirdPartyBuilds/$(BUILD_PLATFORM)/php/php-$(PHP_VERSION).tgz

files	:= $(wildcard src/php-$(PHP_VERSION).tar.bz2)

all: checksrc allclean build tar

checksrc:
	$(if $(files), @echo "", exit 1)

build:
	tar xfj src/php-$(PHP_VERSION).tar.bz2
	(cd php-$(PHP_VERSION); \
	$(PATCH) $(ACEXE) CFLAGS="-g -O2" \
	./configure --prefix=$(ZIMBRA_HOME)/php-$(PHP_VERSION) --with-apxs2=$(ZIMBRA_HOME)/httpd-$(HTTPD_VERSION)/bin/apxs --with-config-file-path=$(ZIMBRA_HOME)/conf --with-pspell=$(ZIMBRA_HOME)/aspell-$(ASPELL_VERSION) --with-libxml-dir=$(ZIMBRA_HOME)/libxml2-$(XML_VERSION); \
	$(SED); \
	$(MAKE) $(MAKEARGS); \
	$(MAKE) install)

clean:
	rm -rf php-$(PHP_VERSION)

allclean: clean
	rm -rf $(ZIMBRA_HOME)/php-$(PHP_VERSION)
	rm -f $(PHP_TGZ_TARGET)

tar: $(P4_ROOT)/ThirdPartyBuilds/$(BUILD_PLATFORM)/php
	(cd $(ZIMBRA_HOME); tar czf \
	$(PHP_TGZ_TARGET) \
	php-$(PHP_VERSION))
	chmod -R a+w $(PHP_TGZ_TARGET)

$(P4_ROOT)/ThirdPartyBuilds/$(BUILD_PLATFORM)/php:
	mkdir -p $@

p4edit: $(PHP_TGZ_TARGET)
	p4 add $(PHP_TGZ_TARGET)
	p4 edit $(PHP_TGZ_TARGET)
