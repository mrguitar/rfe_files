# RFE == RHEL for Edge

This is a demo/example similar to gicmo's work [here.](https://github.com/gicmo/rfe-demo) The repo includes some rudimentary scripts that will yeild a RHEL node that's ideal for a large scale edge environment. When nodes are deployed in numbers ranging from 10s of thousands into the millions, we need to think differently about how we interact with the fleet. The example kickstart includes a few recommended settings and configs that can be built upon and adapted for other use cases. The content of this repo will need to be altered for your environment and is not intended to be used as is.

Everything shown here can be further enhanced using tools like Ansible. 

### Content
#### imagebuilder.sh
A simple example to demonstrate Image Builder's CLI and how to create an rpm-ostree image.
#### ostreeupdate.sh
A simple script to demonstrate how to extract and merge updates. The initial tar archive from Image Builder only requires extracting the contents on a web property. Subsequent updates require a few other commands to add commints in the same repo.

#### rfe.ks 
A basic kickstart that will deploy RFE and include the following feature/functionality

##### Applications are deployed as containers and managed independatly of the OS
RHEL for Edge is intended to be a stand-alone container host. With systems deployed outside of traditional infrastructure it's incredibly important to keep systems patched while also minimizing potential disruptions to applications. Containers are an ideal vehicle to help ensure that "patch Tuesday" problems do not cause  disruptions.

##### The OS & updates are created via Image Builder
All container OSs eventually run into the challenge of what *Linux* content belongs on the underlying operating system vs being deployed in a container. We encourage **no software** to be added to RHEL for Edge, but we also recognize that there are legitamate use cases where this is required. Image Builder's blueprints allow custom content to be added is a safe & repeatable way. As Image Builder is the tool used to generate updates, it's best to plan an appropriate update cadence, and automate the creation and deployment of updates in a testing environment before releasing to a remote fleet. 

##### Nodes will automatically stage updates
Many strategies to updating nodes are valid. This example promotes both the operating system update **and** container images being pulled down as they become available. 
Enable staging for rpm-ostree by setting `AutomaticUpdatePolicy=stage` in `/etc/rpm-ostreed.conf`. The `rpm-ostreed-automatic.timer` will also need to be enabled as shown in the config.

The example container uses the `io.containers.autoupdate=image` label to notify Podman that it should be running the latest image with the defined tag.

##### systemd timers will implement local actions and help us implement maintenance windows
Timers are very similar to chron jobs, but also offer some amazing features that benefit this use case. Essentially they're managed like any other systemd unit file and the details for options can be found [here.](https://www.freedesktop.org/software/systemd/man/systemd.timer.html) 
```
$ systemctl list-timers
NEXT                         LEFT     LAST                         PASSED       UNIT                         ACTIVATES
Thu 2020-09-03 00:42:57 UTC  21h left Wed 2020-09-02 00:08:54 UTC  3h 30min ago podman-auto-update.timer     podman-auto-update.service
Thu 2020-09-03 01:30:00 UTC  21h left n/a                          n/a          applyupdate.timer            applyupdate.service
Thu 2020-09-03 03:00:07 UTC  23h left Wed 2020-09-02 03:00:07 UTC  39min ago    rpm-ostreed-automatic.timer  rpm-ostreed-automatic.service
```

###### Splaying events
Some actions like downloading an OS update or a container image should ideally use some type of *splay* to ensure that a reasonable load is placed on the registry and ostree mirror. Using RandomizedDelaySec=86400 will randomize the timer across a 24 hour period. This is a highly effect approach for events that are not particulatly time sensative.

###### When not to splay
For events like applying OS updates, it's best to carefully target a maintenance window to ensure the SLA is met and the downtime is very minimal and predictible. The provided example will apply updates nighly at 1:30 UTC (OnCalendar=*-*-* 01:30:00). A more realistic example might follow a weekly maintenance window on Sunday nights (OnCalendar=Sun *-*-* 00:00:00). 

##### Local filesystems are encrypted and the TPM chip will be used to automatically unlock the disks.
While disk encryption does not provide protection at runtime, it does protect against disks being removed from a device and data being at risk. We support TPM2 chips for storing the luks passphrase. It's recommended that systems in unsecure facilities have security properly configured at the firmware level as well.

##### cgroup v2 is enabled in the OS & podman in this example.
CGroup v2 offers a lot of value. In short, it provided better security and isolation for any nested cgroups, many common actions are much lighter weight than v1, and the memory controller provides amazing amount of flexibility beyond just a hard cap to invoke the OOM killer. Simply append `systemd.unified_cgroup_hierarchy=1` to the kernel to switch to v2 for the OS. At the time of writing this, Podman will need to use crun as the runtime to launch containers with v2. Add `runtime="crun"` to `containers.conf` to alter the default of runc.

##### The bootloader is password protected
This is standard practice for systems with unprotected console access. This complements the TPM & disk encryption and prevents users from altering the boot options for the system.
