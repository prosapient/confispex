defmodule Confispex.Type do
  @moduledoc """
  Defines the behavior for type casting in Confispex.

  All configuration values start as strings (from environment variables) and need to be
  cast to appropriate Elixir types. This module defines the behavior for type casting
  and provides several built-in type implementations.

  ## Built-in Types

  Confispex provides the following built-in types:

  - `Confispex.Type.Boolean` - casts to boolean (`true`/`false`)
  - `Confispex.Type.Integer` - casts to integer with optional scope (`:positive`)
  - `Confispex.Type.Float` - casts to float
  - `Confispex.Type.String` - validates non-empty strings
  - `Confispex.Type.Enum` - validates value against allowed list
  - `Confispex.Type.Email` - basic email format validation
  - `Confispex.Type.URL` - URL format validation
  - `Confispex.Type.CSV` - parse CSV strings with nested type support
  - `Confispex.Type.JSON` - parse JSON objects with atom/string key conversion
  - `Confispex.Type.Base64Encoded` - decode base64 and cast with nested type
  - `Confispex.Type.Term` - evaluate Elixir terms from strings

  ## Using Types in Schema

  Types can be referenced as a module or as a tuple with options:

      defvariables(%{
        "PORT" => %{
          cast: Confispex.Type.Integer,  # Simple reference
          groups: [:server]
        },
        "LOG_LEVEL" => %{
          cast: {Confispex.Type.Enum, values: ["debug", "info", "warning", "error"]},  # With options
          groups: [:logging]
        }
      })

  ## Creating Custom Types

  To create a custom type, implement the `Confispex.Type` behavior:

      defmodule MyApp.PortType do
        @behaviour Confispex.Type

        @impl true
        def cast(value, _opts) when is_binary(value) do
          case Integer.parse(value) do
            {port, ""} when port >= 1 and port <= 65535 ->
              {:ok, port}

            _ ->
              {:error, ["expected a valid port number (1-65535)"]}
          end
        end

        def cast(_value, _opts) do
          {:error, ["expected a string"]}
        end
      end

  Then use it in your schema:

      defvariables(%{
        "PORT" => %{
          cast: MyApp.PortType,
          groups: [:server]
        }
      })

  ## Error Details Structure

  Error details use a tagged structure for rich error reporting with ANSI colors.
  The structure is a list that can contain strings and tagged tuples.

  ### Available Tags

  - `String` - plain error message, rendered as-is

        {:error, ["value must be a positive number"]}

  - `{:highlight, text}` - highlighted values (rendered in light cyan, typically used
    for showing valid options or values)

        {:error, [
          "expected one of: ",
          {:highlight, "prod"},
          ", ",
          {:highlight, "dev"},
          ", ",
          {:highlight, "test"}
        ]}

  - `{:validation, details}` - validation error section (prefixed with "Validation failed: "
    in light red). Use this when the input format is correct but doesn't meet business rules
    or constraints.

        # Example: Value was successfully parsed as integer, but doesn't meet range requirement
        {:error, [
          {:validation, ["port must be between 1 and 65535"]}
        ]}

  - `{:parsing, details}` - parsing error section (prefixed with "Parsing failed: " in
    light red). Use this when the input cannot be converted to the expected type or format.

        # Example: Value cannot be parsed as an integer at all
        {:error, [
          {:parsing, ["failed to parse integer from ", {:highlight, "abc123"}]}
        ]}

  - `{:nested, [details]}` - nested type errors (used when a collection type like CSV
    needs to report errors from multiple items). Rendered with "Casting nested elements
    failed: " header in light red. The `details` list contains full error tuples from
    inner types: `{value, type, error_details}`.

        # Example: CSV type trying to parse a list of emails, where one email is invalid
        {:error,
         {"admin@,user", {Confispex.Type.CSV, [of: Confispex.Type.Email]},
          [
            nested: [
              {"admin@", Confispex.Type.Email,
               [validation: ["incomplete email address"]]}
            ]
          ]}}

  ### When to Use `:nested`

  Use `:nested` when your type needs to report errors from multiple items or add context
  about WHERE the error occurred in a complex structure.

  Main use case: **Collection types** - when validating multiple items (like CSV):

      # Real example from Confispex.Type.CSV implementation
      results =
        Enum.map(items, fn item ->
          Confispex.Type.cast(item, inner_type)
        end)

      case Enum.filter(results, &match?({:error, _}, &1)) do
        [] ->
          {:ok, Enum.map(results, &elem(&1, 1))}

        errors ->
          {:error, nested: Enum.map(errors, &elem(&1, 1))}
      end

      # This allows reporting ALL failed items at once, not just the first one

  Another use case: **Adding context** - when you want to add information about where
  the error occurred. Note: This is less common - usually you'd just pass the error through.

      # Example: Adding context to an inner type's error (rarely needed)
      case Confispex.Type.cast(value, inner_type) do
        {:ok, result} ->
          {:ok, result}

        {:error, {failed_value, type, details}} ->
          # Wrap the error to add context
          {:error, nested: [{failed_value, type, ["in field 'port': " | details]}]}
      end

  ### Parsing vs Validation

  Understanding when to use `:parsing` vs `:validation`:

  `:parsing` - structural/format errors (cannot convert to target type):
  - `"abc"` → Integer (not a number at all)
  - `"not-an-email"` → Email (doesn't contain @)
  - `"not-json"` → JSON (invalid JSON syntax)
  - `"invalid-base64!@#"` → Base64 (invalid base64 characters)

  `:validation` - business rule errors (converted successfully but doesn't meet constraints):
  - `"99999"` → Integer with scope :positive and max 65535 (too large)
  - `"staging"` → Enum with values ["dev", "prod"] (not in allowed list)
  - `"user@"` → Email (has @ but incomplete)
  - `"-5"` → Integer with scope :positive (negative number)

  ### Complex Example

  Here's a real-world error from CSV type with nested Email validation:

      # When CSV is parsed successfully, but one of the emails inside is invalid
      {:error,
       {"John,user1@example.com", {Confispex.Type.CSV, [of: Confispex.Type.Email]},
        [
          nested: [
            {"John", Confispex.Type.Email,
             [parsing: ["expected a string in format ", {:highlight, "username@host"}]]}
          ]
        ]}}

  This shows:
  1. CSV was parsed successfully (no `:parsing` error at top level)
  2. Inside the CSV (`:nested`), one item failed: `"John"`
  3. That item failed Email type's parsing (`:parsing`) - doesn't match email format
  4. The nested error is a full error tuple: `{value, type, details}`

  Note: If CSV itself fails to parse, you get `:parsing` instead of `:nested`:

      # When CSV structure is broken (e.g., unclosed quotes)
      {:error, [
        {:parsing, ["expected escape character \" but reached the end of file"]}
      ]}

  The type returns either `:parsing` (own error) or `:nested` (inner type error),
  never both at the same time.

  ### ANSI Color Reference

  When rendered in terminal reports:
  - `:highlight` tags - light cyan
  - `:validation` and `:parsing` prefixes - light red
  - `:nested` header - light red
  """

  @typedoc """
  A type specification for casting configuration values.

  Can be either:
  - A module implementing `Confispex.Type` behavior (e.g., `Confispex.Type.String`)
  - A tuple with module and options (e.g., `{Confispex.Type.Integer, scope: :positive}`)
  """
  @type type_reference :: module() | {module(), opts :: Keyword.t()}

  @typedoc """
  Structured error details returned when type casting fails.

  Supports nested structures with formatting hints for terminal output.
  """
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
