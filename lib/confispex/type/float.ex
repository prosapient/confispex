defmodule Confispex.Type.Float do
  @moduledoc """
  A float type.

  Casts input string to `Float`.

  No options.

  ## Examples

      iex> Confispex.Type.cast("3.14", Confispex.Type.Float)
      {:ok, 3.14}

      iex> Confispex.Type.cast("314", Confispex.Type.Float)
      {:ok, 314.0}

      iex> Confispex.Type.cast("1.0e2", Confispex.Type.Float)
      {:ok, 100.0}

      iex> Confispex.Type.cast("1.0ee2", Confispex.Type.Float)
      {:error,
       {"1.0ee2", Confispex.Type.Float, [parsing: ["unexpected substring ", {:highlight, ~s|"ee2"|}]]}}
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
