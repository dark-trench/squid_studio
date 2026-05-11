defmodule SquidStudioDash.MixProject do
  use Mix.Project

  def project do
    [
      app: :squid_studio_dash,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {SquidStudioDash.Application, []}
    ]
  end

  defp deps do
    [
      {:squid_studio, path: ".."},
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 1.1"},
      {:bandit, "~> 1.5"},
      {:jason, "~> 1.2"}
    ]
  end

  defp releases do
    [
      squid_studio_dash: [
        include_executables_for: [:unix]
      ]
    ]
  end
end
