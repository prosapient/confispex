defmodule Confispex.ANSITest do
  use ExUnit.Case

  describe "prepare_report/4" do
    test "returns structured data with color tuples" do
      schema = %{
        "VAR" => %{
          cast: Confispex.Type.String,
          groups: [:test]
        }
      }

      context = %{env: :test}
      invocations = %{}

      report = Confispex.ANSI.prepare_report(invocations, schema, context, :brief)

      assert [
               [
                 {:color, :cyan, "RUNTIME CONFIG STATE"},
                 "\n",
                 [
                   [
                     {:color, :blue, "GROUP :test"},
                     "\n",
                     [
                       [
                         " ",
                         " ",
                         {:color, :yellow, "?"},
                         " ",
                         "VAR",
                         [],
                         "\n",
                         []
                       ]
                     ],
                     "\n"
                   ]
                 ]
               ],
               []
             ] = report
    end

    test "mode :detailed shows values, mode :brief hides them" do
      schema = %{
        "TEST_VAR" => %{
          cast: Confispex.Type.String,
          groups: [:test]
        }
      }

      context = %{env: :test}

      invocations = %{
        "TEST_VAR" => %Confispex.Invocation{
          in_schema: :found,
          in_store: :found,
          value: {:store, "secret_value", :original},
          type_cast_errors: []
        }
      }

      detailed_report = Confispex.ANSI.prepare_report(invocations, schema, context, :detailed)
      brief_report = Confispex.ANSI.prepare_report(invocations, schema, context, :brief)

      detailed_string = IO.iodata_to_binary(Confispex.ANSI.apply_colors(detailed_report, false))
      brief_string = IO.iodata_to_binary(Confispex.ANSI.apply_colors(brief_report, false))

      assert detailed_string ==
               "RUNTIME CONFIG STATE\nGROUP :test\n  ✓ TEST_VAR - store: \"secret_value\"\n\n"

      assert brief_string == "RUNTIME CONFIG STATE\nGROUP :test\n  ✓ TEST_VAR\n\n"
    end
  end

  describe "apply_colors/2" do
    test "with emit_ansi? = true, applies ANSI color codes" do
      data = [
        {:color, :red, "ERROR"},
        " - ",
        {:color, :green, "OK"}
      ]

      result = Confispex.ANSI.apply_colors(data, true)
      string = IO.iodata_to_binary(result)

      assert string == "\e[31mERROR\e[0m - \e[32mOK\e[0m"
    end

    test "with emit_ansi? = false, returns plain text without ANSI codes" do
      data = [
        {:color, :red, "ERROR"},
        " - ",
        {:color, :green, "OK"}
      ]

      result = Confispex.ANSI.apply_colors(data, false)
      string = IO.iodata_to_binary(result)

      assert string == "ERROR - OK"
    end

    test "handles nested color tuples" do
      data = [
        {:color, :cyan, ["prefix: ", {:color, :yellow, "nested"}]}
      ]

      result_with_ansi = Confispex.ANSI.apply_colors(data, true)
      result_without_ansi = Confispex.ANSI.apply_colors(data, false)

      assert IO.iodata_to_binary(result_with_ansi) == "\e[36mprefix: \e[33mnested\e[0m\e[0m"
      assert IO.iodata_to_binary(result_without_ansi) == "prefix: nested"
    end

    test "handles mixed content (strings, tuples, lists)" do
      data = [
        "Plain text",
        {:color, :red, "Red text"},
        ["\n", {:color, :blue, "Blue text"}]
      ]

      result_with_ansi = Confispex.ANSI.apply_colors(data, true)
      result_without_ansi = Confispex.ANSI.apply_colors(data, false)

      assert IO.iodata_to_binary(result_with_ansi) ==
               "Plain text\e[31mRed text\e[0m\n\e[34mBlue text\e[0m"

      assert IO.iodata_to_binary(result_without_ansi) == "Plain textRed text\nBlue text"
    end
  end
end

defmodule Confispex.ANSI.IntegrationTest do
  use ExUnit.Case, async: false

  describe "integration: report/2 with emit_ansi? option" do
    test "Confispex.report respects emit_ansi? option" do
      defmodule TestReportSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "TEST_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      Confispex.init(%{
        schema: TestReportSchema,
        context: %{env: :test},
        store: %{"TEST_VAR" => "value"}
      })

      Confispex.get("TEST_VAR")

      output_with_ansi =
        ExUnit.CaptureIO.capture_io(fn ->
          Confispex.report(:brief, emit_ansi?: true)
        end)

      output_without_ansi =
        ExUnit.CaptureIO.capture_io(fn ->
          Confispex.report(:brief, emit_ansi?: false)
        end)

      assert output_with_ansi ==
               "\e[36mRUNTIME CONFIG STATE\e[0m\n\e[34mGROUP :test\e[0m\n  \e[32m✓\e[0m TEST_VAR\n\n\n"

      assert output_without_ansi == "RUNTIME CONFIG STATE\nGROUP :test\n  ✓ TEST_VAR\n\n\n"
    end

    test "Confispex.report with :detailed mode shows values" do
      defmodule TestDetailedSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "SECRET" => %{
            cast: Confispex.Type.String,
            groups: [:auth]
          }
        })
      end

      Confispex.init(%{
        schema: TestDetailedSchema,
        context: %{env: :test},
        store: %{"SECRET" => "my-secret-key"}
      })

      Confispex.get("SECRET")

      output =
        ExUnit.CaptureIO.capture_io(fn ->
          Confispex.report(:detailed, emit_ansi?: false)
        end)

      assert output ==
               "RUNTIME CONFIG STATE\nGROUP :auth\n  ✓ SECRET - store: \"my-secret-key\"\n\n\n"
    end

    test "Confispex.report validates options with NimbleOptions" do
      defmodule TestValidationSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      Confispex.init(%{
        schema: TestValidationSchema,
        context: %{env: :test},
        store: %{}
      })

      # Invalid server type
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :server option/, fn ->
        Confispex.report(:brief, server: "not_an_atom")
      end

      # Invalid emit_ansi? type
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :emit_ansi\? option/, fn ->
        Confispex.report(:brief, emit_ansi?: "true")
      end

      # Unknown option
      assert_raise NimbleOptions.ValidationError, ~r/unknown options.*unknown_opt/, fn ->
        Confispex.report(:brief, unknown_opt: true)
      end
    end
  end
end
