defmodule PrettyConsole.Translator do
  def translate(_min_level, :info, :report, {:progress, report}), do: translate_report(report)
  def translate(_min_level, _level, _kind, _message) do
    :none
  end

  defp translate_report([application: :logger, started_at: _node_name]), do: :skip
  defp translate_report([application: app_name, started_at: _node_name]) do
    {:ok, [["application", to_string(app_name)], IO.ANSI.format([
      :green, "started", :reset
    ])]}
  end

  defp translate_report([supervisor: {_sup_pid, sup_name}, started: child_report]) do
    case :application.get_application(child_report[:pid]) do
      :undefined -> :none
      {:ok, app_name} ->
        sup_name = sup_name |> normalize_name
        child_name = child_report[:name] |> normalize_name
        child_type = child_report[:child_type]
        child_mfa = child_report[:mfargs]
        translate_child_start_report(app_name, sup_name, child_name, child_type, child_mfa)
    end
  end

  defp translate_child_start_report(:logger, _, _, _, _), do: :skip
  defp translate_child_start_report(_, _, nil, _, _), do: :skip
  defp translate_child_start_report(app_name, _sup_name, child_name, child_type, {child_module, _child_fn, _child_args}) do
    child_name = to_string(child_name)
    child_module = to_string(child_module)
    child_type = to_string(child_type)

    child_name_part = if child_name == child_module do
      []
    else
      [" named ", :white, child_name, :reset]
    end

    {:ok, [["application", to_string(app_name)], IO.ANSI.format([
      "started a ", :white, child_module, :reset, " ", child_type,
      child_name_part
    ])]}
  end

  defp normalize_name({:local, proc_name}), do: proc_name
  defp normalize_name(proc_name) when is_atom(proc_name), do: proc_name
  defp normalize_name(_proc_name), do: nil
end
