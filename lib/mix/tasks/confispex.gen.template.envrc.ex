defmodule Mix.Tasks.Confispex.Gen.Template.Envrc do
  use Mix.Task
  @shortdoc "Generate .envrc template for dotenv utility"
  @moduledoc """
  #{@shortdoc}

  ## Examples

      $ mix confispex.gen.template.envrc --output=.envrc --schema=MyRuntimeConfigSchema
  """
  @requirements ["app.config"]

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
            {not Confispex.Schema.variable_required?(definition, group_name, context), variable_name}
          end)
          |> Enum.map(fn {variable_name, definition} ->
            doc =
              case definition do
                %{doc: doc} when is_binary(doc) ->
                  definition.doc |> String.split("\n", trim: true) |> Enum.map(&["# ", &1, "\n"])

                _ ->
                  ""
              end

            {comment_status, value} =
              case definition do
                %{template_value_generator: callback} ->
                  {:uncommented, callback.()}

                %{default: default} ->
                  {:commented, inspect(default)}

                %{default_lazy: callback} ->
                  {:commented, context |> callback.() |> inspect()}

                definition ->
                  comment_status =
                    if Confispex.Schema.variable_required?(definition, group_name, context) do
                      :uncommented
                    else
                      :commented
                    end

                  {comment_status, ""}
              end

            prefix =
              case comment_status do
                :uncommented -> ""
                :commented -> "# "
              end

            [doc, prefix, "export ", variable_name, "=", value, "\n"] |> to_string()
          end)
        ]
      end)
      |> Enum.intersperse("\n")

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
end
