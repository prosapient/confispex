defmodule Confispex.Type.Base64Encoded do
  @moduledoc """
  A type for base64 encoded values.

  Decodes base64 encoded string into a string.

  ### Options

  * `:of` - `Confispex.Type.String` is used by default.  Can be used any other type according to
  `t:Confispex.Type.type_reference/0`
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, opts) when is_binary(value) do
    case Base.decode64(value) do
      {:ok, decoded_value} ->
        of = Keyword.get(opts, :of, Confispex.Type.String)
        Confispex.Type.cast(decoded_value, of)

      :error ->
        {:error, parsing: "not a base64 encoded string"}
    end
  end
end
