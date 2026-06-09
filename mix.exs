defmodule SquidStudio.MixProject do
  use Mix.Project

  def project do
    [
      app: :squid_studio,
      version: "0.1.0",
      name: "Squid Studio",
      description: description(),
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      package: package(),
      docs: docs(),
      source_url: source_url(),
      homepage_url: source_url(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: dialyzer()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {SquidStudio.Application, []},
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.html": :test,
        "coveralls.json": :test,
        coverage: :test,
        precommit: :test
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1.0"},
      {:squidie, "~> 0.1.3", optional: true},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:esbuild, "~> 0.10", only: [:dev, :test], runtime: false},
      {:tailwind, "~> 0.3", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1,
       only: [:dev, :test]},
      {:jason, "~> 1.2"}
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
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind squid_studio", "esbuild squid_studio"],
      "assets.deploy": [
        "tailwind squid_studio --minify",
        "esbuild squid_studio --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "xref graph --format cycles --label compile-connected --fail-above 0",
        "deps.unlock --check-unused",
        "format --check-formatted",
        "credo --strict",
        "deps.audit --ignore-file config/deps_audit.ignore",
        "assets.build",
        "coveralls"
      ],
      coverage: [
        "coveralls",
        "coveralls.json"
      ]
    ]
  end

  defp description do
    "Embeddable Phoenix workflow editor for Squidie."
  end

  defp source_url do
    "https://github.com/dark-trench/squid_studio"
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => source_url()},
      files: ~w(assets config lib priv .formatter.exs CHANGELOG.md LICENSE mix.exs README.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"],
      source_ref: "main",
      source_url: source_url()
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix, :ex_unit],
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [:error_handling, :missing_return, :underspecs]
    ]
  end
end
