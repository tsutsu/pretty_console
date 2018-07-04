defmodule PrettyConsole.Translator do
  @hidden_translation_req_annotation "_tr\e[0D\e[0D\e[0D"

  def translate(min_level, level, kind, report) do
    new_metadata = [logger_min_level: min_level]

    {new_report, new_metadata} = translate_report(kind, report, new_metadata)

    new_metadata = [translation_req: new_report] ++ new_metadata

    {:ok, plaintext} = Logger.Translator.translate(min_level, level, kind, report)

    {:ok, [@hidden_translation_req_annotation, plaintext], new_metadata}
  end

  def translate_report(:report, {{progress_type, :progress}, progress_report}, metadata), do:
    translate_progress_report(progress_type, progress_report, metadata)

  def translate_report(:report, {{error_type, error}, error_report}, metadata), do:
    translate_error_report(error_type, error, error_report, metadata)

  def translate_report(kind, report, metadata) do
    {{kind, report}, metadata}
  end

  defp translate_progress_report(:application_controller, [application: app_name, started_at: node_name], metadata) do
    metadata = metadata ++ [node: node_name, application: app_name]
    {:app_started, metadata}
  end

  defp translate_progress_report(:supervisor, [supervisor: supervisor_id, started: child], metadata) do
    child_pid = Keyword.fetch!(child, :pid)
    child_id = Keyword.get(child, :id, child_pid)
    child_mfa = Keyword.get(child, :mfargs) || Keyword.fetch!(child, :mfa)
    child_type = Keyword.get(child, :type, :worker)

    supervisor_id = normalize_process_name(supervisor_id)
    child_id = normalize_process_name(child_id)

    {child_module, child_function_name, child_args} = child_mfa
    child_function = case child_args do
      :undefined -> {child_function_name, nil}
      args       -> {child_function_name, Enum.count(args)}
    end

    child_app = case :application.get_application(child_pid) do
      :undefined -> nil
      {:ok, app_name} -> app_name
    end

    child_desc = case {child_module, child_id} do
      {m, m} -> []
      {_m, nil} -> []
      {_m, name} when is_atom(name) -> [name: name]
    end

    child_desc = [child_module, type: child_type, parent: supervisor_id] ++ child_desc

    metadata = Keyword.merge(metadata,
      pid: child_pid,
      application: child_app,
      module: child_module,
      function: child_function
    )

    {{:child_started, child_desc}, metadata}
  end

  def translate_error_report(:supervisor, :child_terminated, [supervisor: supervisor_id, errorContext: :child_terminated, reason: reason, offender: child], metadata) do
    child_pid = Keyword.fetch!(child, :pid)
    child_id = Keyword.get(child, :id, child_pid)
    child_mfa = Keyword.get(child, :mfargs) || Keyword.fetch!(child, :mfa)
    child_type = Keyword.get(child, :type, :worker)

    supervisor_id = normalize_process_name(supervisor_id)
    child_id = normalize_process_name(child_id)

    {child_module, child_function_name, child_args} = child_mfa
    child_function = case child_args do
      :undefined -> {child_function_name, nil}
      args       -> {child_function_name, Enum.count(args)}
    end

    child_app = case :application.get_application(child_pid) do
      :undefined -> nil
      {:ok, app_name} -> app_name
    end

    child_desc = case {child_module, child_id} do
      {m, m} -> []
      {_m, nil} -> []
      {_m, name} when is_atom(name) -> [name: name]
    end

    child_desc = [child_module, type: child_type, parent: supervisor_id] ++ child_desc

    metadata = Keyword.merge(metadata,
      pid: child_pid,
      application: child_app,
      module: child_module,
      function: child_function
    )

    {{:child_exited, child_desc, reason}, metadata}
  end

  defp normalize_process_name({:local, proc_name}), do: normalize_process_name(proc_name)
  defp normalize_process_name(proc_name) when is_atom(proc_name), do: proc_name
  defp normalize_process_name(_proc_name), do: nil
end
