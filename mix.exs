defmodule Nicotib.Mixfile do
  use Mix.Project

  def project do
    [app: :nicotib,
     version: "0.0.1",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
		 description: "Nicotib is an application written in Erlang which aims to provide a medium to interact with the block chain and the bitcoin network",
		 package: package]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger],
		mod: {Nicotib, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    []
  end
	defp package do
		[files: ["lib", "priv", "mix.ex", "README*", "LICENSE*"],
		 mantainers: ["Asier Azkuenaga Batiz"],
		 licenses: ["GPL v3"]
		]
	end
end
