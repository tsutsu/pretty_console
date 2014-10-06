defmodule PrettyConsole.Mixfile do
  use Mix.Project

  def project do [
    app: :pretty_console,
    version: "0.1.0",
    elixir: ">= 1.0.0",
    deps: []
  ] end

  # Configuration for the OTP application
  def application do [
    applications: [:logger]
  ] end
end
