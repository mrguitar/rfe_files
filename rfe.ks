lang en_US.UTF-8
keyboard us
timezone UTC --isUtc --ntpservers=rhel.pool.ntp.org
reboot
#work around for https://bugzilla.redhat.com/show_bug.cgi?id=1861456
text

#wipe existing drives
zerombr
clearpart --all --initlabel

#uncomment for a simple setup 
#autopart --type=plain --fstype=xfs --nohome

#this will create a fixed / and use the majority of the disk for /var
part /boot/efi --fstype=vfat --size=600
part /boot --fstype=xfs --size=1000
part swap --recommended 
part / --fstype=xfs --size 30000 --encrypted --passphrase=temppass
part /var --fstype=xfs --grow --encrypted --passphrase=temppass

network --bootproto=dhcp

#placeholder passwords are "redhat"
rootpw --iscrypted $6$3OrUXJfD.64WiZl2$4/oBFyFgIyPI6LdLCbE.h99YBrFa..pC3x3WlHNH8mUf4ssZmhlhy17CHc0n3kAvHvWecpqunVOd/4kOGB7Ms.

#work around for https://bugzilla.redhat.com/show_bug.cgi?id=1848453
services --enable=ostree-remount

#placeholder passwords are "redhat"
user --name=core --groups=wheel --iscrypted --password=$6$3OrUXJfD.64WiZl2$4/oBFyFgIyPI6LdLCbE.h99YBrFa..pC3x3WlHNH8mUf4ssZmhlhy17CHc0n3kAvHvWecpqunVOd/4kOGB7Ms.
#sshkey --username=core "ssh-rsa AAA......."

#Ensure the tar from Image Builder is served on an accessible web endpoint listed here:
ostreesetup --nogpg --osname=rhel-edge --remote=rhel-edge --url=http://192.168.81.20/repo/ --ref=rhel/8/x86_64/edge


%post

#stage updates as they become available
echo AutomaticUpdatePolicy=stage >> /etc/rpm-ostreed.conf
systemctl enable rpm-ostreed-automatic.timer

#configure clevis to unlock the luks volumes using the TPM2. Adjust /dev/vda appropriotely. 
clevis luks bind -f -k- -d /dev/vda2 tpm2 '{}' \ <<<"temppass"
clevis luks bind -f -k- -d /dev/vda6 tpm2 '{}' \ <<<"temppass"

#Optional to wipe the key and only use the TPM2. 
#cryptsetup luksRemoveKey /dev/vda2 <<< "temppass"

%end

%post
cat > /etc/systemd/system/applyupdate.service << EOF
[Unit]
Description=Apply Update Check

[Service]
Type=simple
ExecStart=/usr/local/sbin/applyupdatecheck.sh
EOF 

cat > /etc/systemd/system/applyupdate.timer << EOF
[Unit]
Description=Daily Update Reboot Check.

[Timer]
OnCalendar=*-*-* 01:30:00
#OnCalendar=Sun *-*-* 00:00:00

[Install]
WantedBy=multi-user.target
EOF

cat > /usr/local/sbin/applyupdatecheck.sh << EOF
#!/bin/bash

if [[ $(rpm-ostree status -v | grep "Staged: yes") ]]; then
   systemctl --message="Applying OTA update" reboot
else
   echo "Latest available update already applied"
fi
EOF

systemctl daemon-reload
systemctl enable applyupdate.timer
%end
