defmodule PrettyConsole do
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
    format_module = Application.get_env(:pretty_console, :formatter)
    fmt = fn({level, color_for_level}, msg, ts, md) ->
      format_module.format({level, color_for_level}, msg, ts, md)
    end

    level = Application.get_env(:pretty_console, :level)

    colors = Application.get_env(:pretty_console, :colors)
    colors = colors |> Enum.into(%{})
    colors = @default_colors |> Map.merge(colors)

    %{formatter: fmt, level: level, colors: colors}
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

  defp log_event(level, msg, ts, md, %{formatter: fmt, colors: colors}) do
    color_for_level = Map.fetch!(colors, level)
    chardata = fmt.({level, color_for_level}, msg, ts, md)
    :io.put_chars(:user, chardata)
  end
end
