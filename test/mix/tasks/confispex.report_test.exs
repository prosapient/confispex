defmodule Mix.Tasks.Confispex.ReportTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  describe "mix confispex.report" do
    test "runs with default brief mode" do
      defmodule DefaultModeSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "TEST_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test_group]
          }
        })
      end

      Confispex.init(%{
        schema: DefaultModeSchema,
        context: %{env: :test},
        store: %{"TEST_VAR" => "value"}
      })

      Confispex.get("TEST_VAR")

      output =
        capture_io(fn ->
          Mix.Tasks.Confispex.Report.run([])
        end)

      assert output == """
             \e[36mRUNTIME CONFIG STATE\e[0m
             \e[34mGROUP :test_group\e[0m
               \e[32m✓\e[0m TEST_VAR


             """
    end

    test "runs with explicit detailed mode" do
      defmodule DetailedModeSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "DETAILED_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:detailed_group]
          }
        })
      end

      Confispex.init(%{
        schema: DetailedModeSchema,
        context: %{env: :test},
        store: %{"DETAILED_VAR" => "visible_value"}
      })

      Confispex.get("DETAILED_VAR")

      output =
        capture_io(fn ->
          Mix.Tasks.Confispex.Report.run(["--mode=detailed"])
        end)

      assert output == """
             \e[36mRUNTIME CONFIG STATE\e[0m
             \e[34mGROUP :detailed_group\e[0m
               \e[32m✓\e[0m DETAILED_VAR - store: \e[96m"visible_value"\e[0m


             """
    end
  end
end
