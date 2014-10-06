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
      {:ok, load_configuration}
    else
      {:error, :ignore}
    end
  end

  defp load_configuration do
    env = Application.get_all_env :pretty_console

    formatter = env |> Dict.get(:formatter, PrettyConsole.Formatter)

    level = env |> Dict.get(:level, :debug)

    colors = env |> Dict.get(:colors, [])
    colors = colors |> Enum.into(%{})
    colors = @default_colors |> Map.merge(colors)

    %{formatter: formatter, level: level, colors: colors}
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
