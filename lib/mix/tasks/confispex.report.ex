defmodule Mix.Tasks.Confispex.Report do
  use Mix.Task

  @shortdoc "Print configuration report to stdout"

  @moduledoc """
  Prints a color-coded report of all configuration variables defined in your schema.

  The report shows variables organized by groups with their status:
  - **Green groups**: all required variables present and valid
  - **Red groups**: required variables missing or invalid
  - **Blue groups**: functional (no required variables or all have defaults)

  ## Options

  - `--mode` - report mode (default: `brief`)
    - `brief` - shows only variable status without values (safe for CI/logs)
    - `detailed` - shows actual values from the store (may contain sensitive data)

  ## Examples

      # Brief report (default, safe for logs)
      $ mix confispex.report

      # Brief report (explicit)
      $ mix confispex.report --mode=brief

      # Detailed report with values
      $ mix confispex.report --mode=detailed

  ## Usage in Development

  Run this task after initializing your app to verify all required environment
  variables are properly configured. Use `--mode=brief` in CI/production logs
  to avoid exposing sensitive values.

  See `Confispex.report/2` for interactive usage (IEx, remote shell).
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
