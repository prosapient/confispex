# Confispex
A tool which allows to defining specs for runtime configuration, cast values according to specified types and inspect them.

## Motivation
We needed a tool for managing complexity of runtime configuration.
We have a lot of environment variables in monolithic application. > 150+ to be more precise.
In such a situation `runtime.exs` quickly becomes polluted with badly designed anonymous functions which convert data to needed Elixir terms.
Also, these functions have bad error reporting, because in a case of exception stacktrace isn't available in `runtime.exs` file.
Environment variable names are flat, it is essential to want to categorize them.
We can't switch to yaml-like configuration file, because existing infrastructure forces using environment variables.
Variables can be used only in certain `env`, can have aliases, can be required/optional and this is needed to be documented somehow.
The easiest way to specify that variable is required is by calling `System.fetch_env!/1`, but to see all required variables if they aren't documented, you have to run application `n` times when `n` is a number of required variables.
The team uses [`direnv`](https://direnv.net/) in development and have to keep a template of `.envrc` file up-to-date for newcomers.

So, how `confispex` helps with issues mentioned above?

Elixir 1.11 allows running application code in `runtime.exs`, so `confispex` uses a schema defined in your application code to cast values to Elixir terms. Errors should not be reported immediately, but only when you ask a report. If `confispex` can't cast value from store or default value to specified type, then `nil` is returned. Think about it as an advanced wrapper around `System.get_env/1`. Also, there is a mix task to generate a `.envrc` template from schema.

## Examples

### Schema

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

### Runtime config

```elixir
import Config

# setup confispex
{:ok, _} = Application.ensure_all_started(:confispex)

Confispex.set_schema(MyApp.RuntimeConfigSchema)
Confispex.set_context(%{env: config_env(), target: config_target()})
Confispex.set_new_store(System.get_env())

# application config
config :logger,
  level: String.to_atom(Confispex.get("LOG_LEVEL"))

config :tzdata,
       :autoupdate,
       if(Confispex.get("TZDATA_AUTOUPDATE_ENABLED"),
         do: :enabled,
         else: :disabled
       )

Confispex.report(:brief)
```

## Documentation
Documentation: https://hexdocs.pm/confispex/

Check [Getting started](./docs/getting_started.md) guide.
