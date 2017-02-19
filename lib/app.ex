defmodule PrettyConsole do
  def install do
    Logger.remove_backend :console
    Logger.add_backend PrettyConsole.Backend

    Logger.add_translator {PrettyConsole.Translator, :translate}
  end
end
