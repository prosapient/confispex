defmodule Confispex.Type.URL do
  @moduledoc """
  An URL type.

  Returns input string if it is a valid URL.

  ## Options

  This type has no options.

  ## Examples

      iex> Confispex.Type.cast("postgres://user@pass:host", Confispex.Type.URL)
      {:ok, "postgres://user@pass:host"}

      iex> Confispex.Type.cast("localhost", Confispex.Type.URL)
      {:error, {"localhost", Confispex.Type.URL, [validation: "missing a scheme (e.g. https)"]}}
  """
  @behaviour Confispex.Type

  @options_schema NimbleOptions.new!([])

  @impl true
  def cast(value, opts) when is_binary(value) do
    NimbleOptions.validate!(opts, @options_schema)

    case URI.parse(value) do
      %URI{scheme: nil} ->
        {:error, validation: "missing a scheme (e.g. https)"}

      %URI{host: host} when host in [nil, ""] ->
        {:error, validation: "missing a host"}

      %URI{query: query} when is_binary(query) ->
        try do
          URI.decode_query(query)
          {:ok, value}
        rescue
          ArgumentError ->
            {:error, parsing: "malformed query string"}
        end

      _ ->
        {:ok, value}
    end
  end
end
