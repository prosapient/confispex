defmodule Mix.Tasks.Confispex.Gen.Doc.Md do
  use Mix.Task
  @shortdoc "Generate a doc in markdown format"
  @moduledoc """
  #{@shortdoc}

  ## Examples

      mix do app.start --no-start, confispex.gen.doc.md --output=RUNTIME_ENV_DEV.md --schema=MyRuntimeConfigSchema --env=prod --target=abc
  """

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
      |> Confispex.Schema.grouped_variables(context)
      |> Enum.sort_by(fn {group_name, _variables} -> group_name end)
      |> Enum.flat_map(fn {group_name, variables} ->
        [
          "## GROUP #{inspect(group_name)}",
          variables
          |> Enum.sort_by(fn {variable_name, definition} ->
            # required first, then sort by name
            {group_name not in List.wrap(definition[:required]), variable_name}
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

            required? = group_name in List.wrap(definition[:required])

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
      |> Enum.intersperse("\n")

    iodata = ["# Variables (#{stringify_context(context)})\n\n", iodata]

    if File.exists?(output_path) do
      result = IO.gets("File #{output_path} exists. Overwrite? [y/n] ")

      if String.downcase(String.trim(result)) == "y" do
        File.write!(output_path, iodata)
      else
        IO.puts("Terminated")
      end
    else
      File.write!(output_path, iodata)
    end
  end

  defp stringify_context(context) do
    Enum.map_join(context, " ", fn {key, value} -> "#{key}=#{value}" end)
  end

  def as_table(rows, header) do
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
