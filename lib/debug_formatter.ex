defmodule PrettyConsole.DebugFormatter do
  @inspect_opts [
    width: 80,
    pretty: true,
    syntax_colors: [
      reset: [:reset, :yellow],
      atom: :cyan,
      string: :green,
      list: :default_color,
      boolean: :magenta,
      nil: :magenta,
      tuple: :default_color,
      binary: :default_color,
      map: :default_color
    ]
  ]

  @hidden_translation_req_annotation "_tr\e[0D\e[0D\e[0D"

  def format(level, msg, ts, metadata) do
    format_from_logger!(level, msg, ts, metadata)
  rescue e ->
    s = System.stacktrace
    exception_str = Exception.format(:throw, e, s)

    ["\n", :red, "could not format: #{inspect {level, msg, metadata}}\n", exception_str, "\n"]
    |> IO.ANSI.format()
  end

  def format_from_logger!(level, [@hidden_translation_req_annotation, _msg], ts, metadata), do:
    format_treq_from_metadata(level, ts, metadata)

  def format_from_logger!(level, msg, ts, metadata) do
    report = [
      report: {:text, msg},
      metadata: metadata ++ [level: level, timestamp: ts]
    ]

    [inspect(report, @inspect_opts), "\n"]
  end

  def format_from_replay!(replayed_log) when is_list(replayed_log) do
    [inspect(replayed_log, @inspect_opts), "\n"]
  end

  defp format_treq_from_metadata(level, ts, metadata) when is_list(metadata) do
    {translation_req, metadata} = Keyword.pop(metadata, :translation_req)

    metadata = metadata ++ [level: level, timestamp: ts]
    output = [report: translation_req, metadata: metadata]

    [inspect(output, @inspect_opts), "\n"]
  end
end
