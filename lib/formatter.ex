defmodule PrettyConsole.Formatter do
  def format({level, style}, msg, _ts, metadata) do
    %{color: color, show: show} = style
    {msg, metadata} = case msg do
      [["application ", app_name, " "], new_msg] ->
        {new_msg, Keyword.put(metadata, :application, String.to_atom(app_name))}
      msg ->
        {msg, metadata}
    end

    app_name = case {metadata[:application], metadata[:pid]} do
      {app, _} when is_atom(app) -> app
      {_, pid} when is_pid(pid)  -> :application.get_application(pid)
      _                          -> nil
    end

    app_desc = case app_name do
      :kernel -> :system
      :stdlib -> :system
      nil -> case get_session(metadata[:pid]) do
        {:error, :dead_process} -> :dead
        {:error, :system_process} -> :system
        {:ok, user_session} -> {:user, user_session}
      end
      v -> {:app, v}
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

    blame_parts = Enum.flat_map(get_blame(show, metadata), fn(blame) ->
      case blame do
        {:mfa, {m, f, a}} ->
          [[:blue, "from ", :bright, inspect(m), ".", to_string(f), "/", to_string(a), :reset]]
        {:file_and_line, f_l} ->
          [[:blue, f_l, :reset]]
        _ -> []
      end
    end)

    blame_part = case {blame_parts, style[:shape]} do
      {[], _} -> {:part, []}

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
    source_file = mod.module_info[:compile][:source]
    file_and_line = Exception.format_file_line(Path.relative_to_cwd(source_file), metadata[:line]) |> String.slice(0..-2)
    [{:file_and_line, file_and_line}]
  end

  defp get_blame(:mfa, mod, metadata) do
    [fn_name, arity] = String.split(metadata[:function], "/")
    [{:mfa, {mod, fn_name, arity}}]
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
