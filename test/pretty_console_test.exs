defmodule PrettyConsole.Tests do
  use ExUnit.Case, async: true

  @moduletag capture_log: false

  require Logger

  @multibyte_string "多字節字符的長序列"

  test "multibyte input" do
    Logger.debug(@multibyte_string)
  end

  @default_logger_trunc_bound 8192

  test "long multibyte input" do
    bound_breaking_msg = make_bound_breaking_msg()

    Logger.debug(bound_breaking_msg)

    # shift the three-byte chars over by one and two bytes
    Logger.debug(["a", bound_breaking_msg])
    Logger.debug(["a", "b", bound_breaking_msg])
  end

  test "long multibyte input in crash report" do
    bound_breaking_msg = make_bound_breaking_msg()
    :proc_lib.spawn(fn -> :nonexistent.call(bound_breaking_msg) end)
  end

  defp make_bound_breaking_msg do
    repetitions_to_pass_bound = trunc(@default_logger_trunc_bound / byte_size(@multibyte_string)) + 1
    List.duplicate(@multibyte_string, repetitions_to_pass_bound)
  end
end
