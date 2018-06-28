if Mix.env in [:dev, :test] do
defmodule PrettyConsole.DebugFileBackend do
  @moduledoc false

  @debug_file_disk_log_name PrettyConsole.DebugFileBackend.DiskLog

  @behaviour :gen_event

  def stream_file!(opts \\ []) do
    {:ok, df} = init({__MODULE__, opts})
    DebugFile.stream!(df)
  end

  def init(__MODULE__), do:
    init({__MODULE__, []})

  def init({__MODULE__, opts}) when is_list(opts) do
    config = Keyword.merge(Application.get_env(:logger, __MODULE__, []), opts)
    {:ok, reopen_debug_file(config, nil)}
  end

  def handle_call({:configure, options}, df) do
    {:ok, :ok, configure(options, df)}
  end

  def handle_event({_level, gl, _event}, df) when node(gl) != node() do
    {:ok, df}
  end

  def handle_event({_, _, {Logger, _, _, _}} = event, df) do
    formatted_term = format_event(event)

    case DebugFile.log_term(df, formatted_term) do
      {:ok, new_df} ->
        {:ok, new_df}

      {:error, reason} ->
        report_error(reason)
        {:ok, df}
    end
  end

  def handle_event(:flush, df) do
    :ok = DebugFile.flush(df)
    {:ok, df}
  end

  def handle_event(_, df) do
    {:ok, df}
  end

  def handle_info(_, df) do
    {:ok, df}
  end

  def code_change(_old_vsn, df, _extra) do
    {:ok, df}
  end

  def terminate(_reason, df) do
    :ok = DebugFile.close(df)
    :ok
  end

  ## Helpers

  defp format_event({level, gl, {Logger, msg, ts, md}}) do
    metadata = [group_leader: gl, timestamp: ts, level: level] ++ md

    case Keyword.fetch(metadata, :translation_req) do
      {:ok, treq} ->
        [report: treq, metadata: metadata]

      :error ->
        [report: {:text, msg}, metadata: metadata]
    end
  end

  defp report_error(reason) do
    formatted_msg = IO.ANSI.format([
      "\n",
      :red,
      "could not write message to #{__MODULE__} log, ",
      "reason:\n", inspect(reason),
      "\n"
    ])

    IO.puts(:stderr, formatted_msg)
  end

  defp configure(options, state) do
    config = Keyword.merge(Application.get_env(:logger, :console), options)
    Application.put_env(:logger, :console, config)
    reopen_debug_file(config, state)
  end

  defp reopen_debug_file(config, prev_debug_file) do
    case prev_debug_file do
      nil -> :ok
      df  -> DebugFile.close(df)
    end

    path = Keyword.get(config, :path, :default)

    DebugFile.open(@debug_file_disk_log_name, path)
  end


end
end
