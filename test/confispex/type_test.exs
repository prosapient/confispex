defmodule Confispex.TypeTest do
  use ExUnit.Case

  describe "cast" do
    test "integer" do
      assert {:error, details} =
               Confispex.Type.cast("-1", {Confispex.Type.Integer, scope: :positive})

      assert details ==
               {"-1", {Confispex.Type.Integer, [scope: :positive]},
                [validation: "expected a positive integer"]}
    end

    test "boolean" do
      assert {:error, details} = Confispex.Type.cast("q", Confispex.Type.Boolean)

      assert details ==
               {"q", Confispex.Type.Boolean,
                [
                  validation: [
                    "expected one of: ",
                    [
                      {:highlight, "enabled"},
                      ", ",
                      {:highlight, "true"},
                      ", ",
                      {:highlight, "1"},
                      ", ",
                      {:highlight, "yes"},
                      ", ",
                      {:highlight, "disabled"},
                      ", ",
                      {:highlight, "false"},
                      ", ",
                      {:highlight, "0"},
                      ", ",
                      {:highlight, "no"}
                    ]
                  ]
                ]}
    end

    test "csv of integers" do
      assert {:error, details} =
               Confispex.Type.cast("1,23,1,q", {Confispex.Type.CSV, of: Confispex.Type.Integer})

      assert details ==
               {"1,23,1,q", {Confispex.Type.CSV, [of: Confispex.Type.Integer]},
                [nested: [{"q", Confispex.Type.Integer, []}]]}

      assert {:error, details} =
               Confispex.Type.cast(
                 "1,23,1,q,12.3",
                 {Confispex.Type.CSV, of: Confispex.Type.Integer}
               )

      assert details ==
               {"1,23,1,q,12.3", {Confispex.Type.CSV, [of: Confispex.Type.Integer]},
                [
                  nested: [
                    {"q", Confispex.Type.Integer, []},
                    {"12.3", Confispex.Type.Integer,
                     [parsing: ["unexpected substring ", {:highlight, "\".3\""}]]}
                  ]
                ]}

      assert {:error, details} =
               Confispex.Type.cast("1,23,1\",q", {Confispex.Type.CSV, of: Confispex.Type.Integer})

      assert details ==
               {"1,23,1\",q", {Confispex.Type.CSV, [of: Confispex.Type.Integer]},
                [parsing: "unexpected escape character \" in \"1,23,1\\\",q\""]}
    end

    test "enum" do
      assert {:error, details} =
               Confispex.Type.cast(
                 "producction",
                 {Confispex.Type.Enum, values: [:prod, :test, :dev]}
               )

      assert details ==
               {"producction", {Confispex.Type.Enum, [values: [:prod, :test, :dev]]},
                [
                  validation: [
                    "expected one of: ",
                    [{:highlight, "prod"}, ", ", {:highlight, "test"}, ", ", {:highlight, "dev"}]
                  ]
                ]}
    end

    test "float" do
      assert {:error, details} = Confispex.Type.cast("32.3ea", Confispex.Type.Float)

      assert details ==
               {"32.3ea", Confispex.Type.Float,
                [parsing: ["unexpected substring ", {:highlight, "\"ea\""}]]}
    end

    test "email" do
      assert {:error, details} = Confispex.Type.cast("email", Confispex.Type.Email)

      assert details ==
               {"email", Confispex.Type.Email,
                [parsing: ["expected a string in format ", {:highlight, "username@host"}]]}
    end

    test "url" do
      assert {:error, details} = Confispex.Type.cast("https://qq?qq%", Confispex.Type.URL)

      assert details ==
               {"https://qq?qq%", Confispex.Type.URL, [parsing: "malformed query string"]}
    end

    test "base64 encoded string" do
      assert {:error, details} =
               Confispex.Type.cast("certificate", Confispex.Type.Base64Encoded)

      assert details ==
               {"certificate", Confispex.Type.Base64Encoded,
                [parsing: "not a base64 encoded string"]}
    end
  end
end
