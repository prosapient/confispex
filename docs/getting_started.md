# Getting started

The package can be installed by adding `confispex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:confispex, "~> 1.1"}
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
    "RUNTIME_CONFIG_REPORT" => %{
      cast: {Type.Enum, values: ["disabled", "detailed", "brief"]},
      default: "disabled",
      groups: [:misc]
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

Put the following content to `config/runtime.exs`:
```elixir
import Config

Confispex.init(%{
  schema: MyApp.RuntimeConfigSchema,
  context: %{env: config_env(), target: config_target()}
})

# application config
config :my_app,
  contact_us_emails: Confispex.get("CONTACT_US_EMAILS"),
  database_pool: Confispex.get("DATABASE_POOL_SIZE"),
  database_ssl: !Confispex.get("DATABASE_NO_SSL")

# printing report should be at the end
case Confispex.get("RUNTIME_CONFIG_REPORT") do
  "disabled" -> :noop
  "detailed" -> Confispex.report(:detailed)
  "brief" -> Confispex.report(:brief)
end
```

Now, if you run
```
RUNTIME_CONFIG_REPORT=detailed CONTACT_US_EMAILS=myemail1@example.com,myemail2 MIX_ENV=prod mix run --no-halt
```
you'll see the following report

![state 1](images/state1.png)

### Group colors
* green - group has required variables and they are present and valid. Such color is not present on a screenshot above, we'll make green group later.
* red - group has requried variables, they aren't present or they are invalid.
* blue - group doesn't have required variables and always functional, because there is always a default value to which system can fall back.

There are 3 groups in our example `:landing_page`, `:misc` and `:primary_db`:
* `:primary_db` is not functional, because all required variables weren't provided.
* `:misc` is functional, everything is valid.
* `:landing_page` is functional too, because even if system failed to cast some value, default value is present and it is used.

### Symbols
* `*` variable is required in specified group. 
* `?` variable is defined in schema, but was not invoked in `runtime.exs`. It is not an error,
just a warning. It might be a desired behavour for your case to have such items, because they may be hidden by some conditions
which depend on other variables.
* `✓` variable was provided and it is valid according to schema.
* `-` variable not provided, but default value is present and used.


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
RUNTIME_CONFIG_REPORT=detailed CONTACT_US_EMAILS=myemail1@example.com,myemail2@host DB_URL=postgres://user:pwd@localhost:5432/db_name MIX_ENV=prod mix run --no-halt
```
![state 2](images/state2.png)
