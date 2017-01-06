defmodule PrettyConsole.Mixfile do
  use Mix.Project

  @version File.read!("VERSION")

  def project do [
    app: :pretty_console,
    version: @version,
    elixir: "~> 1.4.0",
    deps: []
  ] end

  # Configuration for the OTP application
  def application do [
    mod: {PrettyConsole, []},
    extra_applications: [:logger]
  ] end
end
