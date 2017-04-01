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
      nil     -> :user
      v       -> {:app, v}
    end

    app_part = case app_desc do
      {:app, app} -> [color, "[", to_string(app), level_part, "] ", :reset]
      :system ->
        [color, "runtime ", to_string(level), ": ", :reset]
      :user ->
        [color, "user ", to_string(level), ": ", :reset]
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
end

