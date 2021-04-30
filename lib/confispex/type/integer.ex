defmodule Confispex.Type.Integer do
  @moduledoc """
  An integer type.

  Casts input string to `Integer`.

  ### Options

  * `:scope` - can be `:positive`, requires parsed integer value to be > 0
  """
  @behaviour Confispex.Type

  @impl true

  def cast(value, opts) when is_integer(value) do
    cast(to_string(value), opts)
  end

  def cast(value, opts) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} ->
        if Keyword.get(opts, :scope) == :positive and integer <= 0 do
          {:error, validation: "expected a positive integer"}
        else
          {:ok, integer}
        end

      {_, remainder} ->
        {:error, parsing: ["unexpected substring ", {:highlight, inspect(remainder)}]}

      :error ->
        :error
    end
  end
end
