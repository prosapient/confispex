defmodule ConfispexTypesTest do
  use ExUnit.Case, async: true

  describe "Confispex.Type.Float" do
    test "casts float value" do
      assert Confispex.Type.cast(3.14, Confispex.Type.Float) == {:ok, 3.14}
    end

    test "returns error for invalid float" do
      assert {:error, _} = Confispex.Type.cast("not_a_float", Confispex.Type.Float)
    end
  end

  describe "Confispex.Type.JSON" do
    test "casts JSON with :atoms! key conversion" do
      assert Confispex.Type.cast(~s|{"key":"value"}|, {Confispex.Type.JSON, keys: :atoms!}) ==
               {:ok, %{key: "value"}}
    end

    test "handles nested lists with :atoms key conversion" do
      assert Confispex.Type.cast(
               ~s|[{"email":"test@example.com"}]|,
               {Confispex.Type.JSON, keys: :atoms}
             ) == {:ok, [%{email: "test@example.com"}]}
    end

    test "handles nested lists with :atoms! key conversion" do
      assert Confispex.Type.cast(
               ~s|[{"email":"test@example.com"}]|,
               {Confispex.Type.JSON, keys: :atoms!}
             ) == {:ok, [%{email: "test@example.com"}]}
    end

    test "handles ArgumentError in :atoms key conversion" do
      assert {:ok, result} =
               Confispex.Type.cast(
                 ~s|{"nonexistent_atom_key":"value"}|,
                 {Confispex.Type.JSON, keys: :atoms}
               )

      assert result == %{"nonexistent_atom_key" => "value"}
    end
  end

  describe "Confispex.Type.URL" do
    test "validates URL with missing host" do
      assert {:error, {_, _, [validation: message]}} =
               Confispex.Type.cast("https://", Confispex.Type.URL)

      assert message == "missing a host"
    end

    test "accepts URL with valid query string" do
      assert Confispex.Type.cast("https://example.com?key=value", Confispex.Type.URL) ==
               {:ok, "https://example.com?key=value"}
    end

    test "accepts URL without query string" do
      assert Confispex.Type.cast("https://example.com", Confispex.Type.URL) ==
               {:ok, "https://example.com"}
    end
  end

  describe "Confispex.Type.Boolean" do
    test "casts integer 1 to true" do
      assert Confispex.Type.cast(1, Confispex.Type.Boolean) == {:ok, true}
    end

    test "casts integer 0 to false" do
      assert Confispex.Type.cast(0, Confispex.Type.Boolean) == {:ok, false}
    end

    test "casts boolean true" do
      assert Confispex.Type.cast(true, Confispex.Type.Boolean) == {:ok, true}
    end

    test "casts boolean false" do
      assert Confispex.Type.cast(false, Confispex.Type.Boolean) == {:ok, false}
    end
  end

  describe "Confispex.Type.CSV" do
    test "handles empty CSV" do
      assert Confispex.Type.cast("", Confispex.Type.CSV) == {:ok, []}
    end

    test "handles multiple lines error" do
      assert {:error, {_, _, [validation: message]}} =
               Confispex.Type.cast("line1\nline2", Confispex.Type.CSV)

      assert message == "expected a CSV with only 1 line"
    end
  end

  describe "Confispex.Type.Integer" do
    test "casts integer value directly" do
      assert Confispex.Type.cast(42, Confispex.Type.Integer) == {:ok, 42}
    end

    test "returns error for invalid integer" do
      assert {:error, _} = Confispex.Type.cast("not_an_integer", Confispex.Type.Integer)
    end
  end
end
