defmodule Mix.Tasks.Confispex.Gen.Template.EnvrcTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  @temp_output_path "/tmp/test_envrc_output.txt"

  setup do
    # Clean up temp file before each test
    File.rm(@temp_output_path)

    on_exit(fn ->
      File.rm(@temp_output_path)
    end)

    :ok
  end

  describe "mix confispex.gen.template.envrc" do
    test "generates .envrc file with required and optional variables" do
      defmodule EnvrcTestSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "REQUIRED_VAR" => %{
            doc: "This is a required variable",
            cast: Confispex.Type.String,
            groups: [:test_group],
            required: [:test_group]
          },
          "OPTIONAL_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test_group]
          },
          "VAR_WITH_DEFAULT" => %{
            cast: Confispex.Type.String,
            default: "default_value",
            groups: [:test_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Template.Envrc.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.EnvrcTestSchema"
      ])

      assert File.exists?(@temp_output_path)
      content = File.read!(@temp_output_path)

      assert content == """
             # GROUP :test_group
             # This is a required variable
             export REQUIRED_VAR=
             # export OPTIONAL_VAR=
             # export VAR_WITH_DEFAULT="default_value"
             """
    end

    test "generates file with template_value_generator" do
      defmodule GeneratorTestSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "GENERATED_SECRET" => %{
            cast: Confispex.Type.String,
            groups: [:secrets],
            template_value_generator: fn -> "generated_secret_value" end
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Template.Envrc.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.GeneratorTestSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # GROUP :secrets
             export GENERATED_SECRET=generated_secret_value
             """
    end

    test "generates file with default_lazy" do
      defmodule LazyDefaultTestSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "LAZY_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:lazy_group],
            default_lazy: fn
              %{env: :test} -> "test_value"
              _ -> "other_value"
            end
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Template.Envrc.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.LazyDefaultTestSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # GROUP :lazy_group
             # export LAZY_VAR="test_value"
             """
    end

    test "sorts required variables first" do
      defmodule SortingTestSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "Z_OPTIONAL" => %{
            cast: Confispex.Type.String,
            groups: [:sort_group]
          },
          "A_REQUIRED" => %{
            cast: Confispex.Type.String,
            groups: [:sort_group],
            required: [:sort_group]
          },
          "M_OPTIONAL" => %{
            cast: Confispex.Type.String,
            groups: [:sort_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Template.Envrc.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.SortingTestSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # GROUP :sort_group
             export A_REQUIRED=
             # export M_OPTIONAL=
             # export Z_OPTIONAL=
             """
    end

    test "prompts for overwrite when file exists" do
      defmodule OverwriteTestSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "TEST_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      # Create existing file
      File.write!(@temp_output_path, "existing content")

      # Simulate user saying "n" (no)
      output =
        capture_io([input: "n\n"], fn ->
          Mix.Tasks.Confispex.Gen.Template.Envrc.run([
            "--output=#{@temp_output_path}",
            "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.OverwriteTestSchema"
          ])
        end)

      assert output == """
             File #{@temp_output_path} exists. Overwrite? [y/n] Terminated
             """

      # File should remain unchanged
      assert File.read!(@temp_output_path) == "existing content"
    end

    test "overwrites file when user confirms" do
      defmodule OverwriteConfirmSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "NEW_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      # Create existing file
      File.write!(@temp_output_path, "existing content")

      # Simulate user saying "y" (yes)
      capture_io([input: "y\n"], fn ->
        Mix.Tasks.Confispex.Gen.Template.Envrc.run([
          "--output=#{@temp_output_path}",
          "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.OverwriteConfirmSchema"
        ])
      end)

      # File should be overwritten
      content = File.read!(@temp_output_path)

      assert content == """
             # GROUP :test
             # export NEW_VAR=
             """
    end

    test "handles multiple groups sorted by name" do
      defmodule MultiGroupSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "VAR_Z" => %{
            cast: Confispex.Type.String,
            groups: [:z_group]
          },
          "VAR_A" => %{
            cast: Confispex.Type.String,
            groups: [:a_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Template.Envrc.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.MultiGroupSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # GROUP :a_group
             # export VAR_A=

             # GROUP :z_group
             # export VAR_Z=
             """
    end

    test "handles multiline doc comments" do
      defmodule MultilineDocSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "DOCUMENTED_VAR" => %{
            doc: "Line 1\nLine 2\nLine 3",
            cast: Confispex.Type.String,
            groups: [:docs]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Template.Envrc.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Template.EnvrcTest.MultilineDocSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # GROUP :docs
             # Line 1
             # Line 2
             # Line 3
             # export DOCUMENTED_VAR=
             """
    end
  end
end
