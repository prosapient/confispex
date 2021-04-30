defmodule Confispex.Type do
  @type type_reference :: module() | {module(), opts :: Keyword.t()}
  @type error_details :: [
          String.t()
          | error_details()
          | {:highlight | :validation | :parsing, error_details}
          | {:nested, [error_details]}
        ]
  @callback cast(value :: term(), opts :: Keyword.t()) ::
              {:ok, value :: term()} | :error | {:error, error_details}

  @doc """
  Cast `input` using type in `type_reference()`

  ## Examples

      iex> Confispex.Type.cast("dev", {Confispex.Type.Enum, values: [:prod, :test, :dev]})
      {:ok, "dev"}

      iex> Confispex.Type.cast("prodd", {Confispex.Type.Enum, values: [:prod, :test, :dev]})
      {:error,
       {"prodd", {Confispex.Type.Enum, [values: [:prod, :test, :dev]]},
        [
          validation: [
            "expected one of: ",
            [
              {:highlight, "prod"},
              ", ",
              {:highlight, "test"},
              ", ",
              {:highlight, "dev"}
            ]
          ]
        ]}}
  """
  @spec cast(input :: any(), type_reference()) ::
          {:ok, output :: any()}
          | {:error, {failed_on_value :: any(), type_reference(), error_details()}}
  def cast(value, type) do
    type
    |> case do
      type when is_atom(type) -> type.cast(value, [])
      {type, opts} -> type.cast(value, opts)
    end
    |> case do
      {:ok, value} ->
        {:ok, value}

      :error ->
        {:error, {value, type, []}}

      {:error, details} when is_list(details) ->
        {:error, {value, type, details}}

      {:error, nested_details} when is_tuple(nested_details) ->
        {:error, nested_details}
    end
  end
end
