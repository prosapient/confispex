# Confispex

A tool which allows defining specs for runtime configuration, cast values according to specified types and inspect them.

[![Hex.pm](https://img.shields.io/hexpm/v/confispex.svg)](https://hex.pm/packages/confispex)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/confispex)

## Features

- **Type-safe configuration** - cast environment variables to proper Elixir types with validation
- **10+ built-in types** - Boolean, Integer, Float, String, Enum, Email, URL, CSV, JSON, Base64, Term
- **Aliases support** - multiple names for the same variable (e.g., `DATABASE_URL` and `DB_URL`)
- **Context-aware defaults** - different defaults for dev/test/prod environments
- **Group-based organization** - organize related variables into logical groups
- **Comprehensive reporting** - visual reports with color-coded group status
- **Error accumulation** - see all configuration issues at once, not one-at-a-time
- **`.envrc` template generation** - auto-generate direnv templates from schema
- **Extensible** - easy to create custom types

## Motivation
We needed a tool for managing complexity of runtime configuration.
We have a lot of environment variables in monolithic application. > 150+ to be more precise.
In such a situation `runtime.exs` quickly becomes polluted with badly designed anonymous functions which convert data to needed Elixir terms.
Also, these functions have bad error reporting, because in a case of exception stacktrace isn't available in `runtime.exs` file.
Environment variable names are flat, it is essential to categorize them.
We can't switch to yaml-like configuration file, because existing infrastructure forces using environment variables.
Variables can be used only in certain `env`, can have aliases, can be required/optional and this is needed to be documented somehow.
The easiest way to specify that variable is required is by calling `System.fetch_env!/1`, but to see all required variables if they aren't documented, you have to run application `n` times when `n` is a number of required variables.
The team uses [`direnv`](https://direnv.net/) in development and have to keep a template of `.envrc` file up-to-date for newcomers.

So, how `confispex` helps with issues mentioned above?

Elixir 1.11 allows running application code in `runtime.exs`, so `confispex` uses a schema defined in your application code to cast values to Elixir terms. Errors should not be reported immediately, but only when you ask for a report. If `confispex` can't cast value from store or default value to specified type, then `nil` is returned. Think about it as an advanced wrapper around `System.get_env/1`. Also, there is a mix task to generate a `.envrc` template from schema.

## Usage

### Installation

Add `confispex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:confispex, "~> 1.1"}
  ]
end
```

### Define Schema

```elixir
defmodule MyApp.RuntimeConfigSchema do
  import Confispex.Schema
  @behaviour Confispex.Schema
  alias Confispex.Type

  defvariables(%{
    "TZDATA_AUTOUPDATE_ENABLED" => %{
      doc: "Autoupdate timezones from IANA Time Zone Database",
      cast: Type.Boolean,
      default: "false",
      groups: [:base],
      context: [env: [:dev, :prod]]
    },
    "LOG_LEVEL" => %{
      cast:
        {Type.Enum,
         values: [
           "emergency",
           "alert",
           "critical",
           "error",
           "warning",
           "notice",
           "info",
           "debug",
           "none"
         ]},
      default_lazy: fn
        %{env: :test} -> "warning"
        %{env: :dev} -> "debug"
        %{env: :prod} -> "debug"
      end,
      groups: [:base]
    }
  })
end
```

### Configure Runtime

```elixir
import Config

Confispex.init(%{
  schema: MyApp.RuntimeConfigSchema,
  context: %{env: config_env(), target: config_target()}
})

# application config
config :logger,
  level: String.to_atom(Confispex.get("LOG_LEVEL"))

config :tzdata,
       :autoupdate,
       if(Confispex.get("TZDATA_AUTOUPDATE_ENABLED"),
         do: :enabled,
         else: :disabled
       )

```

### Inspect Configuration

```
$ mix confispex.report
$ mix confispex.report --mode=brief
$ mix confispex.report --mode=detailed
```
or
```elixir
Confispex.report(:detailed)
```

### Verify Schema in CI/CD

Ensure all accessed variables are defined in your schema:

```bash
# In your CI pipeline, check all environments
$ MIX_ENV=dev mix confispex.check
$ MIX_ENV=test mix confispex.check
$ MIX_ENV=prod mix confispex.check
```

This prevents runtime issues caused by accessing undocumented configuration variables.

## Documentation

- **Full Documentation:** https://hexdocs.pm/confispex/
- **Getting Started Guide:** [docs/getting_started.md](./docs/getting_started.md)
- **Available Types:** See `Confispex.Type` module documentation

## License

Apache 2.0 - see [LICENSE.txt](./LICENSE.txt)
