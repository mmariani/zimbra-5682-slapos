cyrus_release=2.1.26
cyrus_patchlevel=2z
cyrus_version=${cyrus_release}.${cyrus_patchlevel}
cyrus_src=cyrus-sasl-${cyrus_version}

heimdal_version=1.5.2
openssl_version=1.0.1e
curl_version=7.29.0
xml2_version=2.7.8

openssl_lib_dir=${ZIMBRA_HOME}/openssl-${openssl_version}/lib
heimdal_lib_dir=${ZIMBRA_HOME}/heimdal-${heimdal_version}/lib
cyrus_lib_dir=${ZIMBRA_HOME}/cyrus-sasl-${cyrus_version}/lib
curl_lib_dir=${ZIMBRA_HOME}/curl-${curl_version}/lib
