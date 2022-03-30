defmodule Confispex.Schema do
  @moduledoc """
  ## Example

      defmodule MyApp.RuntimeConfigSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema
        alias Confispex.Type

        defvariables(%{
          "RUNTIME_CONFIG_REPORT" => %{
            cast: {Type.Enum, values: ["disabled", "detailed", "brief"]},
            default: "disabled",
            groups: [:misc]
          },
          "TZDATA_AUTOUPDATE_ENABLED" => %{
            doc: "Autoupdate timezones from IANA Time Zone Database",
            cast: Type.Boolean,
            default: "false",
            groups: [:base],
            context: [env: [:dev, :prod]]
          },
          "LOG_LEVEL" => %{
            cast:
              {Type.Enum,
               values: [
                 "emergency",
                 "alert",
                 "critical",
                 "error",
                 "warning",
                 "notice",
                 "info",
                 "debug",
                 "none"
               ]},
            default_lazy: fn
              %{env: :test} -> "warning"
              %{env: :dev} -> "debug"
              %{env: :prod} -> "debug"
            end,
            groups: [:base]
          },
          "DATABASE_URL" => %{
            aliases: ["DB_URL"],
            doc: "Full DB URL",
            cast: Type.URL,
            context: [env: [:prod]],
            groups: [:primary_db],
            required: [:primary_db]
          },
          "DATABASE_POOL_SIZE" => %{
            aliases: ["DB_POOL_SIZE", "POOL_SIZE"],
            cast: {Type.Integer, scope: :positive},
            default: "10",
            context: [env: [:prod]],
            groups: [:primary_db]
          }
        })
      end
  """
  @type variable_name :: term()

  @typedoc """
  A spec for a single variable

  * `:cast` - describes how value should be cast.
  * `:groups` - a list of groups which are affected by variable.
  * `:doc` - a description about variable, shown in generated `.envrc` file.
  * `:default` - default value. Must be set in raw format. Raw format was choosen to populate `.envrc` file with default values.
  * `:default_lazy` - default value based on given context. Useful when default value must be different for different environments. Cannot be used alongside with `:default` parameter. Return `nil` if default value should be ignored.
  * `:template_value_generator` - a function that is used in `confispex.gen.envrc_template` mix task to generate a value for a variable. Such value will always be uncommented even if it is not required. This is useful for variables like "SECRET_KEY_BASE" which should be generated only once.
  * `:required` - a list of groups or a function that returns a list of groups in which variable is required. When all required variables of the group are cast successfully, then the group is considered as ready for using.
  * `:context` - specifies context in which variable is used.
  * `:aliases` - a list of alias names.
  """
  @type variable_spec :: %{
          required(:cast) => module() | {module(), opts :: keyword()},
          required(:groups) => [atom()],
          optional(:doc) => String.t(),
          optional(:default) => String.t(),
          optional(:default_lazy) => (Confispex.context() -> String.t() | nil),
          optional(:template_value_generator) => (() -> String.t()),
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
