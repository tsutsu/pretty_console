defmodule PrettyConsole.Formatter do
  def format({level, color}, msg, _ts, metadata) do
    {msg, metadata} = case msg do
      [["application ", app_name, " "], new_msg] ->
        {new_msg, Keyword.put(metadata, :application, String.to_atom(app_name))}
      msg ->
        {msg, metadata}
    end

    level_part = case level do
      :info -> []
      level_name -> [" ", to_string(level_name)]
    end

    app_name = case {metadata[:application], metadata[:pid]} do
      {app, _} when is_atom(app) -> app
      {_, pid} when is_pid(pid)  -> :application.get_application(pid)
      _                          -> nil
    end

    app_desc = case app_name do
      :kernel -> :system
      :stdlib -> :system
      nil -> {:user, get_user(metadata[:pid])}
      v -> {:app, v}
    end

    app_part = case app_desc do
      {:app, app} -> [color, "[", to_string(app), level_part, "] ", :reset]
      :system ->
        [color, "runtime", level_part, ": ", :reset]
      {:user, :local_console} ->
        [:bright, "console", :reset, color, level_part, :reset, " | "]
      {:user, {:remote, :unknown}} ->
        [color, "remote user", color, level_part, ": ", :reset]
      {:user, {:remote, username}} when is_binary(username) ->
        [:italic, :blue, "~", username, :reset, color, level_part, ": ", :reset]
    end

    loc_part = if metadata[:module] do
      source_file = metadata[:module].module_info[:compile][:source]
      file_and_line = Exception.format_file_line(Path.relative_to_cwd(source_file), metadata[:line]) |> String.slice(0..-2)
      #{fn_name, arity} = metadata[:function]
      #["(from ", to_string(metadata[:module]), ".", to_string(fn_name), "/", to_string(arity), " in ", file_and_line, ")"]
      ["(", file_and_line, ")"]
    else
      []
    end

    [msg_first_ln|msg_detail_lns] = msg |> :erlang.iolist_to_binary |> String.split("\n")
    msg_detail_lns = msg_detail_lns |> Enum.map(fn(ln) -> ["    ", ln, "\n"] end)

    IO.ANSI.format_fragment([app_part, msg_first_ln, " ", :blue, loc_part, :reset, "\n", msg_detail_lns])
  end

  defp get_user(pid) do
    case Process.info(pid, :group_leader) do
      {:group_leader, pid_gl} ->
        tty_gl = local_tty_group_leader()

        if pid_gl == tty_gl do
          :local_console
        else
          {:remote, get_remote_user(pid_gl)}
        end

      nil -> {:remote, :unknown}
    end
  end

  defp local_tty_group_leader do
    case Process.get(:local_tty_group_leader) do
      :none -> nil
      nil ->
        new_value = read_local_tty_group_leader()
        Process.put(:local_tty_group_leader, new_value)
        new_value
      v -> v
    end
  end

  defp read_local_tty_group_leader do
    case Process.whereis(:user_drv) do
      nil -> :none
      tty_pid when is_pid(tty_pid) ->
        {:dictionary, d} = Process.info(tty_pid, :dictionary)
        Keyword.fetch!(d, :current_group)
    end
  end

  defp get_remote_user(gl_pid) when is_pid(gl_pid) do
    {:dictionary, d} = Process.info(gl_pid, :dictionary)
    Keyword.get(d, :remote_user, :unknown)
  end
end
