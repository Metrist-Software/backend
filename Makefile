.PHONY: dev run db.reset

# If you want to run under IEx, simply do `make ELIXIR=iex run` or `run2`
ELIXIR = elixir

# `make dev` is pretty much what you would do after a reboot
dev:
	docker-compose up -d
	epmd -daemon
	mix deps.get
	npm ci --prefix assets

# `make dev-setup` is for a fresh checkout
dev-setup: dev db.reset
	./cert-setup.sh
	mix escript.install hex livebook


grafana.dev:
	docker-compose -f docker-compose.yml -f docker-compose.grafana.yml up -d

# Release locks that pgAdmin, ... probably is holding by resetting
# docker-compose before we reset the dev and test databases
db.reset:
	docker-compose restart
	MIX_ENV=dev make do.db.reset
#   We don't really need a test db currently, I think.
#	MIX_ENV=test make do.db.reset
	mix metrist.create_shared_account
	RTA_ENABLED=false mix event_store.seed

do.db.reset:
	export BACKEND_MINIMAL_START=true; mix ecto.reset
	export BACKEND_MINIMAL_START=true; mix event_store.reset

run_backend:
	mix ecto.migrate
	mix metrist.dbpa.migrate
	mix event_store.migrate
	npm install --prefix assets
	${ELIXIR_ACTION} --sname ${ELIXIR_SNAME} -S mix phx.server

run:
	make ELIXIR_ACTION=$(ELIXIR) ELIXIR_SNAME=first run_backend

run2:
	make ELIXIR_ACTION=$(ELIXIR) ELIXIR_SNAME=second PORT=4444 run_backend

run.iex:
	make ELIXIR_ACTION=iex ELIXIR_SNAME=first run_backend

run2.iex:
	make ELIXIR_ACTION=iex ELIXIR_SNAME=second PORT=4444 run_backend

# We don't want to always run livebook inside the development backend,
# but it's handy to have around in case it's needed. We have the dependencies
# in mix.iex so that we can run auto-attached and have everything working after this.
# Commented out mount-livebook-data as s3fs doesn't support SSO.
livebook: # mount-livebook-data
	cd livebooks; \
      LIVEBOOK_DATA_PATH=`pwd` \
	  LIVEBOOK_COOKIE=`cat ~/.erlang.cookie` \
	  LIVEBOOK_DEFAULT_RUNTIME=attached:first@`hostname`:`cat ~/.erlang.cookie` \
      livebook server

mount-livebook-data:
	-mkdir livebooks/data
	-umount livebooks/data
	touch /tmp/passwd-s3fs
	chmod 600 /tmp/passwd-s3fs
	echo $$AWS_ACCESS_KEY_ID:$$AWS_SECRET_ACCESS_KEY >/tmp/passwd-s3fs
	op run s3fs metrist-livebook-data livebooks/data \
		-o passwd_file=/tmp/passwd-s3fs \
		-o sigv4 \
		-o url=https://s3-us-west-2.amazonaws.com/

# Handy shortcut so you don't need to remember the URL
get_metrics:
	curl -k https://localhost:4443/internal/metrics

release:
	echo Revision: `git rev-parse --short HEAD` >priv/static/build.txt
	echo Date: `date` >>priv/static/build.txt
	echo Build-Host: `hostname` >>priv/static/build.txt
	npm --prefix ./assets ci
	MIX_ENV=prod mix sentry_recompile --force
	MIX_ENV=prod mix do assets.deploy, compile, release --overwrite

local_release:
	npm --prefix ./assets ci
	MIX_ENV=prod mix do assets.deploy, compile, release --overwrite

migrate_sso: ensure_envs_sso
	MIX_ENV=prod mix release --overwrite
	USE_DB_ADMIN=true _build/prod/rel/backend/bin/backend eval "Backend.ReleaseTasks.migrate_all()"

migrate_dev1:
	export AWS_REGION=us-east-1 ENVIRONMENT_TAG=dev1 SECRETS_NAMESPACE=/dev1/; make migrate_sso

migrate_prod:
	export AWS_REGION=us-west-2 ENVIRONMENT_TAG=prod SECRETS_NAMESPACE=/prod/; make migrate_sso

rollback_public: ensure_envs_sso
	MIX_ENV=prod mix release --overwrite
	_build/prod/rel/backend/bin/backend eval "Backend.ReleaseTasks.rollback_public()"

rollback_all_tenants: ensure_envs_sso
	MIX_ENV=prod mix release --overwrite
	_build/prod/rel/backend/bin/backend eval "Backend.ReleaseTasks.rollback_all_tenants()"

tail_log_dev:
	aws logs tail --region=us-east-1 --follow --since=0m dev1-backend-logs

tail_log_prod:
	aws logs tail --region=us-west-2 --follow --since=0m prod-backend-logs

ensure_envs:
	test -n "$$AWS_ACCESS_KEY_ID" || ( echo "AWS_ACCESS_KEY_ID not set"; exit 1 )
	test -n "$$AWS_SECRET_ACCESS_KEY" || ( echo "AWS_SECRET_ACCESS_KEY not set"; exit 1 )
	test -n "$$AWS_REGION" || ( echo "AWS_REGION not set"; exit 1 )
	test -n "$$SECRETS_NAMESPACE" || ( echo "SECRETS_NAMESPACE not set"; exit 1 )
	test -n "$$ENVIRONMENT_TAG" || ( echo "ENVIRONMENT_TAG not set"; exit 1 )

ensure_envs_sso:
	test -z "$$AWS_ACCESS_KEY_ID" || ( echo "Please unset AWS_ACCESS_KEY_ID"; exit 1 )
	test -z "$$AWS_SECRET_ACCESS_KEY" || ( echo "Please unset AWS_SECRET_ACCESS_KEY"; exit 1 )
	test -n "$$AWS_REGION" || ( echo "AWS_REGION not set"; exit 1 )
	test -n "$$SECRETS_NAMESPACE" || ( echo "SECRETS_NAMESPACE not set"; exit 1 )
	test -n "$$ENVIRONMENT_TAG" || ( echo "ENVIRONMENT_TAG not set"; exit 1 )

slack_test:
	@echo "This will start ngrok to proxy request from the ngrok URL to your localhost:4443 and will update your test application with the generated ngrok URLS. You can see the status of ngrok at http://localhost:4040"
	test -n "$$SLACK_TEST_APP_ID" || ( echo "SLACK_TEST_APP_ID is not set. Please ensure the APP ID to update is set. If you have never setup your test app please run mix metrist.create_slack_test_app"; exit 1 )
	test -n "$$SLACK_TEST_APP_IDENTIFIER" || ( echo "SLACK_TEST_APP_IDENTIFIER is not set. SLACK_TEST_APP_IDENTIFIER should be set to a unique identifier for your test app such as your name."; exit 1 )
	ngrok http https://localhost:4443 --log=stdout > /dev/null &
	mix metrist.update_slack_test_app
