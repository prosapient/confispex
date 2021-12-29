defmodule Mix.Tasks.Confispex.Report do
  use Mix.Task
  @shortdoc "Print report to stdout"
  @moduledoc """
  #{@shortdoc}

  ## Examples

      $ mix confispex.report
      $ mix confispex.report --mode=brief
      $ mix confispex.report --mode=detailed
  """
  @requirements ["app.config"]

  def run(args) do
    {opts, []} = OptionParser.parse!(args, switches: [mode: :string])

    mode =
      case opts[:mode] do
        "detailed" -> :detailed
        _ -> :brief
      end

    Confispex.report(mode)
  end
end
