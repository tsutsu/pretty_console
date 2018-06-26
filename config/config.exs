use Mix.Config

config :elixir,
  ansi_enabled: true

config :logger,
  level: :debug,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  utc_log: true,
  colors: [enabled: true],
  backends: [:console],
  # backends: [:console, PrettyConsole.DebugFileBackend],
  translators: [{PrettyConsole.Translator, :translate}]

config :logger, :console,
  metadata: :all,
  format: {PrettyConsole.Formatter, :format}
