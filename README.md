# Usernetes: Moby (aka Docker) & Kubernetes, without the root privileges

Usernetes aims to provide a binary distribution of Moby (aka Docker) and Kubernetes that can be installed under a user's `$HOME` and does not require the root privileges.

 - [Status](#status)
 - [How it works](#how-it-works)
 - [Requirements](#requirements)
 - [Restrictions](#restrictions)
 - [Install from binary](#install-from-binary)
 - [Install from source](#install-from-source)
 - [Quick start](#quick-start)
   - [Start Kubernetes using Docker](#start-kubernetes-using-docker)
   - [Start Kubernetes using CRI-O](#start-kubernetes-using-cri-o)
   - [Start dockerd only (No Kubernetes)](#start-dockerd-only-no-kubernetes)
   - [Use `docker`](#use-docker)
   - [Use `kubectl`](#use-kubectl)
   - [Reset to factory defaults](#reset-to-factory-defaults)
 - [Advanced guide](#advanced-guide)
   - [Expose netns ports to the host](#expose-netns-ports-to-the-host)
   - [Routing ping packets](#routing-ping-packets)
 - [License](#license)

## Status

* [X] Moby (`dockerd`): Almost usable (except Swarm-mode)
* [X] Kubernetes: Early POC with a single node
  * [X] dockershim
  * [X] CRI-O
  * [ ] containerd (planned)

## How it works

Usernetes executes Moby (aka Docker) and Kubernetes without the root privileges by using unprivileged [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html), [`mount_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html), and [`network_namespaces(7)`](http://man7.org/linux/man-pages/man7/network_namespaces.7.html).

To set up NAT across the host and the network namespace without the root privilege, Usernetes uses a usermode network stack ([slirp4netns](https://github.com/rootless-containers/slirp4netns)).

No SETUID/SETCAP binary is needed. except [`newuidmap(1)`](http://man7.org/linux/man-pages/man1/newuidmap.1.html) and [`newgidmap(1)`](http://man7.org/linux/man-pages/man1/newgidmap.1.html), which are used for setting up [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html) with multiple sub-UIDs and sub-GIDs.

## Requirements

* `newuidmap` and `newgidmap` need to be installed on the host. These commands are provided by the `uidmap` package on most distros.

* `/etc/subuid` and `/etc/subgid` should contain more than 65536 sub-IDs. e.g. `penguin:231072:65536`. These files are automatically configured on most distros.

```console
$ id -u
1001
$ whoami
penguin
$ grep ^$(whoami): /etc/subuid
penguin:231072:65536
$ grep ^$(whoami): /etc/subgid
penguin:231072:65536
```

* Some distros such as Debian (excluding Ubuntu) and Arch Linux require `echo 1 > /proc/sys/kernel/unprivileged_userns_clone`.

## Restrictions

Moby (`dockerd`):
* Only `vfs` graphdriver is supported. However, on [Ubuntu](http://kernel.ubuntu.com/git/ubuntu/ubuntu-artful.git/commit/fs/overlayfs?h=Ubuntu-4.13.0-25.29&id=0a414bdc3d01f3b61ed86cfe3ce8b63a9240eba7) and a few distros, `overlay2` and `overlay` are also supported. [Starting with Linux 4.18](https://www.phoronix.com/scan.php?page=news_item&px=Linux-4.18-FUSE), we will be also able
 to implement FUSE snapshotters.
* Cgroups (including `docker top`) and AppArmor are disabled at the moment. (FIXME: we could enable Cgroups if configured on the host)
* Checkpoint is not supported at the moment.
* Running rootless `dockerd` in rootless/rootful `dockerd` is also possible, but not fully tested.
* You can form Swarm-mode clusters but overlay networking is not functional.

CRI-O:
* To be documented (almost same as Moby)

Kubernetes:
* `kube-proxy` is not supported yet.
* Multi-node networking is untested

## Install from binary

Download the latest `usernetes-x86_64.tbz` from [Releases](https://github.com/rootless-containers/usernetes/releases).

```console
$ tar xjvf usernetes-x86_64.tbz
$ cd usernetes
```

## Install from source

```console
$ git clone https://github.com/rootless-containers/usernetes.git
$ cd usernetes
$ go get -u github.com/go-task/task/cmd/task
$ task -d build
```

## Quick start

### Start Kubernetes using Docker

```console
$ ./run.sh
```

### Start Kubernetes using CRI-O

```console
$ ./run.sh default-crio
```

### Start dockerd only (No Kubernetes)

If you don't need Kubernetes:
```console
$ ./run.sh dockerd
```

### Use `docker`

```console
$ docker -H unix:///run/user/1001/docker.sock info
```

Or

```console
$ ./dockercli.sh info
```

### Use `kubectl`

```console
$ nsenter -U -n -t $(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid) hyperkube kubectl --kubeconfig=./localhost.kubeconfig get nodes
```

Or

```console
$ ./kubectl.sh get nodes
```

### Reset to factory defaults

```console
$ ./cleanup.sh
```

## Advanced guide

### Expose netns ports to the host

As Usernetes runs in a network namespace (with [slirp4netns](https://github.com/rootless-containers/slirp4netns)),
you can't expose container ports to the host by just running `docker run -p`.

In addition, you need to expose Usernetes netns ports to the host via `socat`.

e.g.
```console
$ pid=$(cat $XDG_RUNTIME_DIR/usernetes/rootlesskit/child_pid)
$ socat -t -- TCP-LISTEN:8080,reuseaddr,fork EXEC:"nsenter -U -n -t $pid socat -t -- STDIN TCP4\:127.0.0.1\:80"
```

### Routing ping packets

To route ping packets, you need to set up `net.ipv4.ping_group_range` properly as the root.

```console
$ sudo sh -c "echo 0   2147483647  > /proc/sys/net/ipv4/ping_group_range"
```

## License

Usernetes is licensed under the terms of  [Apache License Version 2.0](LICENSE).

The binary releases of Usernetes contain files that are licensed under the terms of different licenses:

* `bin/slirp4netns`: [GNU GENERAL PUBLIC LICENSE Version 2](docs/binary-release-license/LICENSE-slirp4netns), see https://github.com/rootless-containers/slirp4netns
* `bin/task`: [MIT License](docs/binary-release-license/LICENSE-task), see https://github.com/go-task/task
