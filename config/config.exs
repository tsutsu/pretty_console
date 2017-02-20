use Mix.Config

config :elixir,
  ansi_enabled: true

config :logger,
  level: :debug,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  utc_log: true,
  translators: [{PrettyConsole.Translator, :translate}, {Logger.Translator, :translate}],
  backends: [PrettyConsole.Backend]
