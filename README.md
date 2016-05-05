# pkgng-repository

[![CircleCI](https://img.shields.io/circleci/project/uchida/pkgng-repository.svg?maxAge=2592000)](https://circleci.com/gh/uchida/pkgng-repository)
[![License](https://img.shields.io/github/license/uchida/pkgng-repository.svg?maxAge=2592000)](https://tldrlegal.com/license/creative-commons-cc0-1.0-universal)

This repository manages custom FreeBSD package repository hosted by S3, building packages with [uchida/poudriere](https://atlas.hashicorp.com/uchida/boxes/poudriere) vagrant box.

## Create S3 bucket and IAM key

Create S3 bucket with [terraform](terraform.io)

prepare environment variables,
note: [direnv](https://github.com/direnv/direnv) may be usefull to separate secret environment variables from repository.

```console
$ export AWS_ACCESS_KEY_ID={{ your AWS access key here }}
$ export AWS_SECRET_ACCESS_KEY={{ your AWS secret access key here }}
$ export AWS_DEFAULT_REGION={{ AWS region where you to }}
$ export TF_VAR_bucket_name={{ bucket name to put your packages }}
```

plan and apply

```console
$ pushd bucket
$ terraform plan
$ terraform apply
$ popd
```

and then, generate environment variables settings to access S3 bucket with [jq](https://stedolan.github.io/jq/) for Vagrant provision.

```console
$ cat <<__EOF__ > credential
export BUCKET=$(jq -r '.modules[].resources | .["aws_s3_bucket.main"].primary.id' bucket/terraform.tfstate)
export AWS_DEFAULT_REGION=$(jq -r '.modules[].resources | .["aws_s3_bucket.main"].primary.attributes.region' bucket/terraform.tfstate)
export AWS_ACCESS_KEY_ID=$(jq -r '.modules[].resources | .["aws_iam_access_key.main"].primary.attributes.id' bucket/terraform.tfstate)
export AWS_SECRET_ACCESS_KEY=$(jq -r '.modules[].resources | .["aws_iam_access_key.main"].primary.attributes.secret' bucket/terraform.tfstate)
__EOF__
$ chmod 0600 credential
```

## Generating packaging sign key

generate poudriere sign private and public key with `openssl`

```console
$ openssl genrsa -out poudriere/poudriere.key 4096
$ chmod 0400 poudriere/poudriere.key
$ openssl rsa -in poudriere/poudriere.key -pubout -out poudriere/poudriere.cert
$ chmod 0444 poudriere/poudriere.key
```

## Building and distribiting packages

With `vagrant provision`, start building packages and S3 sync, requires [vagrant](https://www.vagrantup.com/) and rsync to sync folder for vagrant.

```console
$ vagrant up --no-provision
$ vagrant provision
```

After vagrant provision, packages are published.

sample client configuration:

1. put `poudriere/poudriere.cert` in `/usr/local/etc/ssl/certs/`.
2. edit `/usr/local/etc/pkg/repos/poudriere.conf`

  ```
  poudriere: {
    url: http://{{ your bucket endpoint here }}/packages/${ABI},
    mirror_type: http,
    signature_type: pubkey
    pubkey: /usr/local/etc/ssl/keys/poudriere.cert
    enabled: yes
  }
  ```

## Customizing build options

You could set ports option in advance, in vagrant box

```console
$ sudo poudriere options category/portname
```

options file are generated in `/usr/local/etc/poudriere.d/options` in box, copy them on `poudriere/options` in this repository:

```console
$ sudo cp /usr/local/etc/poudriere.d/options/* /vagrant/poudriere/options/
```

now vagrant provision copy them on provision and build with these options.

For detail about `poudriere` command and subcommands such as `poudriere options`,
consult [`man 8 poudriere`](https://www.freebsd.org/cgi/man.cgi?query=poudriere&apropos=0&sektion=8&manpath=FreeBSD+10.2-RELEASE+and+Ports&arch=default&format=html) or
[poudriere documents](https://github.com/freebsd/poudriere/wiki).

## Building custom ports

This section describe building custom ports using portshaker.
For example, to build additional ports in [haskell ports](https://github.com/freebsd-haskell/ports).

1. put `poudriere/portshaker-config/freebsd_haskell` file
  ```sh
  #!/bin/sh

  . /usr/local/share/portshaker/portshaker.subr

  method="git"
  git_clone_uri="https://github.com/freebsd-haskell/ports.git"

  run_portshaker_command $*
  ```
2. edit `custom_merge_from` line in `poudriere/portshaker.conf`:

  ```sh
  custom_merge_from="freebsd_ports freebsd_haskel"
  ```
3. add ports in haskell ports to `poudriere/packages.list`.
4. edit `ports` line in `provision.sh`:

  ```sh
  ports=custom
  ```

Vagrant provision now builds build haskell ports in `poudriere/packages.list`. you could even freeze or replace default ports tree with portshaker mechanism.

## License
[![CC0](http://i.creativecommons.org/p/zero/1.0/88x31.png)]([http://creativecommons.org/publicdomain/zero/1.0/deed](http://creativecommons.org/publicdomain/zero/1.0/deed))

dedicated to public domain by [contributors](https://github.com/uchida/pkgng-repository/graphs/contributors).
