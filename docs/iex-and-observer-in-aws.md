# IEx and Observer in AWS

The ECS deployment runs in [Erlang clustered mode](clustering.md) which means that we can add
a node running the IEx prompt and do all sorts of stuff there. The easiest way is just to
use the infra [`jump-on`](https://github.com/Metrist-Software/infra/blob/main/bin/jump-on.sh) script
but that will only give you a command line. For reference:

```
      <your machine>$ .../infra/bin/jump-on.sh ~/.ssh/id_rsa.pub dev1 0
  <backend instance>$ sudo docker exec -i -t backend bash
<container instance>$ bin/backend remote
```

This sequence will give you an IEx prompt that's very much like the local one.

This document therefore mostly explains how to get a graphical Observer running against deployed
BEAM instances. It assumes you're running this from an X environment (if you're on Windows or
Mac, you have some extra work to do that's outside the scope of this document).

## Using the Jump host.

In EC2, we can do all that if we join an ad-hoc BEAM instance to the cluster. For this, we need
to do a couple of things:

* Run an EC2 node in the public subnet so we can ssh in;
* Run it with the same security group as the "real" EC2 instances to allow Erlang clustering
  traffic, plus ssh port 22;
* Have Elixir installed (plus full Erlang, the `elixir` and `esl-erlang` packages from the
  [ESL download site](https://www.erlang-solutions.com/downloads/) work fine; there is one
  missing dependency, `libwxgtk-webview3.0-gtk3-0v5`, which needs to be installed as well).

Both the `dev1` and `prod` environments run such an EC2 machine that can be reached by using the `'j'` target
instead of an instance number on the `jump-on` script. Note that currently, the jump host does not
have Elixir preinstalled. Steps to do so:


    wget https://packages.erlang-solutions.com/erlang-solutions_2.0_all.deb
    sudo dpkg -i erlang-solutions_2.0_all.deb
    sudo apt update
    sudo apt install esl-erlang elixir libwxgtk-webview3.0-gtk3-0v5


## Running Observer

Once logged in on the jump host, you want to find out where the current nodes live:

    host i-all.backend.dev1.canarymonitor.net

If the cluster isn't upgrading or something, two IP addresses should appear. You only need one to bootstrap things, Erlang
will ensure a full mesh is created. Using the IP address that is in the shell prompt (`ubuntu@ip-192-168-0-30`), start IEx:

    iex --cookie backend-node --name iex@192.168.0.30 --erl '-kernel inet_dist_listen_min 9000 -kernel inet_dist_listen_max 9010 -kernel shell_history_enabled'

And then on the IEx prompt, join the cluster. Use either of the IP addresses from `host` above, and do a ping to the node:

    iex(iex@10.0.185.194)0> :net_adm.ping(:"app@192.168.1.237")

You should get `:pong` as a response pretty much immediately, and `:erlang.nodes()` should list both app nodes now (if you get `:pang`,
usually after a while, then something is wrong and it's debugging time).

After that, you can
do whatever you want - start a remote shell, prod around, send messages/commands to aggregates, or - probably the goal most of the
time, start Observer:

    iex...> :observer.start()

Depending on your network connection, it might be slow-to-sluggish. If you feel adventurous, feel free to install a SPICE or VNC host
on the machine and connect that way :)

## VNC access

With the packages `tigervnc-standalone-server` and `xfwm4` it is easy to use VNC instead of remote X11; this drops the need to
have an X11 display server running and is usually much faster. Steps:

* On the jump host, install the packages needed: `sudo apt install tigervnc-standalone-server xfwm4`
* Start tigervnc with just the window manager if it is not already running (`tigervncserver -list`). Use `123qwe` for the password,
  so you can leave it running for others; SSH does the actual security here.

    tigervncserver :0 -xstartup xfwm4
    export DISPLAY=:0

* Now start IEx normally, Observer will be started on the virtual VNC display
* Use a VNC viewer to connect to `localhost:5900`
* Profit!
