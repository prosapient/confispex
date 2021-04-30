defmodule Confispex.Type.CSV do
  @moduledoc """
  A CSV type.

  Casts a CSV string to a list with values which are cast according to `:of` option.

  ### Options

  * `:of` - `Confispex.Type.String` is used by default.  Can be used any other type according to
  `t:Confispex.Type.type_reference/0`
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, opts) when is_binary(value) do
    with {:ok, line} <- parse_csv(value) do
      of = Keyword.get(opts, :of, Confispex.Type.String)

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
