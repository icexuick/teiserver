defmodule Central.MixProject do
  use Mix.Project

  def project do
    [
      app: :central,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [plt_add_apps: [:ex_unit, :mix], ignore_warnings: "config/dialyzer_ignore.exs"],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Central.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :iex]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.5.9"},
      {:phoenix_ecto, "~> 4.1"},
      {:ecto_sql, "~> 3.6.1"},
      {:postgrex, ">= 0.15.9"},
      {:floki, ">= 0.30.1", only: :test},
      {:phoenix_html, "~> 2.11"},
      {:phoenix_live_reload, "~> 1.3", only: :dev},
      {:phoenix_live_view, "~> 0.15.5"},
      {:phoenix_live_dashboard, "~> 0.2"},
      {:ecto_psql_extras, "~> 0.2"},
      {:telemetry_metrics, "~> 0.4"},
      {:telemetry_poller, "~> 0.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:logger_file_backend, "~> 0.0.10"},
      {:timex, "~> 3.7.5"},
      {:breadcrumble, "~> 1.0.0"},
      {:guardian, "~> 2.1"},
      {:argon2_elixir, "~> 2.3"},
      {:bodyguard, "~> 2.4"},
      {:human_time, "~> 0.2.4"},
      {:oban, "~> 2.6.1"},
      {:ranch, "~> 1.7.1"},
      {:parallel, "~> 0.0"},
      {:con_cache, "~> 1.0"},
      {:bamboo, "~> 2.1"},
      {:bamboo_smtp, "~> 4.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:elixir_uuid, "~> 1.2"},
      {:excoveralls, "~> 0.14", only: :test},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
