defmodule Confispex.Type.URL do
  @moduledoc """
  An URL type.

  Returns input string if it is a valid URL.

  No options.
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, _opts) when is_binary(value) do
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
