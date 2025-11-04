defmodule Confispex.Type.JSON do
  @options_schema NimbleOptions.new!(
                    keys: [
                      type: {:in, [:strings, :atoms, :atoms!]},
                      required: false,
                      default: :strings,
                      doc: """
                      How to handle map keys. Options:
                      * `:strings` - keys remain as strings (default)
                      * `:atoms` - converts keys to existing atoms only (safe)
                      * `:atoms!` - converts keys to atoms, creating new atoms if needed (use with caution)
                      """
                    ]
                  )

  @moduledoc """
  A JSON type.

  Casts JSON string to Elixir terms using built-in `JSON` module.

  ## Options

  #{NimbleOptions.docs(@options_schema)}

  ## Examples

      iex> Confispex.Type.cast(~s|[{"email":"john@example.com","level":1}]|, Confispex.Type.JSON)
      {:ok, [%{"email" => "john@example.com", "level" => 1}]}

      iex> Confispex.Type.cast(~s|[{"email":"john@example.com","level":1}]|, {Confispex.Type.JSON, keys: :atoms})
      {:ok, [%{email: "john@example.com", level: 1}]}

      iex> Confispex.Type.cast("", Confispex.Type.JSON)
      {:error, {"", Confispex.Type.JSON, [parsing: "unexpected end of input at position 0"]}}
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, opts) when is_binary(value) do
    validated_opts = NimbleOptions.validate!(opts, @options_schema)
    keys = Keyword.fetch!(validated_opts, :keys)

    with {:ok, result} <- JSON.decode(value) do
      {:ok, convert_keys(result, keys)}
    else
      {:error, reason} -> {:error, parsing: format_error(reason)}
    end
  end

  defp convert_keys(value, :strings), do: value

  defp convert_keys(value, :atoms) when is_map(value) do
    Map.new(value, fn {k, v} ->
      {String.to_existing_atom(k), convert_keys(v, :atoms)}
    end)
  rescue
    ArgumentError -> value
  end

  defp convert_keys(value, :atoms!) when is_map(value) do
    Map.new(value, fn {k, v} -> {String.to_atom(k), convert_keys(v, :atoms!)} end)
  end

  defp convert_keys(value, keys) when is_list(value) do
    Enum.map(value, &convert_keys(&1, keys))
  end

  defp convert_keys(value, _keys), do: value

  defp format_error({:unexpected_end, offset}),
    do: "unexpected end of input at position #{offset}"

  defp format_error({:invalid_byte, offset, byte}),
    do: "invalid byte #{inspect(byte)} at position #{offset}"

  defp format_error({:unexpected_sequence, offset, bytes}),
    do: "unexpected sequence #{inspect(bytes)} at position #{offset}"
end
