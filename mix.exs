defmodule Confispex.MixProject do
  use Mix.Project

  def project do
    [
      app: :confispex,
      version: "1.0.1",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: [
        nest_modules_by_prefix: [Confispex.Type],
        extras: [
          "docs/getting_started.md": [title: "Getting Started"]
        ]
      ],
      aliases: [docs: ["docs", &copy_images/1]]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{
        GitHub: "https://github.com/prosapient/confispex"
      }
    ]
  end

  defp description do
    """
    Tool for casting runtime config values using defined schema.
    """
  end

  defp copy_images(_) do
    File.cp_r("docs/images", "doc/images", fn _source, _destination -> true end)
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Confispex.Application, []}
    ]
  end

  defp deps do
    [
      {:nimble_csv, "~> 1.0"},
      {:jason, "~> 1.1"},
      {:ex_doc, "~> 0.24", only: :dev}
    ]
  end
end
