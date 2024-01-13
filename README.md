# Backend

This is the Metrist.io backend app.

# Prerequisites

- Current versions of Elixir and Erlang, and NodeJs.
  - There is an [asdf-vm](https://asdf-vm.com/#/) `.tool-versions` file which is the simple and recommended way to install all three.
- Assuming you're using a Debian-variant OS, there are some other packages you'll
want to install:

```
sudo apt-get install erlang-dev
sudo apt-get install erlang-xmerl
sudo apt-get install npm
```

# Development

Run `docker-compose up -d` to start PostgreSQL. Initialize everything with
`make dev`, then `make run` to start the local server.

The docker-compose includes [pgAdmin](http://localhost:3002). The username is
`test@metrist.io` and the password is `123qwe`.

All you need to do is add a database connection (host, user, pass are all "postgres").
You'll want to ensure that you're connecting to the correct host IP, which should simply
be `postgres:5432` if you're using the Docker setup.

TimescaleDB is also started with docker-compose and it can be connected to by using

```
tsdb:5432 - from inside pgadmin
localhost:5532 from outside the container
postgres
postgres
```

Mix tests:

- run with `mix test`
- watch with `mix test.watch`
- watch specific test files with `mix test.watch path/to/file.exs`, example: `mix test.watch test/domain/alert_manager_test.exs`

A bunch of helpful stuff lives in the [How-to directory](docs/HOWTOS.md).

# RDS databases

We use the standard "prod" MIX_ENV for deployed environments, but that really
means "AWS managed deployments". There are RDS databases configured per
Stackery environment tag with secrets in Secrets Manager. The `config.releases.exs`
module is a run-time configuration that fetches these secrets and uses them to
configure users.

For now, we do manual migrations. Set the AWS environment variables, then
point `ENVIRONMENT_TAG` and `SECRETS_NAMESPACE` to dev1 or prod, and
run `make migrate`.

# Auth, secrets, and so on

In development, the code can run without secrets but functionality will be
limited (logging in will not be possible, for starters). Therefore,
please set the following environment variables before starting `mix phx.server`:

```
  AWS_ACCESS_KEY_ID=<secret>
  AWS_SECRET_ACCESS_KEY=<secret>
  SECRETS_NAMESPACE=/dev1/
  AWS_REGION=us-east-1
```

This will run the backend with access to the `dev1` environment's Secrets Manager
values for accessing Auth0 and so on. See [Backend.Application](lib/backend/application.ex)
for details on the secrets pulled.

# Other docs

* [An explanation of our clustering setup](docs/clustering.md)
* [Debugging deployed instances](docs/iex-and-observer-in-aws.md)
