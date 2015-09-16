#!/bin/sh
set -ex

jail=FreeBSD:10:amd64
ports=default
s3opt='--follow-symlinks --acl public-read --storage-class REDUCED_REDUNDANCY'

pkg install -y rsync

mkdir -p /usr/local/etc/ssl/keys
chmod 0600 /usr/local/etc/ssl/keys
cp -f /vagrant/poudriere/poudriere.key /usr/local/etc/ssl/keys/poudriere.key
chmod 0400 /usr/local/etc/ssl/keys/poudriere.key

cp -f /vagrant/poudriere/poudriere.conf /usr/local/etc/poudriere.conf

cp -f /vagrant/poudriere/make.conf /usr/local/etc/poudriere.d/make.conf
rsync -a --delete /vagrant/poudriere/options/ /usr/local/etc/poudriere.d/options

if [ "${ports}" = "default" ]; then
  poudriere ports -u
else
  pkg install -y portshaker portshaker-config git
  rsync -a /vagrant/poudriere/portshaker-config/ /usr/local/etc/portshaker.d/
  find /usr/local/etc/portshaker.d -type f -print0 -exec chmod +x {} +
  cp -f /vagrant/poudriere/portshaker.conf /usr/local/etc/portshaker.conf
  if ! zfs list -H -o mountpoint /var/cache/portshaker; then
    zfs create -o mountpoint=/var/cache/portshaker zroot/portshaker
  fi
  portshaker
fi

poudriere bulk -j "${jail}" -p "${ports}" -f /vagrant/poudriere/packages.list || :

pkg install -y py27-pip
pip install awscli
. /vagrant/credential

aws s3 sync ${s3opt} /usr/local/share/poudriere/html/ "s3://${BUCKET}"
find /usr/local/poudriere/data/logs/bulk -type d | xargs -I% /vagrant/poudriere/gendoc.sh %
aws s3 sync ${s3opt} /usr/local/poudriere/data/logs/bulk/ "s3://${BUCKET}/data"

aws s3 sync ${s3opt} "/usr/local/poudriere/data/packages/${jail}-${ports}/.latest/" "s3://${BUCKET}/packages/${jail}"
