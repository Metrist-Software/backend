defmodule Backend.MixProject do
  use Mix.Project

  def project do
    [
      app: :backend,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :domo_compiler] ++ Mix.compilers() ++ [:domo_phoenix_hot_reload] ,
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      dialyzer: dialyzer(),
      releases: [
        backend: [
          steps: [:assemble, :tar]
        ]
      ],
      # Don't include Domo's generated TypeEnsurer modules for test coverage
      test_coverage: [ignore_modules: [~r/\.TypeEnsurer$/]]
    ]
  end

  def application do
    [
      mod: {Backend.Application, [Mix.env()]},
      extra_applications: [:logger, :runtime_tools, :os_mon, :crypto, :timex, :swarm, :ex_json_schema, :mnesia]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:base62, "~> 1.2"},
      {:cachex, "~> 3.6"},
      {:commanded, github: "Metrist-Software/commanded", ref: "batching-support", override: true},
      {:commanded_ecto_projections, github: "Metrist-Software/commanded-ecto-projections", ref: "batching-support", override: true},
      {:commanded_eventstore_adapter, "~> 1.2"},
      {:configparser_ex, "~> 4.0"},
      {:contex, "~> 0.4.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:domo, "~> 1.5"},
      {:earmark, "~> 1.4"},
      {:ecto_psql_extras, "~> 0.7"},
      {:ecto_sql, "~> 3.4"},
      {:elixir_feed_parser, "~> 2.1"},
      {:elixir_uuid, "~> 1.2"},
      {:esbuild, "~> 0.6.0", runtime: Mix.env() == :dev},
      {:ex_aws_s3, "~> 2.0"},
      # Change back when https://github.com/ex-aws/ex_aws_secretsmanager/pull/7 has been merged.
      {:ex_aws_secretsmanager, github: "Metrist-Software/ex_aws_secretsmanager", ref: "6d651e5"},
      {:ex_aws_ses, "~> 2.0"},
      {:ex_aws_sns, "~> 2.0"},
      {:ex_json_schema, "~> 0.9.0"},
      {:floki, "~> 0.34.1"},
      {:gettext, "~> 0.11"},
      {:hackney, "~> 1.9"},
      {:hammer, "~> 6.1"},
      {:hammer_backend_mnesia, "~> 0.6"},
      {:horde, "~> 0.8.6"},
      {:httpoison, "~> 2.0.0"},
      {:jason, "~> 1.0"},
      {:joken, "~> 2.0"},
      {:kino, "~> 0.5", only: [:dev]},
      {:libcluster, "~> 3.3"},
      {:libcluster_ec2, "~> 0.5"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:open_api_spex, "~> 3.16"},
      {:paginator, "~> 1.2.0"},
      {:petal_components, "~> 0.19.10"},
      {:phoenix, "~> 1.6.0"},
      {:phoenix_ecto, "~> 4.1"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.18.2"},
      {:phoenix_typed_hook, "~> 0.18.2"},
      {:plug_cowboy, "~> 2.0"},
      {:postgrex, ">= 0.0.0"},
      {:prom_ex, "~> 1.7.1"},
      {:rexbug, ">= 1.0.0"},
      {:sentry, "~> 8.0"},
      {:sobelow, "~> 0.12", only: [:dev, :test], runtime: false},
      {:statistics, "~> 0.6.2", only: [:dev, :test], runtime: false},
      {:stripity_stripe, "~> 2.0"},
      {:swarm, git: "https://github.com/Metrist-Software/swarm.git", ref: "a905c87287555eac960270da24d870815b8043e7"},
      {:sweet_xml, "~> 0.6"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_metrics_cloudwatch, "~> 0.3.1"},
      {:telemetry_poller, "~> 1.0.0"},
      {:timex, "~> 3.0"},
      {:typed_struct, "~> 0.3.0"},
      {:ueberauth_auth0, "~> 2.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm ci --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "event_store.setup": ["event_store.create", "event_store.init"],
      "event_store.reset": ["event_store.drop", "event_store.setup"],
      "event_store.seed": ["run priv/event_store/seeds.exs"],
      "assets.deploy": [
        "cmd --cd assets npm run deploy",
        "esbuild default --minify",
        "phx.digest"],
      sentry_recompile: ["compile", "deps.compile sentry --force"]
    ]
  end

    defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_add_apps: [:ex_unit, :jason, :mix, :phoenix_pubsub],
      plt_add_deps: :app_tree,
      plt_file: {:no_warn, "priv/plts/backend.plt"}
    ]
  end

end
