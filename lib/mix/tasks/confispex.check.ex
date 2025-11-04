defmodule Mix.Tasks.Confispex.Check do
  use Mix.Task

  @shortdoc "Verify all accessed variables are defined in schema"

  @moduledoc """
  Checks that all configuration variables accessed via `Confispex.get/1` are
  defined in your schema. Exits with error code 1 if any variables are missing
  from the schema.

  This task is designed for CI/CD pipelines to prevent runtime issues caused by
  accessing undocumented configuration variables.

  ## Usage in CI/CD

  Add this to your CI pipeline after running tests.

  **Important:** Always run this check for each environment you use (dev, test, prod)
  since different environments may have different variables due to context filters.

      # In your CI config (e.g., GitHub Actions, GitLab CI)
      $ MIX_ENV=dev mix confispex.check
      $ MIX_ENV=test mix confispex.check
      $ MIX_ENV=prod mix confispex.check

  The task will:
  - Exit with code 0 if all variables are defined in schema
  - Exit with code 1 if any variables are missing from schema
  - Print the list of missing variables to stderr

  ## Examples

      # Check for missing schema definitions
      $ MIX_ENV=prod mix confispex.check

      # Example output on success:
      ✓ All configuration variables are defined in schema

      # Example output on failure:
      ✗ Found variables missing from schema:
        - UNDOCUMENTED_VAR_1
        - UNDOCUMENTED_VAR_2

  ## When to Use

  Run this task in CI/CD after:
  1. Your application has started and configuration has been loaded
  2. All `Confispex.get/1` calls have been made (usually during app startup)

  This ensures developers don't forget to document new variables when adding
  them to `config/runtime.exs`.
  """

  @requirements ["app.config"]

  def run(_args) do
    state = GenServer.call(Confispex.Server, :get_state)

    if state == nil do
      Mix.raise(
        "Confispex not initialized. Make sure to call Confispex.init/1 in config/runtime.exs"
      )
    end

    missing_definitions =
      state.invocations
      |> Enum.filter(fn {_variable_name, invocation} ->
        invocation.in_schema == :not_found
      end)
      |> Enum.map(&elem(&1, 0))
      |> Enum.sort()

    if missing_definitions == [] do
      Mix.shell().info("✓ All configuration variables are defined in schema")
    else
      Mix.shell().error("✗ Found variables missing from schema:")

      Enum.each(missing_definitions, fn var ->
        Mix.shell().error("  - #{var}")
      end)

      Mix.raise(
        "Configuration check failed: #{length(missing_definitions)} variable(s) not defined in schema"
      )
    end
  end
end
