defmodule Mix.Tasks.Confispex.Gen.Doc.Md do
  use Mix.Task

  @shortdoc "Generate Markdown documentation from schema"

  @moduledoc """
  Generates a Markdown documentation file listing all configuration variables
  from your schema in a human-readable table format.

  Perfect for:
  - Project README files
  - Deployment documentation
  - Onboarding new team members
  - CI/CD pipeline documentation

  The generated document includes tables organized by groups showing:
  - Variable names
  - Required/optional status
  - Default values
  - Descriptions from `:doc` fields

  ## Options

  - `--schema` - (required) the module name of your schema (e.g., `MyApp.RuntimeConfigSchema`)
  - `--output` - (required) path to output file (e.g., `RUNTIME_CONFIG.md`)
  - `--env` - (optional) environment context (e.g., `prod`, `dev`, `test`)
  - `--target` - (optional) target context (e.g., `host`, `docker`)

  ## Examples

      # Generate docs for production environment
      $ mix confispex.gen.doc.md \\
          --schema=MyApp.RuntimeConfigSchema \\
          --output=docs/PRODUCTION_CONFIG.md \\
          --env=prod \\
          --target=host

      # Generate docs for development
      $ mix confispex.gen.doc.md \\
          --schema=MyApp.RuntimeConfigSchema \\
          --output=README_CONFIG.md \\
          --env=dev

  ## Example Output

      # Variables (env=prod target=host)

      ## GROUP :database

      | Name          | Required | Default   | Description            |
      | ------------- | -------- | --------- | ---------------------- |
      | DATABASE_URL  | required |           | PostgreSQL connection  |
      | DATABASE_POOL |          | 10        | Connection pool size   |

      ## GROUP :cache

      | Name       | Required | Default     | Description       |
      | ---------- | -------- | ----------- | ----------------- |
      | REDIS_URL  | required |             | Redis connection  |

  ## Context-Aware Documentation

  The generated documentation respects context filters in your schema. Variables
  marked with `context: [env: [:prod]]` will only appear in documentation generated
  with `--env=prod`.
  """
  @requirements ["app.config"]

  def run(args) do
    {opts, []} =
      OptionParser.parse!(args,
        switches: [env: :string, target: :string, output: :string, schema: :string]
      )

    output_path = Keyword.fetch!(opts, :output)
    schema = Keyword.fetch!(opts, :schema)

    schema = Module.concat([schema])

    env =
      case opts[:env] do
        nil -> Mix.env()
        value -> String.to_existing_atom(value)
      end

    target =
      case opts[:target] do
        nil -> Mix.target()
        value -> String.to_existing_atom(value)
      end

    context = %{env: env, target: target}

    iodata =
      schema.variables_schema()
      |> Confispex.Schema.variables_in_context(context)
      |> Confispex.Schema.grouped_variables()
      |> Enum.sort_by(fn {group_name, _variables} -> group_name end)
      |> Enum.flat_map(fn {group_name, variables} ->
        [
          "## GROUP #{inspect(group_name)}",
          variables
          |> Enum.sort_by(fn {variable_name, definition} ->
            # required first, then sort by name
            {not Confispex.Schema.variable_required?(definition, group_name, context),
             variable_name}
          end)
          |> Enum.map(fn {variable_name, definition} ->
            doc =
              case definition do
                %{doc: doc} when is_binary(doc) ->
                  String.replace(definition.doc, "\n", "")

                _ ->
                  ""
              end

            default =
              case definition do
                %{default: default} -> default
                %{default_lazy: callback} -> context |> callback.()
                _ -> nil
              end

            required? = Confispex.Schema.variable_required?(definition, group_name, context)

            [
              variable_name,
              if(required?, do: "required", else: ""),
              default,
              doc
            ]
          end)
          |> as_table(["Name", "Required", "Default", "Description"])
        ]
      end)
      |> Enum.intersperse("\n\n")

    iodata = ["# Variables (#{stringify_context(context)})\n\n", iodata]

    File.write!(output_path, iodata)
  end

  defp stringify_context(context) do
    Enum.map_join(context, " ", fn {key, value} -> "#{key}=#{value}" end)
  end

  defp as_table(rows, header) do
    columns_number = length(header)
    # rows_number = length(rows)

    column_widths =
      1..columns_number
      |> Map.new(fn column_number ->
        max_length =
          [header | rows]
          |> Enum.map(fn row ->
            row |> Enum.at(column_number - 1) |> to_string |> String.length()
          end)
          |> Enum.max()

        {column_number, max_length}
      end)

    header_delimiter =
      1..columns_number
      |> Enum.map(fn column_number -> String.duplicate("-", column_widths[column_number]) end)

    ([header, header_delimiter] ++ rows)
    |> Enum.map(fn row ->
      body =
        row
        |> Enum.with_index(1)
        |> Enum.map_join(" | ", fn {cell, column_number} ->
          cell |> to_string() |> String.pad_trailing(column_widths[column_number])
        end)

      "| " <> body <> " |"
    end)
    |> Enum.intersperse("\n")
  end
end
