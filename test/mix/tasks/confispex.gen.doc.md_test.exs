defmodule Mix.Tasks.Confispex.Gen.Doc.MdTest do
  use ExUnit.Case, async: false

  @temp_output_path "/tmp/test_doc_md_output.md"

  setup do
    # Clean up temp file before each test
    File.rm(@temp_output_path)

    on_exit(fn ->
      File.rm(@temp_output_path)
    end)

    :ok
  end

  describe "mix confispex.gen.doc.md" do
    test "generates markdown documentation with table format" do
      defmodule DocTestSchema do
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
            doc: "This is optional",
            cast: Confispex.Type.String,
            groups: [:test_group]
          },
          "VAR_WITH_DEFAULT" => %{
            doc: "Has a default value",
            cast: Confispex.Type.String,
            default: "default_value",
            groups: [:test_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.DocTestSchema"
      ])

      assert File.exists?(@temp_output_path)
      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=test target=host)

             ## GROUP :test_group

             | Name             | Required | Default       | Description                 |
             | ---------------- | -------- | ------------- | --------------------------- |
             | REQUIRED_VAR     | required |               | This is a required variable |
             | OPTIONAL_VAR     |          |               | This is optional            |
             | VAR_WITH_DEFAULT |          | default_value | Has a default value         |\
             """
    end

    test "generates docs with custom env and target context" do
      defmodule ContextTestSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "PROD_VAR" => %{
            doc: "Production only variable",
            cast: Confispex.Type.String,
            groups: [:prod_group],
            context: [env: [:prod]]
          },
          "DEV_VAR" => %{
            doc: "Development only variable",
            cast: Confispex.Type.String,
            groups: [:dev_group],
            context: [env: [:dev]]
          }
        })
      end

      # Create :docker atom first
      _ = :docker

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.ContextTestSchema",
        "--env=prod",
        "--target=docker"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=prod target=docker)

             ## GROUP :prod_group

             | Name     | Required | Default | Description              |
             | -------- | -------- | ------- | ------------------------ |
             | PROD_VAR |          |         | Production only variable |\
             """
    end

    test "sorts required variables first within groups" do
      defmodule SortingDocSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "Z_OPTIONAL" => %{
            doc: "Optional Z",
            cast: Confispex.Type.String,
            groups: [:sort_group]
          },
          "A_REQUIRED" => %{
            doc: "Required A",
            cast: Confispex.Type.String,
            groups: [:sort_group],
            required: [:sort_group]
          },
          "M_OPTIONAL" => %{
            doc: "Optional M",
            cast: Confispex.Type.String,
            groups: [:sort_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.SortingDocSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=test target=host)

             ## GROUP :sort_group

             | Name       | Required | Default | Description |
             | ---------- | -------- | ------- | ----------- |
             | A_REQUIRED | required |         | Required A  |
             | M_OPTIONAL |          |         | Optional M  |
             | Z_OPTIONAL |          |         | Optional Z  |\
             """
    end

    test "handles default_lazy with context" do
      defmodule LazyDefaultDocSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "LAZY_VAR" => %{
            doc: "Lazy default based on env",
            cast: Confispex.Type.String,
            groups: [:lazy_group],
            default_lazy: fn
              %{env: :prod} -> "prod_value"
              %{env: :dev} -> "dev_value"
              _ -> "other_value"
            end
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.LazyDefaultDocSchema",
        "--env=prod"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=prod target=host)

             ## GROUP :lazy_group

             | Name     | Required | Default    | Description               |
             | -------- | -------- | ---------- | ------------------------- |
             | LAZY_VAR |          | prod_value | Lazy default based on env |\
             """
    end

    test "handles multiple groups sorted alphabetically" do
      defmodule MultiGroupDocSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "VAR_Z" => %{
            doc: "In Z group",
            cast: Confispex.Type.String,
            groups: [:z_group]
          },
          "VAR_A" => %{
            doc: "In A group",
            cast: Confispex.Type.String,
            groups: [:a_group]
          },
          "VAR_M" => %{
            doc: "In M group",
            cast: Confispex.Type.String,
            groups: [:m_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.MultiGroupDocSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=test target=host)

             ## GROUP :a_group

             | Name  | Required | Default | Description |
             | ----- | -------- | ------- | ----------- |
             | VAR_A |          |         | In A group  |

             ## GROUP :m_group

             | Name  | Required | Default | Description |
             | ----- | -------- | ------- | ----------- |
             | VAR_M |          |         | In M group  |

             ## GROUP :z_group

             | Name  | Required | Default | Description |
             | ----- | -------- | ------- | ----------- |
             | VAR_Z |          |         | In Z group  |\
             """
    end

    test "handles variables without doc field" do
      defmodule NoDocSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "NO_DOC_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:no_doc_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.NoDocSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=test target=host)

             ## GROUP :no_doc_group

             | Name       | Required | Default | Description |
             | ---------- | -------- | ------- | ----------- |
             | NO_DOC_VAR |          |         |             |\
             """
    end

    test "removes newlines from multiline doc strings" do
      defmodule MultilineDocSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "MULTILINE_VAR" => %{
            doc: "Line 1\nLine 2\nLine 3",
            cast: Confispex.Type.String,
            groups: [:multiline_group]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.MultilineDocSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=test target=host)

             ## GROUP :multiline_group

             | Name          | Required | Default | Description        |
             | ------------- | -------- | ------- | ------------------ |
             | MULTILINE_VAR |          |         | Line 1Line 2Line 3 |\
             """
    end

    test "generates proper markdown table with aligned columns" do
      defmodule TableFormatSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "SHORT" => %{
            doc: "Short",
            cast: Confispex.Type.String,
            groups: [:table]
          },
          "VERY_LONG_VARIABLE_NAME" => %{
            doc: "Very long description that should not break the table",
            cast: Confispex.Type.String,
            default: "long_default_value",
            groups: [:table]
          }
        })
      end

      Mix.Tasks.Confispex.Gen.Doc.Md.run([
        "--output=#{@temp_output_path}",
        "--schema=Mix.Tasks.Confispex.Gen.Doc.MdTest.TableFormatSchema"
      ])

      content = File.read!(@temp_output_path)

      assert content == """
             # Variables (env=test target=host)

             ## GROUP :table

             | Name                    | Required | Default            | Description                                           |
             | ----------------------- | -------- | ------------------ | ----------------------------------------------------- |
             | SHORT                   |          |                    | Short                                                 |
             | VERY_LONG_VARIABLE_NAME |          | long_default_value | Very long description that should not break the table |\
             """
    end
  end
end
