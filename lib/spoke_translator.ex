defmodule PrettyConsole.SpokeTranslator do
  def partially_translate(:text, text, metadata), do:
    {:ok, text, metadata}

  def partially_translate(:report, {:text, text}, metadata), do:
    {:ok, text, metadata}

  def partially_translate(:report, {{event_owner, event_type}, event_report}, metadata), do:
    partially_translate_report(event_type, event_report, metadata ++ [owner: event_owner])

  defp partially_translate_report(:progress, [application: app_name, started_at: node_name], metadata) do
    reply_with :app_started, [node: node_name, application: app_name], metadata
  end

  defp partially_translate_report(:child_started, [supervisor: supervisor_id, started: child], metadata) do
    child_pid = Keyword.fetch!(child, :pid)
    child_id = Keyword.get(child, :id, child_pid)
    child_mfa = Keyword.get(child, :mfargs) || Keyword.fetch!(child, :mfa)
    child_type = Keyword.get(child, :type, :worker)

    child_detail = process_detail(child_pid, child_id, child_mfa, type: child_type, parent: supervisor_id)

    metadata_from_child = Keyword.take(child_detail, [:pid, :application, :module, :function])

    reply_with {:child_started, child_detail}, metadata_from_child, metadata
  end

  defp partially_translate_report(:child_terminated, [supervisor: supervisor_id, errorContext: :child_terminated, reason: reason, offender: child], metadata) do
    child_pid = Keyword.fetch!(child, :pid)
    child_id = Keyword.get(child, :id, child_pid)
    child_mfa = Keyword.get(child, :mfargs) || Keyword.fetch!(child, :mfa)
    child_type = Keyword.get(child, :type, :worker)

    child_detail = process_detail(child_pid, child_id, child_mfa, type: child_type, parent: supervisor_id)

    metadata_from_child = Keyword.take(child_detail, [:pid, :application, :module, :function])

    reply_with {:child_exited, child_detail, reason}, metadata_from_child, metadata
  end

  defp partially_translate_report(:crash, [crash_report, _neighbour_reports], metadata) do
    child_pid = Keyword.fetch!(crash_report, :pid)
    child_mfa = Keyword.get(crash_report, :initial_call)
    child_id = Keyword.get(crash_report, :registered_name)
    error_info = Keyword.get(crash_report, :error_info)
    ancestor_pids = Keyword.get(crash_report, :ancestors, [])
    parent_id = List.last(ancestor_pids)

    child_detail = process_detail(child_pid, child_id, child_mfa, parent: parent_id)

    metadata_from_child = Keyword.take(child_detail, [:pid, :application, :module, :function])

    reply_with {:crashed, child_detail, error_info}, metadata_from_child, metadata
  end



  ## Helpers

  defp reply_with(event, new_metadata, old_metadata) do
    all_metadata = [partial_translation: event] ++ new_metadata ++ old_metadata
    {:ok, [], all_metadata}
  end

  def process_detail(pid, maybe_name, start_mfa, opts \\ []) do
    {start_mod, start_fun_name, start_args} = start_mfa
    start_fun_desc = {start_fun_name, Enum.count(start_args)}
    mfa_part = [module: start_mod, function: start_fun_desc]

    self_part = process_desc([pid, maybe_name, start_mod])

    parent_part = case opts[:parent] do
      nil -> []
      parent -> process_desc([parent])
    end

    app_part = case :application.get_application(pid) do
      {:ok, app_name} ->
        [application: app_name]

      :undefined ->
        case :application.get_application(start_mod) do
          {:ok, app_name} ->
            [application: app_name]

          :undefined ->
            []
        end
    end

    type_part = case opts[:type] do
      nil -> []
      type when is_atom(type) -> [type: type]
    end

    Enum.concat([self_part, type_part, mfa_part, parent_part, app_part])
  end

  def process_desc(parts) do
    parts
    |> Enum.flat_map(&normalize_process_desc_part/1)
    |> Enum.uniq()
  end

  defp normalize_process_desc_part({mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args), do:
    [module: mod, function: {fun, Enum.count(args)}] ++ normalize_process_desc_part(mod)
  defp normalize_process_desc_part({:via, _reg, part}), do: normalize_process_desc_part(part)
  defp normalize_process_desc_part({:global, part}), do: normalize_process_desc_part(part)
  defp normalize_process_desc_part({:local, part}), do: normalize_process_desc_part(part)
  defp normalize_process_desc_part(mod) when is_atom(mod) do
    case Process.whereis(mod) do
      pid when is_pid(pid) -> [pid: pid, name: mod]
      nil -> [name: mod]
    end
  end
  defp normalize_process_desc_part(pid) when is_pid(pid), do: [pid: pid]
  defp normalize_process_desc_part(_), do: []
end
