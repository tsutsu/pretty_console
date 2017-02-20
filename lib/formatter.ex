defmodule PrettyConsole.Formatter do
  def format({level, color}, msg, _ts, metadata) do
    {app_symbol, msg} = case msg do
      [["application", plain_app], str] ->
        {{:ok, plain_app}, str}

      str ->
        app_for_pid = case Keyword.fetch(metadata, :pid) do
          {:ok, pid} -> :application.get_application(pid)
          :error     -> :system
        end

        {app_for_pid, str}
    end

    level_part = case level do
      :info -> []
      level_name -> [" ", to_string(level_name)]
    end

    app_part = case app_symbol do
      {:ok, app} -> [color, "[", to_string(app), level_part, "] ", :reset]
      :system    ->
        [color, "runtime ", to_string(level), ": ", :reset]
      :undefined ->
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

