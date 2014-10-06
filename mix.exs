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
    applications: [:logger],
    env: env
  ] end

  defp env do [
    level: :debug,
    formatter: PrettyConsole.Formatter,
    colors: [],
  ] end
end
