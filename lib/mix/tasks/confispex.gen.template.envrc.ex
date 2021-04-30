defmodule Mix.Tasks.Confispex.Gen.Template.Envrc do
  use Mix.Task
  @shortdoc "Generate .envrc template for dotenv utility"
  @moduledoc """
  #{@shortdoc}

  ## Examples

      mix confispex.gen.envrc_template --output=.envrc --schema=MyRuntimeConfigSchema
  """

  def run(args) do
    {[output: output_path, schema: schema], []} =
      OptionParser.parse!(args, strict: [output: :string, schema: :string])

    schema = Module.concat([schema])
    context = %{env: Mix.env(), target: Mix.target()}

    iodata =
      schema.variables_schema()
      |> Confispex.Schema.grouped_variables(context)
      |> Enum.sort_by(fn {group_name, _variables} -> group_name end)
      |> Enum.flat_map(fn {group_name, variables} ->
        [
          "# GROUP #{inspect(group_name)}",
          variables
          |> Enum.sort_by(fn {variable_name, definition} ->
            # required first, then sort by name
            {group_name not in List.wrap(definition[:required]), variable_name}
          end)
          |> Enum.map(fn {variable_name, definition} ->
            doc =
              case definition do
                %{doc: doc} when is_binary(doc) ->
                  definition.doc |> String.split("\n", trim: true) |> Enum.map(&["# ", &1, "\n"])

                _ ->
                  ""
              end

            prefix = if group_name in List.wrap(definition[:required]), do: "", else: "# "

            value =
              case definition do
                %{default: default} -> inspect(default)
                %{default_lazy: callback} -> context |> callback.() |> inspect()
                _ -> ""
              end

            [doc, prefix, "export ", variable_name, "=", value, "\n"] |> to_string()
          end)
        ]
      end)
      |> Enum.intersperse("\n")

    File.write!(output_path, iodata)
  end
end
