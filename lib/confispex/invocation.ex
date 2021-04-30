defmodule Confispex.Invocation do
  @moduledoc false
  defstruct [:in_schema, :in_store, :type_cast_errors, :value]

  @type t :: %__MODULE__{
          in_schema: :found | :not_found,
          in_store: :found | :not_found,
          type_cast_errors: [
            {source :: {:store, :original | {:alias, term()}} | :default,
             Confispex.Type.error_details()}
          ],
          value:
            {:store, term(), :original | {:alias, term()}} | {:default, term(), :schema | :system}
        }

  def new(variable_name, context, variables_store, variables_schema) do
    case Map.fetch(variables_schema, variable_name) do
      {:ok, variable_schema} ->
        with {:store, {:ok, value}} <- {:store, Access.fetch(variables_store, variable_name)},
             {:cast, {:ok, value}} <- {:cast, Confispex.Type.cast(value, variable_schema.cast)} do
          %Confispex.Invocation{
            in_schema: :found,
            in_store: :found,
            value: {:store, value, :original}
          }
        else
          {:store, :error} ->
            case find_value_in_aliases(variables_store, variable_schema) do
              nil ->
                %Confispex.Invocation{
                  in_schema: :found,
                  in_store: :not_found
                }
                |> set_default_value(variable_schema, context)

              {:ok, {alias_name, value}} ->
                %Confispex.Invocation{
                  in_schema: :found,
                  in_store: :found,
                  value: {:store, value, {:alias, alias_name}}
                }

              {:error, {alias_name, details}} ->
                %Confispex.Invocation{
                  in_schema: :found,
                  in_store: :found,
                  type_cast_errors: [{{:store, {:alias, alias_name}}, details}]
                }
                |> set_default_value(variable_schema, context)
            end

          {:cast, {:error, details}} ->
            %Confispex.Invocation{
              in_schema: :found,
              in_store: :found,
              type_cast_errors: [{{:store, :original}, details}]
            }
            |> set_default_value(variable_schema, context)
        end

      :error ->
        {in_store, value} =
          case Access.fetch(variables_store, variable_name) do
            {:ok, value} -> {:found, {:store, value, :original}}
            :error -> {:not_found, {:default, nil, :system}}
          end

        %Confispex.Invocation{
          in_schema: :not_found,
          in_store: in_store,
          value: value
        }
    end
  end

  defp find_value_in_aliases(variables_store, %{aliases: aliases} = variable_schema)
       when is_list(aliases) do
    Enum.find_value(aliases, fn alias_name ->
      with {:store, {:ok, value}} <- {:store, Access.fetch(variables_store, alias_name)},
           {:cast, {:ok, value}} <- {:cast, Confispex.Type.cast(value, variable_schema.cast)} do
        {:ok, {alias_name, value}}
      else
        {:store, :error} -> nil
        {:cast, {:error, details}} -> {:error, {alias_name, details}}
      end
    end)
  end

  defp find_value_in_aliases(_variables_store, _variable_schema), do: nil

  defp set_default_value(invocation, variable_schema, context) do
    variable_schema
    |> Map.fetch(:default)
    |> case do
      {:ok, _default_value} = result ->
        result

      :error ->
        case Map.fetch(variable_schema, :default_lazy) do
          {:ok, callback} -> {:ok, callback.(context)}
          :error -> :error
        end
    end
    |> case do
      {:ok, raw_default_value} ->
        case Confispex.Type.cast(raw_default_value, variable_schema.cast) do
          {:ok, value} ->
            %{invocation | value: {:default, value, :schema}}

          {:error, details} ->
            %{
              invocation
              | type_cast_errors: invocation.type_cast_errors ++ [default: details],
                value: {:default, nil, :system}
            }
        end

      :error ->
        %{invocation | value: {:default, nil, :system}}
    end
  end
end
