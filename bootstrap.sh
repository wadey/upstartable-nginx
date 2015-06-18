#!/bin/sh

VERSION="1.7.10"
BUILD="betable5"

set -e -x

DIRNAME="$(cd "$(dirname "$0")" && pwd)"
OLDESTPWD="$PWD"

cd "$(mktemp -d)"
trap "rm -rf \"$PWD\"" EXIT INT QUIT TERM

curl -O "http://nginx.org/download/nginx-$VERSION.tar.gz"
/bin/tar xf "nginx-$VERSION.tar.gz"
cd "nginx-$VERSION"

git clone -b"v0.25" "git@github.com:agentzh/headers-more-nginx-module"
git clone -b"v0.9.1" "git@github.com:masterzen/nginx-upload-progress-module"
git clone -b"a18b409" "git@github.com:gnosek/nginx-upstream-fair"
git clone -b"b756a12" "git@github.com:zebrafishlabs/nginx-statsd.git"

patch -p1 < "$DIRNAME/patches/syslog-tag-allow-dashes.patch"
patch -p1 < "$DIRNAME/patches/syslog-tag-length.patch"

./configure \
    --add-module="headers-more-nginx-module" \
    --add-module="nginx-upload-progress-module" \
    --add-module="nginx-upstream-fair" \
    --add-module="nginx-statsd" \
    --conf-path="/etc/nginx/nginx.conf" \
    --error-log-path="/var/log/nginx/error.log" \
    --group="www-data" \
    --http-client-body-temp-path="/var/lib/nginx/body" \
    --http-fastcgi-temp-path="/var/lib/nginx/fastcgi" \
    --http-log-path="/var/log/nginx/access.log" \
    --http-proxy-temp-path="/var/lib/nginx/proxy" \
    --lock-path="/var/lock/nginx.lock" \
    --pid-path="/var/run/nginx.pid" \
    --prefix="/etc/nginx" \
    --sbin-path="/usr/sbin/nginx" \
    --user="www-data" \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-md5="/usr/include/openssl" \
    --without-http_scgi_module \
    --without-http_uwsgi_module \
    --with-sha1="/usr/include/openssl"

make
mkdir "rootfs"
make install DESTDIR="$PWD/rootfs"

rm -rf \
    "rootfs/etc/nginx/fastcgi.conf" \
    "rootfs/etc/nginx/html" \
    "rootfs/etc/nginx/scgi_params" \
    "rootfs/etc/nginx/uwsgi_params"
find "rootfs/etc/nginx" -name "*.default" -delete

find "$DIRNAME" -not -name "patches" -type "d" -printf "%P\n" |
xargs -I"__" mkdir -p "rootfs/__"

find "$DIRNAME" -not -path "*/patches/*" -not -name "bootstrap.sh" -not -name "README.md" -type "f" -printf "%P\n" |
xargs -I"__" cp "$DIRNAME/__" "rootfs/__"

fakeroot fpm -C "rootfs" \
             -d "inotify-tools" -d "netcat" -d "procps" \
             -m "Nate Brown <nate@betable.com>" \
             -n "nginx" -v "$VERSION-$BUILD" \
             -p "$OLDESTPWD/nginx_${VERSION}-${BUILD}_amd64.deb" \
             --replaces "nginx-common" --replaces "nginx-extras" \
             -s "dir" -t "deb" \
             "etc" "usr"
