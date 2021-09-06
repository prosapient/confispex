defmodule Confispex.Type.Boolean do
  @moduledoc """
  A boolean type.

  Casts `"enabled"`, `"true"`, `"1"`, `"yes"`, `1`, `true` to `true`,
  and `"disabled"`, `"false"`, `"0"`, `"no"`, `0`, `false` to `false`.

  No options.

  ## Examples

      iex> Confispex.Type.cast("yes", Confispex.Type.Boolean)
      {:ok, true}

      iex> Confispex.Type.cast("true", Confispex.Type.Boolean)
      {:ok, true}

      iex> Confispex.Type.cast("0", Confispex.Type.Boolean)
      {:ok, false}

      iex> Confispex.Type.cast("disabled", Confispex.Type.Boolean)
      {:ok, false}

      iex> Confispex.Type.cast("DISABLED", Confispex.Type.Boolean)
      {
        :error,
        {"DISABLED", Confispex.Type.Boolean,
         [
           validation: [
             "expected one of: ",
             [
               {:highlight, "enabled"},
               ", ",
               {:highlight, "true"},
               ", ",
               {:highlight, "1"},
               ", ",
               {:highlight, "yes"},
               ", ",
               {:highlight, "disabled"},
               ", ",
               {:highlight, "false"},
               ", ",
               {:highlight, "0"},
               ", ",
               {:highlight, "no"}
             ]
           ]
         ]}
      }
  """
  @behaviour Confispex.Type

  @true_values ["enabled", "true", "1", "yes"]
  @false_values ["disabled", "false", "0", "no"]
  @impl true
  def cast(value, opts) when is_integer(value) or is_boolean(value) do
    cast(to_string(value), opts)
  end

  def cast(value, _opts) when is_binary(value) do
    cond do
      value in @true_values ->
        {:ok, true}

      value in @false_values ->
        {:ok, false}

      true ->
        {:error,
         validation: [
           "expected one of: ",
           Enum.map_intersperse(@true_values ++ @false_values, ", ", &{:highlight, &1})
         ]}
    end
  end
end
