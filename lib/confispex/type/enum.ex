defmodule Confispex.Type.Enum do
  @moduledoc """
  An enum type.

  Returns input value if it is present in a list specified in `:values` option.

  ### Options

  * `:values` - required option, can be a list of any values which implement `String.Chars` protocol.
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, opts) when is_binary(value) do
    values = opts |> Keyword.fetch!(:values) |> Enum.map(&to_string/1)

    if value in values do
      {:ok, value}
    else
      {:error,
       validation: ["expected one of: ", Enum.map_intersperse(values, ", ", &{:highlight, &1})]}
    end
  end
end
