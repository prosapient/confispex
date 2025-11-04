defmodule Mix.Tasks.Confispex.CheckTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  setup do
    # Ensure app is started
    {:ok, _} = Application.ensure_all_started(:confispex)
    :ok
  end

  describe "mix confispex.check" do
    test "exits with success when all variables are in schema" do
      defmodule AllInSchemaTest do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "GOOD_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      Confispex.init(%{
        schema: AllInSchemaTest,
        context: %{env: :test},
        store: %{"GOOD_VAR" => "value"}
      })

      Confispex.get("GOOD_VAR")

      output =
        capture_io(fn ->
          Mix.Tasks.Confispex.Check.run([])
        end)

      assert output =~ "✓ All configuration variables are defined in schema"
    end

    test "exits with error when variables are missing from schema" do
      defmodule MissingFromSchemaTest do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "DEFINED_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      Confispex.init(%{
        schema: MissingFromSchemaTest,
        context: %{env: :test},
        store: %{"DEFINED_VAR" => "value", "UNDEFINED_VAR" => "oops"}
      })

      Confispex.get("DEFINED_VAR")
      Confispex.get("UNDEFINED_VAR")

      assert_raise Mix.Error, ~r/Configuration check failed: 1 variable/, fn ->
        capture_io(:stderr, fn ->
          Mix.Tasks.Confispex.Check.run([])
        end)
      end
    end

    test "lists all missing variables in error message" do
      defmodule MultipleMissingTest do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "GOOD" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      Confispex.init(%{
        schema: MultipleMissingTest,
        context: %{env: :test},
        store: %{}
      })

      Confispex.get("GOOD")
      Confispex.get("BAD_ONE")
      Confispex.get("BAD_TWO")

      output =
        capture_io(:stderr, fn ->
          assert_raise Mix.Error, fn ->
            Mix.Tasks.Confispex.Check.run([])
          end
        end)

      assert output =~ "✗ Found variables missing from schema:"
      assert output =~ "- BAD_ONE"
      assert output =~ "- BAD_TWO"
    end
  end
end
