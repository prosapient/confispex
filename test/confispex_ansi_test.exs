defmodule ConfispexANSITest do
  use ExUnit.Case, async: true

  describe "format_type_cast_error/3" do
    test "formats simple type cast error" do
      error = {"invalid", Confispex.Type.Integer, [validation: "not a valid integer"]}

      result = Confispex.ANSI.format_type_cast_error(error)

      assert result == [
               [
                 [],
                 [],
                 "Error while casting ",
                 {:color, :yellow, "\"invalid\""},
                 " to ",
                 {:color, :yellow, "Confispex.Type.Integer"}
               ],
               "\n",
               [["   "], {:color, :light_red, "Validation failed: "}, "not a valid integer"]
             ]
    end

    test "formats type cast error with intro" do
      error = {"invalid", Confispex.Type.Integer, [validation: "not a valid integer"]}
      intro = ["Attempt to use ", {:color, :light_cyan, "ALIAS_VAR"}]

      result = Confispex.ANSI.format_type_cast_error(error, 0, intro)

      assert result == [
               [
                 [
                   [],
                   ["Attempt to use ", {:color, :light_cyan, "ALIAS_VAR"}],
                   "\n"
                 ],
                 [],
                 "Error while casting ",
                 {:color, :yellow, "\"invalid\""},
                 " to ",
                 {:color, :yellow, "Confispex.Type.Integer"}
               ],
               "\n",
               [["   "], {:color, :light_red, "Validation failed: "}, "not a valid integer"]
             ]
    end

    test "formats type cast error with nested level" do
      error = {"invalid", Confispex.Type.Integer, [validation: "not a valid integer"]}

      result = Confispex.ANSI.format_type_cast_error(error, 2)

      assert result == [
               [
                 [],
                 ["   ", "   "],
                 "Error while casting ",
                 {:color, :yellow, "\"invalid\""},
                 " to ",
                 {:color, :yellow, "Confispex.Type.Integer"}
               ],
               "\n",
               [
                 ["   ", "   ", "   "],
                 {:color, :light_red, "Validation failed: "},
                 "not a valid integer"
               ]
             ]
    end

    test "formats parsing error" do
      error = {"invalid", Confispex.Type.JSON, [parsing: "unexpected end of input"]}

      result = Confispex.ANSI.format_type_cast_error(error)

      assert result == [
               [
                 [],
                 [],
                 "Error while casting ",
                 {:color, :yellow, "\"invalid\""},
                 " to ",
                 {:color, :yellow, "Confispex.Type.JSON"}
               ],
               "\n",
               [["   "], {:color, :light_red, "Parsing failed: "}, "unexpected end of input"]
             ]
    end

    test "formats error with highlight in message" do
      error = {
        "invalid",
        Confispex.Type.Integer,
        [validation: ["not a valid ", {:highlight, "integer"}]]
      }

      result = Confispex.ANSI.format_type_cast_error(error)

      assert result == [
               [
                 [],
                 [],
                 "Error while casting ",
                 {:color, :yellow, "\"invalid\""},
                 " to ",
                 {:color, :yellow, "Confispex.Type.Integer"}
               ],
               "\n",
               [
                 ["   "],
                 {:color, :light_red, "Validation failed: "},
                 ["not a valid ", {:color, :light_cyan, "integer"}]
               ]
             ]
    end

    test "formats nested type cast errors" do
      nested_error1 = {"invalid1", Confispex.Type.Integer, [validation: "not a valid integer"]}
      nested_error2 = {"invalid2", Confispex.Type.Integer, [validation: "not a valid integer"]}

      error = {
        "[\"invalid1\", \"invalid2\"]",
        Confispex.Type.CSV,
        [
          {:nested, [nested_error1, nested_error2]}
        ]
      }

      result = Confispex.ANSI.format_type_cast_error(error)

      assert [
               [[], [], "Error while casting ", _, " to ", _],
               "\n",
               [
                 ["   "],
                 {:color, :light_red, "Casting nested elements failed: \n"},
                 [
                   [
                     [[], ["   ", "   "], "Error while casting ", _, " to ", _],
                     "\n",
                     [["   ", "   ", "   "], {:color, :light_red, "Validation failed: "}, _]
                   ],
                   "\n",
                   [
                     [[], ["   ", "   "], "Error while casting ", _, " to ", _],
                     "\n",
                     [["   ", "   ", "   "], {:color, :light_red, "Validation failed: "}, _]
                   ]
                 ]
               ]
             ] = result
    end

    test "formats multiple error types" do
      error = {
        "invalid",
        Confispex.Type.Integer,
        [
          validation: "first error",
          parsing: "second error"
        ]
      }

      result = Confispex.ANSI.format_type_cast_error(error)

      assert result == [
               [
                 [],
                 [],
                 "Error while casting ",
                 {:color, :yellow, "\"invalid\""},
                 " to ",
                 {:color, :yellow, "Confispex.Type.Integer"}
               ],
               "\n",
               [["   "], {:color, :light_red, "Validation failed: "}, "first error"],
               "\n",
               [["   "], {:color, :light_red, "Parsing failed: "}, "second error"]
             ]
    end
  end

  describe "apply_colors/2" do
    test "applies ANSI colors when emit_ansi? is true" do
      data = [
        {:color, :green, "success"},
        " ",
        {:color, :red, "error"}
      ]

      result = Confispex.ANSI.apply_colors(data, true)

      assert IO.iodata_to_binary(result) =~ "\e[32msuccess\e[0m \e[31merror\e[0m"
    end

    test "strips ANSI colors when emit_ansi? is false" do
      data = [
        {:color, :green, "success"},
        " ",
        {:color, :red, "error"}
      ]

      result = Confispex.ANSI.apply_colors(data, false)

      assert IO.iodata_to_binary(result) == "success error"
    end

    test "handles nested color structures" do
      data = [
        {:color, :green, ["nested ", {:color, :red, "content"}]}
      ]

      result = Confispex.ANSI.apply_colors(data, false)

      assert IO.iodata_to_binary(result) == "nested content"
    end

    test "handles plain strings" do
      data = ["plain", " ", "text"]

      result = Confispex.ANSI.apply_colors(data, true)

      assert IO.iodata_to_binary(result) == "plain text"
    end
  end
end
