defmodule PrettyConsole.HubTranslator do
  alias PrettyConsole.SpokeTranslator

  @hidden_translation_req_annotation "_tr\e[0D\e[0D\e[0D"

  def losslessly_translate(min_level, level, kind, report) do
    new_metadata = [
      translation_req: {kind, report},
      logger_min_level: min_level,
      logger_level: level
    ]

    {:ok, plaintext} = Logger.Translator.translate(min_level, level, kind, report)

    {:ok, [@hidden_translation_req_annotation, plaintext], new_metadata}
  end

  def lossfully_translate(min_level, level, kind, report) do
    new_metadata = [
      translation_req: {kind, report},
      logger_min_level: min_level,
      logger_level: level
    ]

    case Logger.compare_levels(min_level, level) do
      :gt -> :skip
      _ -> SpokeTranslator.partially_translate(kind, report, new_metadata)
    end
  end

  def decode_report(report, metadata) do
    case Keyword.fetch(metadata, :translation_req) do
      {:ok, kind_and_report} -> kind_and_report
      :error -> {:text, report}
    end
  end
end
