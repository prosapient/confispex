defmodule Confispex.Type.String do
  @moduledoc """
  A string type.

  Returns input string if it is not empty.

  No options.

  ## Examples

      iex> Confispex.Type.cast("value", Confispex.Type.String)
      {:ok, "value"}

      iex> Confispex.Type.cast("", Confispex.Type.String)
      {:error, {"", Confispex.Type.String, [validation: "blank string"]}}

      iex> Confispex.Type.cast("value" <> <<0xFFFF::16>>, Confispex.Type.String)
      {:error, {"value" <> <<0xFFFF::16>>, Confispex.Type.String, [validation: "not a valid string"]}}
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, _opts) when is_binary(value) do
    case String.trim(value) do
      "" ->
        {:error, validation: "blank string"}

      value ->
        if String.valid?(value) do
          {:ok, value}
        else
          {:error, validation: "not a valid string"}
        end
    end
  end
end
