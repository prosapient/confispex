defmodule Confispex.Type.Integer do
  @moduledoc """
  An integer type.

  Casts input string to `Integer`.

  ### Options

  * `:scope` - can be `:positive`, requires parsed integer value to be > 0

  ## Examples

      iex> Confispex.Type.cast("-42", Confispex.Type.Integer)
      {:ok, -42}

      iex> Confispex.Type.cast("-42", {Confispex.Type.Integer, scope: :positive})
      {:error, {"-42", {Confispex.Type.Integer, [scope: :positive]}, [validation: "expected a positive integer"]}}

      iex> Confispex.Type.cast("42 monkeys", Confispex.Type.Integer)
      {:error,
       {"42 monkeys", Confispex.Type.Integer,
        [parsing: ["unexpected substring ", {:highlight, ~s|" monkeys"|}]]}}
  """
  @behaviour Confispex.Type

  @options_schema NimbleOptions.new!(scope: [type: {:in, [:positive]}, required: false])

  @impl true

  def cast(value, opts) when is_integer(value) do
    cast(to_string(value), opts)
  end

  def cast(value, opts) when is_binary(value) do
    validated_opts = NimbleOptions.validate!(opts, @options_schema)
    do_cast(value, validated_opts)
  end

  defp do_cast(value, opts) do
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
