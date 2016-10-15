use Mix.Config

config :elixir,
  ansi_enabled: true

config :logger,
  level: :debug,
  handle_otp_reports: true,
  handle_sasl_reports: true,
  utc_log: true,
  translators: [],
  backends: []
