defmodule PrettyConsole do
  def install!(mode \\ :prod) do
    Logger.configure([
      handle_otp_reports: true,
      handle_sasl_reports: true,
      utc_log: true,
      colors: [enabled: true]
    ])

    Logger.add_translator {PrettyConsole.Translator, :translate}
    Logger.remove_translator {Logger.Translator, :translate}

    Logger.configure_backend(:console, [
      metadata: :all,
      format: {formatter_module(mode), :format}
    ])
  end

  if Mix.env in [:dev, :test] do
    def replay!(opts \\ []) do
      formatter = formatter_module(opts[:mode])

      PrettyConsole.DebugFileBackend.stream_file!(opts)
      |> Enum.each(fn log ->
        formatted = formatter.format_from_replay!(log)
        IO.binwrite(formatted)
        :ok
      end)

      :ok
    end
  end

  defp formatter_module(:debug), do: PrettyConsole.DebugFormatter
  defp formatter_module(_), do: PrettyConsole.Formatter
end
