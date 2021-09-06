defmodule Confispex.Type.Email do
  @moduledoc """
  An email type.

  Returns input value if it is in `username@host` format.

  No options.

  ## Examples

      iex> Confispex.Type.cast("user@example.com", Confispex.Type.Email)
      {:ok, "user@example.com"}

      iex> Confispex.Type.cast("user[at]example.com", Confispex.Type.Email)
      {:error,
       {"user[at]example.com", Confispex.Type.Email,
        [parsing: ["expected a string in format ", {:highlight, "username@host"}]]}}
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
