defmodule PrettyConsole.Backend do
  @moduledoc false


  @default_colors %{
    info: :normal,
    debug: :cyan,
    warn: :yellow,
    error: :red
  }


  use GenEvent

  def init(_) do
    if user = Process.whereis(:user) do
      Process.group_leader(self(), user)
      {:ok, load_configuration()}
    else
      {:error, :ignore}
    end
  end

  defp load_configuration do
    env = Application.get_env :logger, PrettyConsole

    level = env |> Keyword.get(:level, Application.get_env(:logger, :level))
    formatter = env |> Keyword.get(:formatter, PrettyConsole.Formatter)

    colors = env |> Keyword.get(:colors, [])
    colors = colors |> Enum.into(%{})
    colors = @default_colors |> Map.merge(colors)

    %{formatter: formatter, level: level, colors: colors}
  end

  def log(level, msg) do
    default_config = %{
      formatter: PrettyConsole.Formatter,
      colors: @default_colors
    }

    log_event(level, msg, DateTime.utc_now, [pid: self()], default_config)
  end


  def handle_event({_level, gl, _event}, state) when node(gl) != node() do
    {:ok, state}
  end

  def handle_event({level, _gl, {Logger, msg, ts, md}}, %{level: min_level} = state) do
    if is_nil(min_level) or Logger.compare_levels(level, min_level) != :lt do
      log_event(level, msg, ts, md, state)
    end
    {:ok, state}
  end

  defp log_event(level, msg, ts, md, %{formatter: formatter, colors: colors}) do
    color_for_level = Map.fetch!(colors, level)
    chardata = formatter.format({level, color_for_level}, msg, ts, md)
    :io.put_chars(:user, chardata)
  end
end
