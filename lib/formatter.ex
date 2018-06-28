defmodule PrettyConsole.Formatter do
  @hidden_translation_req_annotation "_tr\e[0D\e[0D\e[0D"

  def format(level, msg, ts, metadata) do
    format_from_logger!(level, msg, ts, metadata)
  rescue e ->
    s = System.stacktrace
    exception_str = Exception.format(:throw, e, s)

    ["\n", :red, "could not format: #{inspect {level, msg, metadata}}\n", exception_str, "\n"]
    |> IO.ANSI.format()
  end

  def format_from_logger!(level, [@hidden_translation_req_annotation, _plaintext], ts, metadata) when is_list(metadata) do
    {report, metadata} = Keyword.pop(metadata, :translation_req)

    metadata = [level: level, timestamp: ts] ++ metadata

    format!(report, metadata)
  end

  def format_from_logger!(level, msg, ts, metadata) when is_list(metadata) do
    metadata = [level: level, timestamp: ts] ++ metadata
    format!({:text, msg}, metadata)
  end

  def format_from_replay!([report: report, metadata: metadata]) do
    format!(report, metadata)
  end

  def format!(report, metadata) do
    metadata = Map.new(metadata)

    style = %{
      show: :all,
      color: get_highlight_color(metadata[:level])
    }

    if print_report?(report, metadata) do
      metadata = metadata
      |> put_application()
      |> put_session()
      |> put_blame(style)

      {report, blame_shape} = late_translate(report, metadata)

      stylize(report, metadata, Map.put(style, :blame_shape, blame_shape))
    else
      []
    end
  end

  defp print_report?({:text, _text}, _metadata), do: true

  # TODO: filter out useless reports here
  defp print_report?(:app_started, _metadata), do: true
  defp print_report?({:child_started, _}, _metadata), do: false
  defp print_report?({:child_exited, _, _}, _metadata), do: true
  defp print_report?({:crashed, _, _}, _metadata), do: true
  defp print_report?(_, _metadata), do: true

  defp late_translate(:app_started, _), do:
    {IO.ANSI.format([:green, "started", :reset]), :nothing}

  defp late_translate({:child_exited, child, reason}, _), do:
    {["#{inspect child} exited: #{reason}"], :compact}

  defp late_translate({:crashed, process, error}, _), do:
    {["#{inspect process} crashed: #{inspect error}"], :compact}

  defp late_translate({:text, text}, _metadata), do:
    {text, :compact}

  defp late_translate(term, metadata), do:
    {inspect({term, metadata}, pretty: true, width: 80), :multiline}


  defp get_highlight_color(:debug), do: :cyan
  defp get_highlight_color(:info), do: :normal
  defp get_highlight_color(:warn), do: :yellow
  defp get_highlight_color(:error), do: :red

  defp put_blame(metadata, %{show: show_style}) do
    Map.put(metadata, :blame, get_blame(show_style, metadata))
  end

  defp put_application(metadata) do
    case {metadata[:application], metadata[:pid]} do
      {app, _} when is_atom(app) ->
        metadata

      {_, pid} when is_pid(pid)  ->
        Map.put(metadata, :application, :application.get_application(pid))

      _ ->
        metadata
    end
  end

  defp put_session(metadata) do
    case Map.fetch(metadata, :pid) do
      {:ok, pid} when is_pid(pid) ->
        Map.put(metadata, :session, get_session(metadata[:pid]))

      _ ->
        metadata
    end
  end

  def stylize(msg, metadata, style) do
    %{color: color, blame_shape: blame_shape} = style

    level = metadata[:level]

    app_desc = case {metadata[:application], metadata[:session]} do
      {:kernel, _} -> :system
      {:stdlib, _} -> :system
      {nil, {:ok, user_session}} -> {:user, user_session}
      {nil, {:error, :system_process}} -> :system
      {nil, {:error, :dead_process}} -> :dead
      {v, _} when is_atom(v) -> {:app, v}
    end

    app_part = case app_desc do
      {:app, app} -> [color, "[", to_string(app), basic_level_part(level), "] ", :reset]
      :dead ->
        [color, "<dead>", basic_level_part(level), ": ", :reset]
      :system ->
        [color, "runtime", basic_level_part(level), ": ", :reset]
      {:user, :local_console} ->
        [:bright, "console", :reset, color, basic_level_part(level), :reset, " | "]
      {:user, {:remote, {session_counter, username}}} ->
        [:italic, :blue, "~", username, :reset, :blue, ":", to_string(session_counter), :reset, color, user_action_level_part(level), :reset]
    end

    blame_parts = Enum.flat_map(metadata[:blame], fn(blame) ->
      case blame do
        {:mfa, {m, f, a}} ->
          [[:blue, "from ", :bright, inspect(m), ".", to_string(f), "/", to_string(a), :reset]]
        {:file_and_line, f_l} ->
          [[:blue, f_l, :reset]]
        _ -> []
      end
    end)

    blame_part = case {blame_parts, blame_shape} do
      {[], _} -> {:part, []}

      {_, :nothing} -> {:part, []}

      {l, :compact} when is_list(l) -> {:part, [
        :blue, " (",
        Enum.intersperse(l, [:white, " : "]),
        :blue, ")", :reset
      ]}

      {l, :multiline} when is_list(l) -> {:line, [
        :blue, "(",
        Enum.intersperse(l, [:white, " : "]),
        :blue, ")", :reset
      ]}
    end

    [msg_first_ln|msg_rest_lns] = msg |> :erlang.iolist_to_binary |> String.split("\n")
    msg_first_ln = [app_part, msg_first_ln]

    {log_first_ln, log_rest_lns} = case blame_part do
      {:part, blame_part} -> {[msg_first_ln, blame_part], msg_rest_lns}
      {:line, blame_ln} -> {blame_ln, [msg_first_ln|msg_rest_lns]}
    end

    indented_rest_lns = Enum.map(log_rest_lns, fn(ln) -> ["  ", ln, "\n"] end)

    IO.ANSI.format_fragment([log_first_ln, "\n", indented_rest_lns])
  end

  defp basic_level_part(:info), do: []
  defp basic_level_part(level_name), do: [" ", to_string(level_name)]

  defp user_action_level_part(:info), do: ["> "]
  defp user_action_level_part(:debug), do: [" tests: "]
  defp user_action_level_part(:warn), do: [" warns: "]
  defp user_action_level_part(:error), do: [" fails: "]

  defp get_blame(:nothing, _metadata), do: []
  defp get_blame(show, metadata), do: get_blame(show, metadata[:module], metadata)

  defp get_blame(_show, nil, _metadata), do: []

  @blame_parts [:mfa, :file_and_line]
  defp get_blame(:all, mod, metadata), do: get_blame(@blame_parts, mod, metadata)

  defp get_blame(blame_parts, mod, metadata) when is_list(blame_parts) do
    Enum.flat_map(blame_parts, &get_blame(&1, mod, metadata))
  end

  defp get_blame(:file_and_line, mod, metadata) do
    case fetch_file_for(mod, metadata) do
      {:ok, source_file} ->
        file_and_line = source_file
        |> Path.relative_to_cwd()
        |> Exception.format_file_line(metadata[:line])
        |> String.slice(0..-2)

        [{:file_and_line, file_and_line}]

      :error ->
        []
    end
  end

  defp get_blame(:mfa, mod, %{function: f}), do:
    get_blame(:mfa, mod, f)

  defp get_blame(:mfa, mod, fa) when is_binary(fa) do
    [fn_name, arity] = String.split(fa, "/")
    get_blame(:mfa, mod, {String.to_atom(fn_name), String.to_integer(arity)})
  end

  defp get_blame(:mfa, mod, {fn_name, arity}) when is_atom(fn_name) and is_integer(arity) do
    [{:mfa, {mod, fn_name, arity}}]
  end

  defp fetch_file_for(mod, metadata) do
    case {metadata[:file], Code.ensure_loaded?(mod)} do
      {file, _} when is_binary(file) ->
        {:ok, file}

      {_, true} ->
        case mod.module_info[:compile][:source] do
          f when is_binary(f) or is_list(f) -> {:ok, f}
          _ -> :error
        end

      {_, false} ->
        :error
    end
  end

  defp get_session(pid) do
    case get_group(pid) do
      {:error, _} = err -> err
      {:ok, :local_console} -> {:ok, :local_console}
      {:ok, group} when is_pid(group) ->
        {:dictionary, d} = Process.info(group, :dictionary)
        case Keyword.fetch(d, :ssh_session_id) do
          {:ok, session_id} -> {:ok, {:remote, session_id}}
          :error -> {:error, :system_process}
        end
    end
  end

  defp get_group(pid) do
    case Process.info(pid, :group_leader) do
      {:group_leader, group} ->
        case local_console_group_leader() do
          ^group -> {:ok, :local_console}
          _ -> {:ok, group}
        end
      nil -> {:error, :dead_process}
    end
  end

  defp local_console_group_leader do
    case Process.get(:local_console_group_leader) do
      :none -> nil
      nil ->
        new_value = read_local_console_group_leader()
        Process.put(:local_console_group_leader, new_value)
        new_value
      v -> v
    end
  end

  defp read_local_console_group_leader do
    case Process.whereis(:user_drv) do
      nil -> :none
      tty_pid when is_pid(tty_pid) ->
        {:dictionary, d} = Process.info(tty_pid, :dictionary)
        Keyword.fetch!(d, :current_group)
    end
  end
end
