use Mix.Config

config :elixir, :ansi_enabled, true

config :logger, :level, :debug
config :logger, :handle_otp_reports, true
config :logger, :handle_sasl_reports, true
config :logger, :utc_log, true

config :logger, :backends, [PrettyConsole]
config :logger, :translators, [{PrettyConsole.Translator, :translate}]
