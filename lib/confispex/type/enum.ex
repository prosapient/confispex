defmodule Confispex.Type.Enum do
  @moduledoc """
  An enum type.

  Returns input value if it is present in a list specified in `:values` option.

  ### Options

  * `:values` - required option, can be a list of any values which implement `String.Chars` protocol.

  ## Examples

      iex> Confispex.Type.cast("low", {Confispex.Type.Enum, values: ["low", "high"]})
      {:ok, "low"}

      iex> Confispex.Type.cast("LOW", {Confispex.Type.Enum, values: ["low", "high"]})
      {:error,
       {"LOW", {Confispex.Type.Enum, [values: ["low", "high"]]},
        [validation: ["expected one of: ", [{:highlight, "low"}, ", ", {:highlight, "high"}]]]}}
  """
  @behaviour Confispex.Type

  @options_schema NimbleOptions.new!(values: [type: {:list, :any}, required: true])

  @impl true
  def cast(value, opts) when is_binary(value) do
    validated_opts = NimbleOptions.validate!(opts, @options_schema)
    values = validated_opts |> Keyword.fetch!(:values) |> Enum.map(&to_string/1)

    if value in values do
      {:ok, value}
    else
      {:error,
       validation: ["expected one of: ", Enum.map_intersperse(values, ", ", &{:highlight, &1})]}
    end
  end
end
