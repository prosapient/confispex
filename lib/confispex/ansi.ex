defmodule Confispex.ANSI do
  @moduledoc false
  def prepare_report(invocations, variables_schema, context, mode) do
    missing_schema_definitions =
      for {variable_name, %Confispex.Invocation{in_schema: :not_found}} <- invocations do
        variable_name
      end
      |> Enum.sort()

    grouped_variables =
      variables_schema
      |> Confispex.Schema.grouped_variables()
      |> Enum.map(fn {group, variables} ->
        {group, group_status(variables, group, invocations, context), variables}
      end)
      |> Enum.sort_by(fn {group, group_status, _variables} ->
        {group_status_priority(group_status), group}
      end)

    schema_state = [
      colorize("RUNTIME CONFIG STATE", :cyan),
      "\n",
      for {group, group_status, variables} <- grouped_variables do
        variable_name_column_width =
          variables |> Enum.map(&(&1 |> elem(0) |> String.length())) |> Enum.max()

        [
          colorize("GROUP " <> inspect(group), group_status_color(group_status)),
          "\n",
          variables
          |> Enum.sort_by(fn {variable_name, spec} ->
            # required first, then sort by name
            {not Confispex.Schema.variable_required?(spec, group, context), variable_name}
          end)
          |> Enum.map(
            &format_variable_state(
              &1,
              invocations,
              group,
              variable_name_column_width,
              mode
            )
          ),
          "\n"
        ]
      end
    ]

    [
      schema_state,
      case missing_schema_definitions do
        [] ->
          []

        missing_schema_definitions ->
          [
            "\n",
            colorize("MISSING SCHEMA DEFINITIONS", :light_red),
            "\n",
            missing_schema_definitions |> Enum.map(&("  " <> &1 <> "\n"))
          ]
      end
    ]
  end

  defp group_status_priority(:ok), do: 0
  defp group_status_priority(:no_required_variables), do: 1
  defp group_status_priority(:requirements_not_met), do: 2

  defp group_status_color(:ok), do: :green
  defp group_status_color(:requirements_not_met), do: :red
  defp group_status_color(:no_required_variables), do: :blue

  defp group_status(variables, group, invocations, context) do
    variables
    |> Enum.filter(fn {_variable_name, spec} ->
      Confispex.Schema.variable_required?(spec, group, context)
    end)
    |> case do
      [] ->
        :no_required_variables

      required_variables ->
        required_variables
        |> Enum.all?(fn {variable_name, _spec} ->
          match?(
            {:ok,
             %Confispex.Invocation{in_schema: :found, in_store: :found, value: {:store, _, _}}},
            Map.fetch(invocations, variable_name)
          )
        end)
        |> case do
          true -> :ok
          false -> :requirements_not_met
        end
    end
  end

  defp glyph(:set_and_valid), do: colorize("✓", :green)
  defp glyph(:not_set), do: colorize("-", :cyan)
  defp glyph(:error), do: colorize("✗", :red)
  defp glyph(:not_invoked), do: colorize("?", :yellow)
  defp glyph(:required), do: colorize("*", :red)
  defp glyph(:not_required), do: " "

  defp format_variable_state(
         {variable_name, spec},
         invocations,
         group,
         variable_name_column_width,
         mode
       ) do
    {prefix, ending, details} =
      case Map.fetch(invocations, variable_name) do
        {:ok,
         %Confispex.Invocation{in_schema: :found, in_store: :found, value: {:store, _, _} = value}} ->
          {glyph(:set_and_valid), if(mode == :detailed, do: inspect_value_text(value)), nil}

        {:ok,
         %Confispex.Invocation{
           in_schema: :found,
           in_store: :not_found,
           value: {:default, _, _} = value
         }} ->
          {glyph(:not_set), if(mode == :detailed, do: inspect_value_text(value)), nil}

        {:ok,
         %Confispex.Invocation{
           in_schema: :found,
           in_store: :found,
           value: {:default, _, _} = value,
           type_cast_errors: errors
         }}
        when errors != [] ->
          {ending, formatted_details} =
            case mode do
              :detailed -> {inspect_value_text(value), format_type_cast_errors(errors)}
              :brief -> {nil, nil}
            end

          {glyph(:error), ending, formatted_details}

        :error ->
          {glyph(:not_invoked), nil, nil}
      end

    [
      if is_list(spec[:required]) and group in spec[:required] do
        glyph(:required)
      else
        glyph(:not_required)
      end,
      " ",
      prefix,
      " ",
      String.pad_trailing(variable_name, variable_name_column_width),
      if(ending, do: [" - ", ending], else: []),
      "\n",
      if(details, do: [details, "\n"], else: [])
    ]
  end

  defp format_type_cast_errors(errors) do
    errors
    |> Enum.map_intersperse("\n", fn {source_type, details} ->
      alias_msg =
        case source_type do
          {:store, :original} -> []
          {:store, {:alias, alias_name}} -> ["Attempt to use alias ", highlight(alias_name)]
          :default -> ["Attempt to use ", highlight("schema default")]
        end

      Confispex.ANSI.format_type_cast_error(details, 2, alias_msg)
    end)
  end

  defp inspect_value_text({:store, value, source_type}) do
    ending =
      case source_type do
        :original -> []
        {:alias, alias_name} -> [" (via ", highlight(alias_name), " alias)"]
      end

    ["store", ending, ": ", highlight(inspect(value))]
  end

  defp inspect_value_text({:default, value, default_source}) do
    ["#{default_source} default: ", highlight(inspect(value))]
  end

  def format_type_cast_error({value, type, details}, level \\ 0, intro \\ [])
      when is_list(details) do
    intro_content =
      case intro do
        [] -> []
        intro -> [leading_margin(level), intro, "\n"]
      end

    [
      [
        intro_content,
        leading_margin(level),
        "Error while casting ",
        colorize(inspect(value), :yellow),
        " to ",
        colorize(inspect(type), :yellow)
      ]
      | details
    ]
    |> Enum.map_intersperse("\n", fn
      list when is_list(list) ->
        list

      {:nested, nested_items} ->
        [
          leading_margin(level + 1),
          colorize("Casting nested elements failed: \n", :light_red),
          Enum.map_intersperse(nested_items, "\n", &format_type_cast_error(&1, level + 2, []))
        ]

      {action, error} ->
        text =
          case action do
            :validation -> "Validation failed"
            :parsing -> "Parsing failed"
          end

        [leading_margin(level + 1), colorize(text <> ": ", :light_red), process_highlights(error)]
    end)
  end

  defp process_highlights(value) when is_binary(value), do: value
  defp process_highlights({:highlight, value}), do: value |> process_highlights() |> highlight()
  defp process_highlights(value) when is_list(value), do: Enum.map(value, &process_highlights/1)

  defp highlight(text) do
    colorize(text, :light_cyan)
  end

  defp colorize(string, color) do
    {:color, color, string}
  end

  def apply_colors(data, emit_ansi?) do
    data
    |> List.flatten()
    |> Enum.map(&do_apply_color(&1, emit_ansi?))
  end

  defp do_apply_color({:color, color, content}, emit_ansi?) when is_binary(content) do
    IO.ANSI.format_fragment([color, content, :reset], emit_ansi?)
  end

  defp do_apply_color({:color, color, content}, emit_ansi?) when is_list(content) do
    [
      IO.ANSI.format_fragment([color], emit_ansi?),
      Enum.map(content, &do_apply_color(&1, emit_ansi?)),
      IO.ANSI.format_fragment([:reset], emit_ansi?)
    ]
  end

  defp do_apply_color(value, _emit_ansi?) when is_binary(value), do: value

  defp do_apply_color(value, emit_ansi?) when is_list(value),
    do: Enum.map(value, &do_apply_color(&1, emit_ansi?))

  defp leading_margin(level) do
    List.duplicate("   ", level)
  end
end
