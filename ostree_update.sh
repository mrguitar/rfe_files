#!/bin/bash
#A simple script to extract and merge an rpm-ostree commit from Image Builder with an existing ostree repo


UPDATEPATH=/var/www/html/ostree/update
REPOPATH=/var/www/html/ostree/repo

tar -xf $UPDATEPATH/*-commit.tar -C $UPDATEPATH
ostree pull-local $UPDATEPATH/repo --repo $REPOPATH
ostree static-delta generate --repo $REPOPATH rhel/8/x86_64/edge
ostree summary -u --repo $REPOPATH

