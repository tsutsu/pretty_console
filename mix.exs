defmodule PrettyConsole.Mixfile do
  use Mix.Project

  def project do [
    app: :pretty_console,
    version: "0.1.1",
    elixir: "~> 1.4.0",
    deps: []
  ] end

  # Configuration for the OTP application
  def application do [
    mod: {PrettyConsole, []},
    extra_applications: [:logger]
  ] end
end
