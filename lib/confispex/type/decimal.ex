defmodule Confispex.Type.Decimal do
  @moduledoc """
  A decimal type.

  Casts input string to `Decimal`.

  No options.

  ## Examples

      iex> Confispex.Type.cast("3.14", Confispex.Type.Decimal)
      {:ok, Decimal.new("3.14")}

      iex> Confispex.Type.cast("1.0invalid", Confispex.Type.Decimal)
      {:error,
       {"1.0invalid", Confispex.Type.Decimal, [parsing: ["unexpected substring ", {:highlight, ~s|"invalid"|}]]}}
  """
  @behaviour Confispex.Type

  @impl true
  def cast(%Decimal{} = value, _opts) do
    {:ok, value}
  end

  def cast(value, _opts) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} ->
        {:ok, decimal}

      {_, remainder} ->
        {:error, parsing: ["unexpected substring ", {:highlight, inspect(remainder)}]}

      :error ->
        :error
    end
  end
end
