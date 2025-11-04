defmodule Confispex.Type.CSV do
  @moduledoc """
  A CSV type.

  Casts a CSV string to a list with values which are cast according to `:of` option.

  ### Options

  * `:of` - `Confispex.Type.String` is used by default.  Can be used any other type according to
  `t:Confispex.Type.type_reference/0`

  ## Examples

      iex> Confispex.Type.cast("John,user1@example.com", Confispex.Type.CSV)
      {:ok, ["John", "user1@example.com"]}

      iex> Confispex.Type.cast("John,user1@example.com", {Confispex.Type.CSV, of: Confispex.Type.Email})
      {:error,
       {"John,user1@example.com", {Confispex.Type.CSV, [of: Confispex.Type.Email]},
        [
          nested: [
            {"John", Confispex.Type.Email,
             [parsing: ["expected a string in format ", {:highlight, "username@host"}]]}
          ]
        ]}}

      iex> Confispex.Type.cast(~s|John,"user1@example.com|, Confispex.Type.CSV)
      {:error,
       {~s|John,"user1@example.com|, Confispex.Type.CSV,
        [parsing: ~s|expected escape character " but reached the end of file|]}}
  """
  @behaviour Confispex.Type

  @options_schema NimbleOptions.new!(
                    of: [
                      type: {:or, [:atom, {:tuple, [:atom, :keyword_list]}]},
                      required: false,
                      default: Confispex.Type.String
                    ]
                  )

  @impl true
  def cast(value, opts) when is_binary(value) do
    validated_opts = NimbleOptions.validate!(opts, @options_schema)

    with {:ok, line} <- parse_csv(value) do
      of = Keyword.fetch!(validated_opts, :of)

      results =
        Enum.map(line, fn value ->
          Confispex.Type.cast(value, of)
        end)

      case Enum.filter(results, &match?({:error, _}, &1)) do
        [] -> {:ok, Enum.map(results, &elem(&1, 1))}
        results -> {:error, nested: Enum.map(results, &elem(&1, 1))}
      end
    end
  end

  defp parse_csv(value) do
    case NimbleCSV.RFC4180.parse_string(value, skip_headers: false) do
      [] -> {:ok, []}
      [line] -> {:ok, line}
      _ -> {:error, validation: "expected a CSV with only 1 line"}
    end
  rescue
    e in NimbleCSV.ParseError ->
      {:error, parsing: Exception.message(e)}
  end
end
