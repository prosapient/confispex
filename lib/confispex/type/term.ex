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

  @options_schema NimbleOptions.new!([])

  @impl true
  def cast(value, opts) do
    NimbleOptions.validate!(opts, @options_schema)
    {:ok, value}
  end
end
