defmodule Confispex.Type.Base64Encoded do
  @options_schema NimbleOptions.new!(
                    of: [
                      type: {:or, [:atom, {:tuple, [:atom, :keyword_list]}]},
                      required: false,
                      default: Confispex.Type.String,
                      doc:
                        "Type reference for casting decoded value. Can be a module or `{module, opts}` tuple. Defaults to `Confispex.Type.String`."
                    ]
                  )

  @moduledoc """
  A type for base64 encoded values.

  Decodes base64 encoded string.

  ## Options

  #{NimbleOptions.docs(@options_schema)}

  ## Examples

      iex> Confispex.Type.cast("aGVsbG8=", Confispex.Type.Base64Encoded)
      {:ok, "hello"}

      iex> Confispex.Type.cast("//8=", Confispex.Type.Base64Encoded)
      {:error, {<<255, 255>>, Confispex.Type.String, [validation: "not a valid string"]}}

      iex> Confispex.Type.cast("//8=", {Confispex.Type.Base64Encoded, of: Confispex.Type.Term})
      {:ok, <<0xFFFF::16>>}
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, opts) when is_binary(value) do
    validated_opts = NimbleOptions.validate!(opts, @options_schema)

    case Base.decode64(value) do
      {:ok, decoded_value} ->
        of = Keyword.fetch!(validated_opts, :of)
        Confispex.Type.cast(decoded_value, of)

      :error ->
        {:error, parsing: "not a base64 encoded string"}
    end
  end
end
