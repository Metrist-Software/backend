# Clustering in EC2

We need multiple instances in EC2 so that we can do a rolling restart. There is one component we already use that requires us to
cluster in this case, and that is [Phoenix PubSub](https://hexdocs.pm/phoenix_pubsub/Phoenix.PubSub.html).

We mainly use PubSub for notifications back from projections to active LiveViews that get updated with the new data. The projections
are guaranteed (by Commanded, using PostgreSQL locks) to run on only one node, but LiveViews are scattered across multiple nodes. So
as soon as we have multiple instances, some instances won't be doing local projections, will therefore not otherwise receive PubSub
messages, and therefore will not update the locally running LiveViews. Therefore, we need clustering. PubSub will automatically
recognize that it is running on clustered BEAM instances and exchange messages.

On top of that, we also use distribution in other places, like real-time analytics, keeping track of user flows, and probably more.

## Distributed Erlang

This might be a good moment to read the [Distributed Erlang](https://erlang.org/doc/reference_manual/distributed.html) documentation,
as it explains what is going on. Distributed Erlang is the more correct term but "clustering" is shorter, we use them interchangeably
here.

One thing to note is that there are two network connections in play: if the BEAM kernel code learns about a node (which has a name
and a hostname or IP address), it will first contact that node's IP address on port `4369/epmd` and ask the epmd running there to
lookup the name of the node and return the corresponding port, and only then it will form the cluster connection to the IP it already
knew and the port it just learned about. This way, a single host can run multiple instances of BEAM and only one reserved port is
needed. This is the same kind of port mapping that also underpins SunRPC, for example.

## EC2 and clustering

Distributed Erlang was created for a typical telephony switch control plane: two motherboards sitting close together plugged into
a passive backplane. Therefore, out-of-the-box, clustering requires manual setting of hostnames, which is a bit of a pain if they
change on every deployment. Because everything is accessible programmatically, solutions have sprung up that learn from the
network which nodes it should cluster with, for example by looking in DNS, in Kubernetes or Consul metadata, or using the AWS metadata
API. We use a library called [libcluster](https://hexdocs.pm/libcluster/readme.html) which supports, out of the box, DNS lookups.

The part that sets up DNS records is in our [backend infrastructure code](https://github.com/Metrist-Software/infra/blob/main/src/backend.ts)
where we add Route53 records for each host we create; our [runtime config](../config/runtime.exs) then configures libcluster to
look for these records.

All that libcluster therefore needs to do is to do a DNS request for `app.backend.<env-tag>-svcs.canarymonitor.com` every
time it wants to poll and process the resulting IP addresses as Erlang nodenames (again, by prefixing it with `app`, so
a nodename becomes `app@<private-ip>`).

## Clustering in development mode

It is important to be as close as possible to deployment environments in development as possible, especially when working on
clustering. To this end, our [Makefile](../Makefile) is setup to facilitate local clustering:

* `make run` will start Phoenix in a cluster-ready Erlang node;
* `make run2` will start a second Phoenix node.

In development, libcluster is configured to use the "local epmd" strategy, which essentially means that all local Erlang
nodes will automatically cluster up. The end result is a cluster that is very much like the one we use in deployed environments,
and by killing and restarting nodes it becomes easy to emulate rolling restarts.

## Some pointers

* In the [`rel`](../rel) directory there are a couple of template files that are used by the [release process](https://hexdocs.pm/mix/master/Mix.Tasks.Release.html#content):

  1. [`env.sh.eex`](../rel/env.sh.eex) is an EEx template that sets the Erlang distribution flags, like the nodename.
     That nodename is derived from the first IP address present in the local metadata.
  2. [`vm.args.eex`](../rel/vm.args.eex) is an EEx template that sets BEAM VM arguments, the relevant ones are the
     min and max listen port telling the BEAM distribution system to allocate a port in that range; it is the same
     range as we open up in the security group.
