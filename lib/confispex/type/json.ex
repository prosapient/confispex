defmodule Confispex.Type.JSON do
  @moduledoc """
  A JSON type.

  Casts JSON string to Elixir terms using `Jason` library.

  ### Options

  * `:keys` - possible values are: `:strings` (default), `:atoms`, `:atoms!`.
  Read about meaning of this values in doc for `Jason.decode/2`.

  ## Examples

      iex> Confispex.Type.cast(~s|[{"email":"john@example.com","level":1}]|, Confispex.Type.JSON)
      {:ok, [%{"email" => "john@example.com", "level" => 1}]}

      iex> Confispex.Type.cast(~s|[{"email":"john@example.com","level":1}]|, {Confispex.Type.JSON, keys: :atoms})
      {:ok, [%{email: "john@example.com", level: 1}]}

      iex> Confispex.Type.cast("", Confispex.Type.JSON)
      {:error, {"", Confispex.Type.JSON, [parsing: "unexpected end of input at position 0"]}}
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
