defmodule Confispex.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    Supervisor.start_link([Confispex.Server], strategy: :one_for_one, name: Confispex.Supervisor)
  end
end
