defmodule Confispex.Type.Term do
  @moduledoc """
  Represents any term.

  Returns input.

  No options.

  ## Examples

      iex> Confispex.Type.cast("value", Confispex.Type.Term)
      {:ok, "value"}

      iex> Confispex.Type.cast("", Confispex.Type.Term)
      {:ok, ""}
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, _opts) do
    {:ok, value}
  end
end
