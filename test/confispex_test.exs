defmodule ConfispexTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  setup do
    server = :"test_server_#{:erlang.unique_integer([:positive])}"
    start_supervised!({Confispex.Server, name: server})
    %{server: server}
  end

  doctest Confispex.Type.Boolean
  doctest Confispex.Type.URL
  doctest Confispex.Type.Term
  doctest Confispex.Type.String
  doctest Confispex.Type.JSON
  doctest Confispex.Type.Integer
  doctest Confispex.Type.Float
  doctest Confispex.Type.Enum
  doctest Confispex.Type.Email
  doctest Confispex.Type.CSV
  doctest Confispex.Type.Base64Encoded

  describe "init_once/2" do
    test "initializes confispex only once", %{server: server} do
      defmodule InitOnceSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "TEST_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test]
          }
        })
      end

      Confispex.init_once(
        %{
          schema: InitOnceSchema,
          context: %{env: :test},
          store: %{"TEST_VAR" => "first"}
        },
        server
      )

      assert Confispex.get("TEST_VAR", server) == "first"

      Confispex.init_once(
        %{
          schema: InitOnceSchema,
          context: %{env: :test},
          store: %{"TEST_VAR" => "second"}
        },
        server
      )

      assert Confispex.get("TEST_VAR", server) == "first"
    end
  end

  describe "any_required_touched?/2" do
    test "returns true when at least one required variable is present", %{server: server} do
      defmodule AnyRequiredSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "REQ_VAR1" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          },
          "REQ_VAR2" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          }
        })
      end

      Confispex.init(
        %{
          schema: AnyRequiredSchema,
          context: %{env: :test},
          store: %{"REQ_VAR1" => "present"}
        },
        server
      )

      assert Confispex.any_required_touched?(:feature, server) == true
    end

    test "returns false when no required variables are present", %{server: server} do
      defmodule NoRequiredSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "REQ_VAR1" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          },
          "REQ_VAR2" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          }
        })
      end

      Confispex.init(
        %{
          schema: NoRequiredSchema,
          context: %{env: :test},
          store: %{}
        },
        server
      )

      assert Confispex.any_required_touched?(:feature, server) == false
    end
  end

  describe "all_required_touched?/2" do
    test "returns true when all required variables are present", %{server: server} do
      defmodule AllRequiredSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "REQ_VAR1" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          },
          "REQ_VAR2" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          }
        })
      end

      Confispex.init(
        %{
          schema: AllRequiredSchema,
          context: %{env: :test},
          store: %{"REQ_VAR1" => "val1", "REQ_VAR2" => "val2"}
        },
        server
      )

      assert Confispex.all_required_touched?(:feature, server) == true
    end

    test "returns false when some required variables are missing", %{server: server} do
      defmodule SomeRequiredSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "REQ_VAR1" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          },
          "REQ_VAR2" => %{
            cast: Confispex.Type.String,
            groups: [:feature],
            required: [:feature]
          }
        })
      end

      Confispex.init(
        %{
          schema: SomeRequiredSchema,
          context: %{env: :test},
          store: %{"REQ_VAR1" => "val1"}
        },
        server
      )

      assert Confispex.all_required_touched?(:feature, server) == false
    end
  end

  describe "update_store/2" do
    test "updates the store with transformation function", %{server: server} do
      defmodule UpdateStoreSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "COUNTER" => %{
            cast: Confispex.Type.Integer,
            groups: [:test]
          }
        })
      end

      Confispex.init(
        %{
          schema: UpdateStoreSchema,
          context: %{env: :test},
          store: %{"COUNTER" => "10"}
        },
        server
      )

      assert Confispex.get("COUNTER", server) == 10

      Confispex.update_store(
        fn store ->
          Map.put(store, "COUNTER", "20")
        end,
        server
      )

      assert Confispex.get("COUNTER", server) == 20
    end
  end

  describe "aliases" do
    test "uses alias when primary variable is not present", %{server: server} do
      defmodule AliasSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "PRIMARY_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test],
            aliases: ["LEGACY_VAR", "OLD_VAR"]
          }
        })
      end

      Confispex.init(
        %{
          schema: AliasSchema,
          context: %{env: :test},
          store: %{"LEGACY_VAR" => "from_alias"}
        },
        server
      )

      assert Confispex.get("PRIMARY_VAR", server) == "from_alias"
    end

    test "prefers primary variable over alias", %{server: server} do
      defmodule PreferPrimarySchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "PRIMARY_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test],
            aliases: ["LEGACY_VAR"]
          }
        })
      end

      Confispex.init(
        %{
          schema: PreferPrimarySchema,
          context: %{env: :test},
          store: %{"PRIMARY_VAR" => "primary", "LEGACY_VAR" => "legacy"}
        },
        server
      )

      assert Confispex.get("PRIMARY_VAR", server) == "primary"
    end

    test "tries multiple aliases in order", %{server: server} do
      defmodule MultipleAliasesSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "PRIMARY_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test],
            aliases: ["FIRST_ALIAS", "SECOND_ALIAS", "THIRD_ALIAS"]
          }
        })
      end

      Confispex.init(
        %{
          schema: MultipleAliasesSchema,
          context: %{env: :test},
          store: %{"SECOND_ALIAS" => "from_second"}
        },
        server
      )

      assert Confispex.get("PRIMARY_VAR", server) == "from_second"
    end

    test "falls back to default when no alias is present", %{server: server} do
      defmodule AliasWithDefaultSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "PRIMARY_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test],
            aliases: ["LEGACY_VAR"],
            default: "default_value"
          }
        })
      end

      Confispex.init(
        %{
          schema: AliasWithDefaultSchema,
          context: %{env: :test},
          store: %{}
        },
        server
      )

      assert Confispex.get("PRIMARY_VAR", server) == "default_value"
    end

    test "handles type cast error in alias", %{server: server} do
      defmodule AliasTypeCastErrorSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "PRIMARY_VAR" => %{
            cast: Confispex.Type.Integer,
            groups: [:test],
            aliases: ["LEGACY_VAR"],
            default: "42"
          }
        })
      end

      Confispex.init(
        %{
          schema: AliasTypeCastErrorSchema,
          context: %{env: :test},
          store: %{"LEGACY_VAR" => "not_a_number"}
        },
        server
      )

      assert Confispex.get("PRIMARY_VAR", server) == 42
    end
  end

  describe "report formatting" do
    test "reports missing schema definitions", %{server: server} do
      defmodule MissingSchemaDefSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "EXISTING_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:test_group]
          }
        })
      end

      Confispex.init(
        %{
          schema: MissingSchemaDefSchema,
          context: %{env: :test},
          store: %{"EXISTING_VAR" => "value"}
        },
        server
      )

      # Get a variable that's in schema
      Confispex.get("EXISTING_VAR", server)
      # Try to get a variable that's NOT in schema
      Confispex.get("UNDEFINED_VAR", server)

      output =
        capture_io(fn ->
          Confispex.report(:brief, server: server)
        end)

      assert output == """
             \e[36mRUNTIME CONFIG STATE\e[0m
             \e[34mGROUP :test_group\e[0m
               \e[32m✓\e[0m EXISTING_VAR


             \e[91mMISSING SCHEMA DEFINITIONS\e[0m
               UNDEFINED_VAR

             """
    end

    test "runs with default brief mode", %{server: server} do
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

      Confispex.init(
        %{
          schema: DefaultModeSchema,
          context: %{env: :test},
          store: %{"TEST_VAR" => "value"}
        },
        server
      )

      Confispex.get("TEST_VAR", server)

      output =
        capture_io(fn ->
          Confispex.report(:brief, server: server)
        end)

      assert output == """
             \e[36mRUNTIME CONFIG STATE\e[0m
             \e[34mGROUP :test_group\e[0m
               \e[32m✓\e[0m TEST_VAR


             """
    end

    test "runs with explicit brief mode", %{server: server} do
      defmodule BriefModeSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "BRIEF_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:brief_group]
          }
        })
      end

      Confispex.init(
        %{
          schema: BriefModeSchema,
          context: %{env: :test},
          store: %{"BRIEF_VAR" => "secret"}
        },
        server
      )

      Confispex.get("BRIEF_VAR", server)

      output =
        capture_io(fn ->
          Confispex.report(:brief, server: server)
        end)

      assert output == """
             \e[36mRUNTIME CONFIG STATE\e[0m
             \e[34mGROUP :brief_group\e[0m
               \e[32m✓\e[0m BRIEF_VAR


             """
    end

    test "runs with detailed mode showing values", %{server: server} do
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

      Confispex.init(
        %{
          schema: DetailedModeSchema,
          context: %{env: :test},
          store: %{"DETAILED_VAR" => "visible_value"}
        },
        server
      )

      Confispex.get("DETAILED_VAR", server)

      output =
        capture_io(fn ->
          Confispex.report(:detailed, server: server)
        end)

      assert output == """
             \e[36mRUNTIME CONFIG STATE\e[0m
             \e[34mGROUP :detailed_group\e[0m
               \e[32m✓\e[0m DETAILED_VAR - store: \e[96m"visible_value"\e[0m


             """
    end

    test "handles required variables correctly", %{server: server} do
      defmodule RequiredVarSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "REQUIRED_VAR" => %{
            cast: Confispex.Type.String,
            groups: [:req_group],
            required: [:req_group]
          }
        })
      end

      Confispex.init(
        %{
          schema: RequiredVarSchema,
          context: %{env: :test},
          store: %{}
        },
        server
      )

      Confispex.get("REQUIRED_VAR", server)

      output =
        capture_io(fn ->
          Confispex.report(:brief, server: server)
        end)

      assert output == """
             \e[36mRUNTIME CONFIG STATE\e[0m
             \e[31mGROUP :req_group\e[0m
             \e[31m*\e[0m \e[36m-\e[0m REQUIRED_VAR


             """
    end
  end
end
