defmodule Confispex.Type.JSON do
  @moduledoc """
  A JSON type.

  Casts JSON string to Elixir terms using `Jason` library.

  ### Options

  * `:keys` - possible values are: `:strings` (default), `:atoms`, `:atoms!`.
  Read about meaning of this values in doc for `Jason.decode/2`.
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, opts) when is_binary(value) do
    keys = Keyword.get(opts, :keys, :strings)

    case Jason.decode(value, keys: keys) do
      {:ok, result} -> {:ok, result}
      {:error, exception} -> {:error, parsing: Exception.message(exception)}
    end
  end
end
