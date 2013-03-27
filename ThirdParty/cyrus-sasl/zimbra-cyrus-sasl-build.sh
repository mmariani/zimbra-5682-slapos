#!/bin/bash -x

#
# Builds a saslauthd with Zimbra authentication support.  We modify
# configure.in which means we have to run autoconf.  I have borrowed
# the steps to run autoconf from the rpm spec.  The cyrus CVS tree's
# SMakefile is probably the source for the rpm spec.
#
BETA=$1

platform=`uname -s`
cyrus_root=`pwd`
p4_root=`cd ${cyrus_root}/../..; pwd`
build_platform=`sh ${p4_root}/ZimbraBuild/rpmconf/Build/get_plat_tag.sh`

if [ x$BETA = "xbeta" ]; then
  source ../beta_versions.sh
else
  source ../versions.sh
fi

cd ${cyrus_src}
rm config/ltconfig config/libtool.m4
if [ -x ${ZIMBRA_HOME}/libtool/bin/libtoolize ]; then
        LIBTOOLIZE=${ZIMBRA_HOME}/libtool/bin/libtoolize
else
        if [ -x /usr/bin/libtoolize ]; then
               LIBTOOLIZE=/usr/bin/libtoolize
        elif [ -x /opt/local/bin/glibtoolize ]; then
		export CPPFLAGS=-DDARWIN
		LIBTOOLIZE=/opt/local/bin/glibtoolize
	elif [ -x /usr/bin/glibtoolize ]; then
		export CPPFLAGS=-DDARWIN
		LIBTOOLIZE=/usr/bin/glibtoolize
	else
		echo "Where is libtoolize?"
		exit 1
	fi
fi
$LIBTOOLIZE -f -c
aclocal -I config -I cmulocal --system-acdir=${ZIMBRA_HOME}/libtool/share/aclocal
automake -a -c -f
autoheader
autoconf -f

cd saslauthd
rm config/ltconfig
$LIBTOOLIZE -f -c
aclocal -I config -I ../cmulocal -I ../config --system-acdir=${ZIMBRA_HOME}/libtool/share/aclocal
automake -a -c -f
autoheader
autoconf -f

cd ..
# fix linking against OpenSSL
#sed -i.obak -e 's|${with_openssl}/$CMU_LIB_SUBDIR|${with_openssl}/lib|' -e 's|${with_openssl}/lib $andrew_runpath_switch${with_openssl}/$CMU_LIB_SUBDIR|${with_openssl}/lib|' configure
#sed -i.obak -e 's|${with_openssl}/$CMU_LIB_SUBDIR|${with_openssl}/lib|' -e 's|${with_openssl}/lib $andrew_runpath_switch${with_openssl}/$CMU_LIB_SUBDIR|${with_openssl}/lib|' saslauthd/configure

sed -i.bak 's/-lRSAglue //' configure
if [ $platform = "Darwin" ]; then
LIBS="${ZIMBRA_HOME}/libxml2/lib/libxml2.a" CFLAGS="-D_REENTRANT -g -O2 -I${ZIMBRA_HOME}/libxml2/include/libxml2" ./configure --enable-zimbra --prefix=${ZIMBRA_HOME}/${cyrus_src} \
            --with-saslauthd=${ZIMBRA_HOME}/data/sasl2/state \
            --with-plugindir=${ZIMBRA_HOME}/${cyrus_src}/lib/sasl2 \
            --enable-static=no \
            --enable-shared \
            --with-dblib=no \
            --with-devrandom=/dev/urandom \
            --with-openssl=${ZIMBRA_HOME}/openssl-${openssl_version} \
            --with-libcurl=${ZIMBRA_HOME}/curl-${curl_version} \
            --with-gss_impl=heimdal \
            --enable-gssapi=${ZIMBRA_HOME}/heimdal-${heimdal_version} \
            --with-libxml2=${ZIMBRA_HOME}/libxml2-${xml2_version}/bin/xml2-config \
            --with-configdir=${ZIMBRA_HOME}/conf/sasl2 \
            --enable-login
else
	if [ $build_platform = "UBUNTU12_64" ]; then
                xmllib="${ZIMBRA_HOME}/libxml2/lib/libxml2.a -lz -lm"
	else
                xmllib="${ZIMBRA_HOME}/libxml2/lib/libxml2.a"
	fi
LIBS="${xmllib}" CFLAGS="-D_REENTRANT -g -O2 -I${ZIMBRA_HOME}/libxml2/include/libxml2" ./configure --enable-zimbra --prefix=${ZIMBRA_HOME}/${cyrus_src} \
            --with-saslauthd=${ZIMBRA_HOME}/data/sasl2/state \
            --with-plugindir=${ZIMBRA_HOME}/${cyrus_src}/lib/sasl2 \
            --with-dblib=no \
            --with-devrandom=/dev/urandom \
            --with-openssl=${ZIMBRA_HOME}/openssl-${openssl_version} \
            --with-libcurl=${ZIMBRA_HOME}/curl-${curl_version} \
            --with-gss_impl=heimdal \
            --enable-gssapi=${ZIMBRA_HOME}/heimdal-${heimdal_version} \
            --with-libxml2=${ZIMBRA_HOME}/libxml2-${xml2_version}/bin/xml2-config \
            --with-lib-subdir=lib \
            --with-configdir=${ZIMBRA_HOME}/conf/sasl2 \
            --enable-login
fi
if [ $platform = "Darwin" ]; then
     sed -i .bak -e 's/\_la_LDFLAGS)/_la_LDFLAGS) $(AM_LDFLAGS)/' plugins/Makefile
     sed -i .bak -e "s|-L${ZIMBRA_HOME}/libxml2-${xml2_version}/lib -lxml2||" saslauthd/Makefile
elif [ $build_platform = "F7" -o $build_platform -o "DEBIAN4.0" ]; then
     sed -i.bak -e 's/\_la_LDFLAGS)/_la_LDFLAGS) $(AM_LDFLAGS)/' plugins/Makefile
fi
LD_RUN_PATH="${openssl_lib_dir}:${heimdal_lib_dir}:${cyrus_lib_dir}:${curl_lib_dir}" make
