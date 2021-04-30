defmodule Confispex.Type.Email do
  @moduledoc """
  An email type.

  Returns input value if it is in `username@host` format.

  No options.
  """
  @behaviour Confispex.Type

  @impl true
  def cast(value, _opts) when is_binary(value) do
    case String.split(value, "@") do
      [username, host] when username != "" and host != "" ->
        {:ok, value}

      _ ->
        {:error, parsing: ["expected a string in format ", {:highlight, "username@host"}]}
    end
  end
end
