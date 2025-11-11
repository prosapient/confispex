# Getting started

The package can be installed by adding `confispex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:confispex, "~> 1.2"}
  ]
end
```

Let's define the first version of a variables schema and runtime config with `confispex`:
```elixir
defmodule MyApp.RuntimeConfigSchema do
  import Confispex.Schema
  @behaviour Confispex.Schema
  alias Confispex.Type

  defvariables(%{
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
      groups: [:base]
    },
    "DATABASE_URL" => %{
      aliases: ["DB_URL"],
      doc: "Full DB URL",
      cast: Type.URL,
      context: [env: [:prod]],
      groups: [:primary_db],
      required: [:primary_db]
    },
    "DATABASE_POOL_SIZE" => %{
      aliases: ["DB_POOL_SIZE", "POOL_SIZE"],
      cast: {Type.Integer, scope: :positive},
      default: "10",
      context: [env: [:prod]],
      groups: [:primary_db]
    },
    "CONTACT_US_EMAILS" => %{
      cast: {Type.CSV, of: Type.Email},
      default: "help@example.com,feedback@example.com",
      groups: [:landing_page],
      context: [env: [:dev, :prod]]
    }
  })
end
```
You can read about all possible options in doc about the type `t:Confispex.Schema.variable_spec/0`.

## Understanding Key Concepts

Before we configure runtime, let's understand some important concepts used in the schema above.

### Aliases

Variables can have multiple names. Confispex tries them in order:

```elixir
"DATABASE_URL" => %{
  aliases: ["DB_URL"],  # If DATABASE_URL not found, tries DB_URL
  # ...
}
```

This means you can set either `DATABASE_URL=postgres://...` or `DB_URL=postgres://...` and Confispex will find it.

### Context Filtering

Variables can be limited to specific environments:

```elixir
"DATABASE_URL" => %{
  context: [env: [:prod]],  # Only available in production
  # ...
}
```

When you run in `:dev` or `:test`, this variable won't appear in the schema at all. This prevents confusion about which variables apply to which environment.

### Error Handling

When `Confispex.get/1` encounters an error (type casting fails or variable not found), it returns `nil` instead of raising an exception. All errors are collected and can be viewed later:

```bash
mix confispex.report --mode=detailed
```

This design allows you to see ALL configuration problems at once, rather than fixing them one-at-a-time.

### The Store

The "store" is where Confispex reads configuration values from. By default, it uses `System.get_env/0`, which returns all environment variables as a map. You can provide a custom store to read configuration from other sources like JSON files, databases, or any other data structure:

```elixir
# Read from JSON file
store = File.read!("config.json") |> JSON.decode!()

Confispex.init(%{
  schema: MyApp.ConfigSchema,
  context: %{env: :prod},
  store: store
})

# Or use a function that lazily loads the store
Confispex.init(%{
  schema: MyApp.ConfigSchema,
  context: %{env: :prod},
  store: fn -> File.read!("config.json") |> JSON.decode!() end
})
```

## Runtime Configuration

Put the following content to `config/runtime.exs`:
```elixir
import Config

Confispex.init(%{
  schema: MyApp.RuntimeConfigSchema,
  context: %{env: config_env(), target: config_target()}
})

# application config

config :logger,
  level: String.to_atom(Confispex.get("LOG_LEVEL"))

config :my_app,
  contact_us_emails: Confispex.get("CONTACT_US_EMAILS"),
  database_pool: Confispex.get("DATABASE_POOL_SIZE"),
  database_ssl: !Confispex.get("DATABASE_NO_SSL")
```

Now, if you run
```
LOG_LEVEL=info CONTACT_US_EMAILS=myemail1@example.com,myemail2 MIX_ENV=prod mix confispex.report --mode=detailed
```
you'll see the following report

![state 1](images/state1.png)

### Group colors
* green - group has required variables and they are present and valid. Such color is not present on a screenshot above, we'll make green group later.
* red - group has required variables, they aren't present or they are invalid.
* blue - group doesn't have required variables and always functional, because there is always a default value to which system can fall back.

There are 3 groups in our example `:landing_page`, `:base` and `:primary_db`:
* `:primary_db` is not functional, because all required variables weren't provided.
* `:base` is functional, everything is valid.
* `:landing_page` is functional too, because even if system failed to cast some value, default value is present and it is used.

### Symbols
* `*` - variable is required in specified group.
* `?` - variable is defined in schema, but was not invoked in `runtime.exs`. It is not an error,
just a warning. It might be a desired behaviour for your case to have such items, because they may be hidden by some conditions
which depend on other variables.
* `✓` - variable was provided and it is valid according to schema.
* `-` - variable wasn't provided and default value is used.


There is a block `MISSING SCHEMA DEFINITIONS` at the bottom.
It simply prints variable names which were invoked in `runtime.exs`, but not present in the schema.

Let's make everything functional.

Add `DATABASE_NO_SSL` to the schema:
```elixir
  "DATABASE_NO_SSL" => %{
    aliases: ["DB_NO_SSL"],
    cast: Type.Boolean,
    default: "false",
    context: [env: [:prod]],
    groups: [:primary_db]
  }
```
Set `DATABASE_URL` in `runtime.exs`:
```elixir
config :my_app,
  # ...
  database_url: Confispex.get("DATABASE_URL"),
```
and run report with valid values:

```
LOG_LEVEL=info CONTACT_US_EMAILS=myemail1@example.com,myemail2@host DB_URL=postgres://user:pwd@localhost:5432/db_name MIX_ENV=prod mix confispex.report --mode=detailed
```
![state 2](images/state2.png)

## Verifying Schema Completeness

To ensure all variables accessed in your application are properly documented in the schema,
use `mix confispex.check` in your CI/CD pipeline:

```bash
# Check that all Confispex.get/1 calls reference variables in schema
$ MIX_ENV=prod mix confispex.check
✓ All configuration variables are defined in schema
```

If you access a variable that's not in your schema, the check will fail:

```bash
$ MIX_ENV=prod mix confispex.check
✗ Found variables missing from schema:
  - UNDOCUMENTED_VAR
** (Mix.Error) Configuration check failed: 1 variable(s) not defined in schema
```

**Best Practice:** Run this check for all environments in CI, since context filters
may cause different variables to be available in different environments:

```bash
MIX_ENV=dev mix confispex.check
MIX_ENV=test mix confispex.check
MIX_ENV=prod mix confispex.check
```

This prevents developers from forgetting to document new variables when adding them
to `config/runtime.exs`.
