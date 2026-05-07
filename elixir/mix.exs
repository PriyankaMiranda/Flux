defmodule Flux.MixProject do
  use Mix.Project

  def project do
    [
      app: :flux,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Flux.Application, []}
    ]
  end

  defp deps do
    [
      # WebSocket and HTTP
      {:cowboy, "~> 2.10"},
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      
      # Pub/Sub messaging
      {:phoenix_pubsub, "~> 2.1"},
      
      # Configuration
      {:yaml_elixir, "~> 2.11"},
      {:dotenv, "~> 3.1"},
      
      # Database (TimescaleDB)
      {:postgrex, "~> 0.18"},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      
      # Elixir to Rust integration
      {:rustler, "~> 0.33"},
      
      # HTTP client
      {:httpoison, "~> 2.0"},
      
      # Dev/Test
      {:ex_doc, "~> 0.30", only: :dev}
    ]
  end
end
