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
      assert {:ok, "https://qq?qq%"} = Confispex.Type.cast("https://qq?qq%", Confispex.Type.URL)

      assert {:error,
              {"localhost", Confispex.Type.URL, [validation: "missing a scheme (e.g. https)"]}} =
               Confispex.Type.cast("localhost", Confispex.Type.URL)
    end

    test "base64 encoded string" do
      assert {:error, details} = Confispex.Type.cast("certificate", Confispex.Type.Base64Encoded)

      assert details ==
               {"certificate", Confispex.Type.Base64Encoded,
                [parsing: "not a base64 encoded string"]}
    end
  end

  describe "options validation" do
    test "integer with invalid scope option" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :scope option/, fn ->
        Confispex.Type.cast("42", {Confispex.Type.Integer, scope: :negative})
      end
    end

    test "integer with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("42", {Confispex.Type.Integer, unknown: :value})
      end
    end

    test "enum without required values option" do
      assert_raise NimbleOptions.ValidationError, ~r/required :values option not found/, fn ->
        Confispex.Type.cast("value", Confispex.Type.Enum)
      end
    end

    test "enum with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("value", {Confispex.Type.Enum, values: ["a", "b"], unknown: :value})
      end
    end

    test "csv with invalid of option" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/expected :of option to match at least one given type/,
                   fn ->
                     Confispex.Type.cast("a,b", {Confispex.Type.CSV, of: "invalid"})
                   end
    end

    test "csv with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast(
          "a,b",
          {Confispex.Type.CSV, of: Confispex.Type.String, unknown: :value}
        )
      end
    end

    test "json with invalid keys option" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :keys option/, fn ->
        Confispex.Type.cast("{}", {Confispex.Type.JSON, keys: :invalid})
      end
    end

    test "json with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("{}", {Confispex.Type.JSON, unknown: :value})
      end
    end

    test "base64 with invalid of option" do
      assert_raise NimbleOptions.ValidationError,
                   ~r/expected :of option to match at least one given type/,
                   fn ->
                     Confispex.Type.cast("aGVsbG8=", {Confispex.Type.Base64Encoded, of: 123})
                   end
    end

    test "base64 with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("aGVsbG8=", {Confispex.Type.Base64Encoded, unknown: :value})
      end
    end

    test "boolean with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("true", {Confispex.Type.Boolean, unknown: :value})
      end
    end

    test "float with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("3.14", {Confispex.Type.Float, unknown: :value})
      end
    end

    test "string with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("value", {Confispex.Type.String, unknown: :value})
      end
    end

    test "email with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("user@example.com", {Confispex.Type.Email, unknown: :value})
      end
    end

    test "url with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("https://example.com", {Confispex.Type.URL, unknown: :value})
      end
    end

    test "term with unknown option" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options \[:unknown\]/, fn ->
        Confispex.Type.cast("value", {Confispex.Type.Term, unknown: :value})
      end
    end
  end
end
