defmodule Commanded.EventStore.Adapters.Nats.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :commanded_nats_eventstore_adapter,
      version: @version,
      elixir: "~> 1.16",
      consolidate_protocols: Mix.env() != :test,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:commanded, "~> 1.4"},
      {:gnat, "~> 1.8"},
      {:uuid, "~> 1.1"},

      # Optional dependencies
      {:jason, "~> 1.2", optional: true},

      # Test & build tooling
      {:ex_doc, "~> 0.21", only: :dev},
      {:mox, "~> 1.0", only: :test}
    ]
  end

  defp package do
    [
      files: [
        "lib",
        "mix.exs",
        "README*",
        "LICENSE*"
      ],
      maintainers: ["Kevin Hoffman"],
      licenses: ["Apache-2"],
      links: %{
        "GitHub" => "https://github.com/autodidaddict/commanded-nats-eventstore-adapter"
      }
    ]
  end

  defp description do
    """
    NATS JetStream event store adapter for Commanded
    """
  end

  defp docs do
    [
      main: "Commanded.EventStore.Adapters.Nats",
      canonical: "http://hexdocs.pm/commanded_nats_eventstore_adapter",
      source_ref: "v#{@version}",
      extra_section: "GUIDES",
      extras: [
        "CHANGELOG.md",
        "guides/Getting Started.md": [
          filename: "getting-started",
          title: "NATS JetStream adapter"
        ]
      ]
    ]
  end

  defp elixirc_paths(:test) do
    [
      "lib",
      "deps/commanded/test/event_store",
      "deps/commanded/test/support",
      "test/support"
    ]
  end

  defp elixirc_paths(_), do: ["lib"]
end
