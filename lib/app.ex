defmodule PrettyConsole do
  use Application

  def start(_type \\ :temporary, _args \\ []) do
    import Supervisor.Spec, warn: false

    children = []

    opts = [strategy: :one_for_one, name: PrettyConsole.Supervisor]
    {:ok, status} = Supervisor.start_link(children, opts)

    Logger.remove_backend :console
    Logger.add_backend PrettyConsole.Backend

    Logger.add_translator {PrettyConsole.Translator, :translate}

    {:ok, status}
  end
end
