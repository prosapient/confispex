defmodule Confispex.Schema do
  @moduledoc """
  Defines the behavior and helpers for creating configuration schemas.

  A schema describes all environment variables your application uses, their types,
  defaults, validation rules, and how they're organized into logical groups.

  ## Basic Usage

      defmodule MyApp.RuntimeConfigSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema
        alias Confispex.Type

        defvariables(%{
          "DATABASE_URL" => %{
            cast: Type.URL,
            groups: [:database],
            required: [:database]
          }
        })
      end

  ## Variable Specification

  Each variable is defined with a map containing the following options:

  ### Required Options

  * `:cast` - type specification for casting the value. Can be:
    - A module implementing `Confispex.Type` behavior (e.g., `Type.String`)
    - A tuple with module and options (e.g., `{Type.Integer, scope: :positive}`)

  * `:groups` - list of group atoms this variable belongs to. Groups are used for:
    - Organizing variables in reports
    - Checking if a feature is properly configured via `all_required_touched?/1`
    - Conditional configuration based on `any_required_touched?/1`

  ### Optional Options

  * `:doc` - human-readable description shown in generated `.envrc` template files

  * `:default` - default value as a string. Used when variable is not present in the store.
    Cannot be used with `:required` or `:default_lazy`.

        "PORT" => %{
          cast: Type.Integer,
          default: "4000",
          groups: [:server]
        }

  * `:default_lazy` - function `(context -> String.t() | nil)` for context-dependent defaults.
    Receives runtime context (e.g., `%{env: :prod, target: :host}`) and returns default value
    or `nil` to skip default. Cannot be used with `:default`.

        "LOG_LEVEL" => %{
          cast: {Type.Enum, values: ["debug", "info", "warning", "error"]},
          default_lazy: fn
            %{env: :prod} -> "warning"
            %{env: :dev} -> "debug"
            _ -> "info"
          end,
          groups: [:logging]
        }

  * `:required` - marks variable as required in specific groups. Can be:
    - List of group atoms (e.g., `[:database, :cache]`)
    - Function `(context -> [atom()])` for context-dependent requirements

    When all required variables in a group are present and valid, the group is considered
    ready for use. Cannot be used with `:default`.

        "DATABASE_URL" => %{
          cast: Type.URL,
          groups: [:database],
          required: [:database]  # Required when using :database group
        }

  * `:context` - keyword list specifying when this variable should be included in the schema.
    Variables outside their context are filtered out completely.

        "DATABASE_URL" => %{
          cast: Type.URL,
          context: [env: [:prod]],  # Only in production
          groups: [:database]
        }

  * `:aliases` - list of alternative names for this variable. Confispex will try each name
    in order until it finds a value in the store.

        "DATABASE_URL" => %{
          aliases: ["DB_URL", "DATABASE_CONNECTION"],
          cast: Type.URL,
          groups: [:database]
        }

  * `:template_value_generator` - function `(-> String.t())` that generates a value for
    `.envrc` template. Useful for secrets that should be generated once.

        "SECRET_KEY_BASE" => %{
          cast: Type.String,
          template_value_generator: fn -> :crypto.strong_rand_bytes(64) |> Base.encode64() end,
          groups: [:security]
        }

  ## Complete Example

      defmodule MyApp.RuntimeConfigSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema
        alias Confispex.Type

        defvariables(%{
          # Simple required variable
          "DATABASE_URL" => %{
            aliases: ["DB_URL"],
            doc: "PostgreSQL connection URL",
            cast: Type.URL,
            context: [env: [:prod]],
            groups: [:database],
            required: [:database]
          },

          # Variable with default
          "DATABASE_POOL_SIZE" => %{
            aliases: ["POOL_SIZE"],
            cast: {Type.Integer, scope: :positive},
            default: "10",
            context: [env: [:prod]],
            groups: [:database]
          },

          # Context-dependent default
          "LOG_LEVEL" => %{
            cast: {Type.Enum, values: ["debug", "info", "warning", "error"]},
            default_lazy: fn
              %{env: :test} -> "warning"
              %{env: :dev} -> "debug"
              %{env: :prod} -> "info"
            end,
            groups: [:logging]
          },

          # Generated secret
          "SECRET_KEY_BASE" => %{
            cast: Type.String,
            template_value_generator: fn ->
              :crypto.strong_rand_bytes(64) |> Base.encode64()
            end,
            groups: [:security],
            required: [:security]
          }
        })
      end
  """

  @typedoc """
  Name of a configuration variable.

  Typically a string representing an environment variable name (e.g., `"DATABASE_URL"`),
  but can be any term.
  """
  @type variable_name :: term()

  @typedoc """
  Specification for a single configuration variable.

  See the module documentation for detailed explanation of each option.
  """
  @type variable_spec :: %{
          required(:cast) => module() | {module(), opts :: keyword()},
          required(:groups) => [atom()],
          optional(:doc) => String.t(),
          optional(:default) => String.t(),
          optional(:default_lazy) => (Confispex.context() -> String.t() | nil),
          optional(:template_value_generator) => (-> String.t()),
          optional(:required) => [atom()] | (Confispex.context() -> [atom()]),
          optional(:context) => [{atom(), atom()}],
          optional(:aliases) => [variable_name()]
        }
  @callback variables_schema() :: %{variable_name() => variable_spec()}

  @doc """
  A helper which performs basic validations of the input schema and then defines `variables_schema/0` function.
  """
  defmacro defvariables(variables) do
    quote do
      validate_variables!(unquote(variables))

      @impl unquote(__MODULE__)
      def variables_schema do
        unquote(variables)
      end
    end
  end

  @doc false
  def validate_variables!(variables) when is_map(variables) do
    Enum.each(variables, fn {variable_name, spec} ->
      assert(spec[:cast], "param :cast is required", variable_name)
      assert(spec[:groups], "param :groups is required", variable_name)
      assert(is_list(spec[:groups]), "param :groups must be a list", variable_name)

      assert(
        is_nil(spec[:default]) or is_nil(spec[:default_lazy]),
        "param :default cannot be used with :default_lazy",
        variable_name
      )

      assert(
        is_nil(spec[:required]) or is_nil(spec[:default]),
        "param :default cannot be used with :required",
        variable_name
      )

      assert(
        not Map.has_key?(spec, :required) or is_list(spec.required) or
          is_function(spec.required, 1),
        "param :required must be a list or function with arity 1",
        variable_name
      )

      assert(
        not Map.has_key?(spec, :aliases) or is_list(spec.aliases),
        "param :aliases must be a list",
        variable_name
      )

      assert(
        not Map.has_key?(spec, :template_value_generator) or
          is_function(spec.template_value_generator, 0),
        "param :template_value_generator must be a function with arity 0",
        variable_name
      )

      assert(
        not Map.has_key?(spec, :default_lazy) or
          is_function(spec.default_lazy, 1),
        "param :default_lazy must be a function with arity 1",
        variable_name
      )
    end)
  end

  defp assert(condition, msg, variable_name) do
    if condition do
      :ok
    else
      raise ArgumentError, "Assertion failed for #{variable_name}: " <> msg
    end
  end

  @doc false
  def variable_required?(spec, group, context) do
    case spec[:required] do
      nil -> false
      required when is_list(required) -> group in required
      required when is_function(required, 1) -> group in required.(context)
    end
  end

  @doc false
  def variables_in_context(variables_schema, context) do
    Enum.filter(variables_schema, fn {_variable_name, spec} -> spec_in_context?(spec, context) end)
  end

  defp spec_in_context?(spec, context) do
    case Map.fetch(spec, :context) do
      {:ok, context_spec} ->
        Enum.all?(context_spec, fn {context_key, allowed_values} ->
          Map.fetch!(context, context_key) in allowed_values
        end)

      :error ->
        true
    end
  end

  @doc false
  def grouped_variables(variables_schema) do
    variables_schema
    |> Enum.flat_map(fn {_variable_name, spec} = item ->
      Enum.map(spec.groups, &{&1, item})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
end
