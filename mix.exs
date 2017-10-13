defmodule PrettyConsole.Mixfile do
  use Mix.Project

  @version File.read!("VERSION") |> String.trim

  def project do [
    app: :pretty_console,
    version: @version,
    description: description(),
    package: package(),
    elixir: "~> 1.5.0",
    deps: deps()
  ] end

  defp description do
    """
    A slightly more pleasant Logger console backend.
    """
  end

  defp package do [
    name: :pretty_console,
    files: ["config", "lib", "mix.exs", "VERSION", "LICENSE"],
    maintainers: ["Levi Aul"],
    licenses: ["MIT"],
    links: %{"GitHub" => "https://github.com/tsutsu/pretty_console"}
  ] end

  # Configuration for the OTP application
  def application do [
    extra_applications: [:logger]
  ] end

  defp deps do [
    {:ex_doc, ">= 0.0.0", only: :dev}
  ] end
end
