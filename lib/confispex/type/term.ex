defmodule Confispex.Type.Term do
  @moduledoc """
  Represents any term.

  Returns input.

  No options.
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, _opts) do
    {:ok, value}
  end
end
