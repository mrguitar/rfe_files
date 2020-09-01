#!/bin/bash
#A simple script that can create the initial rpm-ostree compose on an 8.3+ system running Image Builder 
#This will produce a tar archive creating the rpm-ostree commit that will need to be copied to a web property and expanded.

#create a default blueprint and add crun because it's awesome
cat >edge_node.toml << EOF
name = "EdgeNode"
description = "edge_node_build"
version = "0.0.1"
modules = []
groups = []

[[packages]]
name = "crun"
version = "*"
EOF

#add the blueprint to Image Builder
composer-cli blueprints push edge_node.toml

#create the initial rpm-ostree commit using the new blueprint and default ref 
composer-cli compose start-ostree --ref rhel/8/x86_64/edge EdgeNode rhel-edge-commit

#To generate updates for this deployment include the --parent ref that can be found under repo/refs/heads/rhel/8/x86_64/edge
#composer-cli compose start-ostree --parent b15021e03236ecddb82b6bdb545f09a48cb79cb7627c589c7b01dafadde26cc2 --ref rhel/8/x86_64/edge EdgeNode rhel-edge-commit


#The composer UUID will now have a status of RUNNING. Assuming only a single build is being created this will locate the correct UUID
COMPOSER_UUID=$(composer-cli compose status |grep RUNNING | awk '{ print $1}')

#guestimate - wait for the build to complete
sleep 10m

#This will pull the tar file from the server
composer-cli compose image $COMPOSER_UUID

#scp the *-commit.tar file to the desired web property to serve.
