defmodule Confispex.Type.String do
  @moduledoc """
  A string type.

  Returns input string if it is not empty.

  No options.
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
