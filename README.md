# pkgng-repository

[![License](https://img.shields.io/github/license/uchida/packer-freebsd.svg)](http://creativecommons.org/publicdomain/zero/1.0/deed)

This repository manages custom FreeBSD package repository hosted by S3, building packages with [uchida/poudriere](https://atlas.hashicorp.com/uchida/boxes/poudriere) vagrant box.

## Create S3 bucket and IAM key

Create S3 bucket with [terraform](terraform.io)

```console
$ pushd bucket
$ edit variables.tf
$ terraform plan
$ terraform apply
$ popd
```

and then, generate environment variables settings to access S3 bucket with [jq](https://stedolan.github.io/jq/)

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
$ openssl rsa -in poudriere/poudriere.key pubout -out poudriere/poudriere.cert
$ chmod 0444 poudriere/poudriere.key
```

## Building and distribiting packages

With `vagrant provision`, start building packages and S3 sync, requires [vagrant](https://www.vagrantup.com/).

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

For detail about `poudriere options` command, consult `man 8 poudriere`.

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