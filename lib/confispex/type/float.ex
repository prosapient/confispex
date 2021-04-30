defmodule Confispex.Type.Float do
  @moduledoc """
  A float type.

  Casts input string to `Float`.

  No options.
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, _opts) when is_float(value) do
    {:ok, value}
  end

  def cast(value, _opts) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} ->
        {:ok, float}

      {_, remainder} ->
        {:error, parsing: ["unexpected substring ", {:highlight, inspect(remainder)}]}

      :error ->
        :error
    end
  end
end
