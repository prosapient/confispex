defmodule Confispex do
  @report_options_schema NimbleOptions.new!(
                           server: [
                             type: :atom,
                             doc:
                               "The GenServer to query for report data. Defaults to the internal server."
                           ],
                           emit_ansi?: [
                             type: :boolean,
                             doc:
                               "Whether to emit ANSI color codes. Defaults to `IO.ANSI.enabled?()`."
                           ]
                         )

  @moduledoc """
  A tool which allows defining specs for runtime configuration, cast values according to specified types and inspect them.

  ## Workflow

  1. **Define a schema** - Create a module with `defvariables/1` describing your configuration
  2. **Initialize** - Call `init/1` in `config/runtime.exs` with your schema and context
  3. **Get values** - Use `get/1` to retrieve typed and validated configuration values
  4. **Inspect** - Run `mix confispex.report` to see all variables and their status

  ## Key Concepts

  - **Schema** - Defines variables with types, defaults, validation rules, and grouping
  - **Context** - Runtime environment info (e.g., `%{env: :prod, target: :host}`)
  - **Store** - Source of raw configuration values (default: `System.get_env/0`)
  - **Groups** - Logical organization of related variables for reporting
  - **Invocations** - Tracked variable access for comprehensive error reporting

  ## Example

      # 1. Define schema
      defmodule MyApp.ConfigSchema do
        import Confispex.Schema
        @behaviour Confispex.Schema

        defvariables(%{
          "DATABASE_URL" => %{
            cast: Confispex.Type.URL,
            required: [:database],
            groups: [:database]
          }
        })
      end

      # 2. Initialize in config/runtime.exs
      Confispex.init(%{
        schema: MyApp.ConfigSchema,
        context: %{env: config_env()}
      })

      # 3. Use values
      config :my_app, MyApp.Repo,
        url: Confispex.get("DATABASE_URL")

      # 4. Inspect (command line)
      # $ mix confispex.report --mode=detailed

  See the [Getting Started](https://hexdocs.pm/confispex/getting_started.html) guide for more details.
  """

  @typedoc """
  A map containing configuration values, typically environment variables.

  Keys are variable names (usually strings) and values are their string representations.
  """
  @type store :: map()

  @typedoc """
  Runtime context information used for conditional defaults and requirements.

  Commonly includes `:env` (`:dev`, `:test`, `:prod`) and `:target` (`:host`, `:docker`).
  """
  @type context :: %{atom() => atom()}

  @doc """
  Initialize or reinitialize a state in server

  ## Example

      Confispex.init(%{
        schema: MyApp.RuntimeConfigSchema,
        context: %{env: config_env(), target: config_target()}
      })

  By default, `Confispex` uses `System.get_env/0` to setup the store.
  """
  @spec init(
          %{
            required(:schema) => module(),
            required(:context) => context(),
            optional(:store) => store() | (-> store())
          },
          GenServer.server()
        ) :: :ok
  def init(params, server \\ Confispex.Server) do
    {:ok, _} = Application.ensure_all_started(:confispex)
    GenServer.cast(server, {:init, params})
  end

  @doc """
  Initialize a state in server if it hasn't already been initialized.

  Use this instead of `init/1` when you want to initialize only once, ignoring
  subsequent calls. This is useful when configuration file is re-read with
  `Config.Reader.read!/1` to prevent overwriting the existing state.

  ## Example

      # In config/runtime.exs - initializes only on first call
      Confispex.init_once(%{
        schema: MyApp.RuntimeConfigSchema,
        context: %{env: config_env(), target: config_target()}
      })

  By default, `Confispex` uses `System.get_env/0` to setup the store.
  """
  @spec init_once(
          %{
            required(:schema) => module(),
            required(:context) => context(),
            optional(:store) => store() | (-> store())
          },
          GenServer.server()
        ) :: :ok
  def init_once(params, server \\ Confispex.Server) do
    {:ok, _} = Application.ensure_all_started(:confispex)
    GenServer.cast(server, {:init_once, params})
  end

  @doc """
  Update the store at runtime by applying a function to the current store.

  ## Example

      # Add or override specific variables
      new_values = %{"FEATURE_X_ENABLED" => "true", "API_KEY" => "new-key"}
      Confispex.update_store(&Map.merge(&1, new_values))

      # Remove a variable
      Confispex.update_store(&Map.delete(&1, "TEMP_CONFIG"))
  """

  @spec update_store((store() -> store()), GenServer.server()) :: :ok
  def update_store(update_fn, server \\ Confispex.Server) when is_function(update_fn, 1) do
    GenServer.cast(server, {:update_store, update_fn})
  end

  @doc """
  Get a value from store by specified variable name (key) and cast it according to schema.

  Returns the casted value on success, or `nil` on any error (variable not found, type
  casting failed, etc.). Errors are collected and can be viewed with `report/1`.

  ## Example

      config :my_app, MyApp.Repo, url: Confispex.get("DATABASE_URL")

  ## Behavior

  - **Variable found and valid**: returns the casted value
  - **Variable found via alias**: returns the casted value (e.g., `DB_URL` when `DATABASE_URL` not found)
  - **Variable not found but has default**: returns the default value (casted)
  - **Type casting fails**: returns `nil` and saves error for later reporting
  - **Variable not in schema**: returns `nil` and shows warning in report

  To see all errors, run:

      mix confispex.report --mode=detailed
      # or
      Confispex.report(:detailed)

  This design allows your application to start even with configuration errors, so you
  can see ALL problems at once in the report, rather than fixing them one-at-a-time.
  """
  @spec get(Confispex.Schema.variable_name(), GenServer.server()) :: any()
  def get(variable_name, server \\ Confispex.Server) do
    GenServer.call(server, {:cast, variable_name})
  end

  @doc """
  Print report with variables usage to STDOUT.

  The report shows all variables organized by groups with color-coded status:
  - **Green groups**: all required variables present and valid
  - **Red groups**: required variables missing or invalid
  - **Blue groups**: functional (no required variables or all have defaults)

  ## Modes

  - `:detailed` - shows actual values from the store (may contain sensitive data)
  - `:brief` - hides values, only shows variable status (safe for logs)

  ## Options

  #{NimbleOptions.docs(@report_options_schema)}

  ## Examples

      # Show full report with values
      Confispex.report(:detailed)

      # Show report without values (safe for CI/logs)
      Confispex.report(:brief)

      # Force colors on remote shell
      Confispex.report(:detailed, emit_ansi?: true)

      # Custom server with colors disabled
      Confispex.report(:brief, server: MyApp.ConfigServer, emit_ansi?: false)

  You can also use the mix task:

      mix confispex.report --mode=detailed
      mix confispex.report --mode=brief
  """
  @spec report(:detailed | :brief, keyword()) :: :ok
  def report(mode, opts \\ []) when mode in [:detailed, :brief] do
    opts = NimbleOptions.validate!(opts, @report_options_schema)
    server = Keyword.get(opts, :server, Confispex.Server)
    emit_ansi? = Keyword.get(opts, :emit_ansi?, IO.ANSI.enabled?())

    server
    |> GenServer.call({:report, mode, emit_ansi?})
    |> IO.puts()
  end

  @doc """
  Returns `true` if any required variable in specified group is present in store.

  Use this to detect if the user is **trying** to configure a group, even if the
  configuration is incomplete. This is useful for conditional configuration of
  services that crash on invalid config (better to skip than crash).

  ## Example

      # Configure APNS only if user provided at least one APNS variable
      if Confispex.any_required_touched?(:apns) do
        config :pigeon, :apns,
          sandbox: %{
            cert: Confispex.get("APNS_CERT"),
            key: Confispex.get("APNS_KEY"),
            mode: :dev
          }
      end

  ## Difference from `all_required_touched?/1`

  - `any_required_touched?/1` - returns `true` if **at least one** required variable is present
    (user is trying to configure this group)
  - `all_required_touched?/1` - returns `true` only if **all** required variables are present
    (configuration is complete)

  Use `any_required_touched?/1` to decide "should I configure this at all?" and
  `all_required_touched?/1` to decide "is configuration complete and valid?"
  """
  @spec any_required_touched?(group_name :: atom(), GenServer.server()) :: boolean()
  def any_required_touched?(group_name, server \\ Confispex.Server) do
    GenServer.call(server, {:any_required_touched?, group_name})
  end

  @doc """
  Returns `true` if all required variables in specified group are present in store.

  Use this when you want to ensure ALL required variables are configured before
  enabling a feature. This is stricter than `any_required_touched?/1`.

  ## Example

      # Only configure database if ALL required variables are provided
      if Confispex.all_required_touched?(:database) do
        config :my_app, MyApp.Repo,
          url: Confispex.get("DATABASE_URL"),
          pool_size: Confispex.get("DATABASE_POOL_SIZE"),
          ssl: Confispex.get("DATABASE_SSL")
      end

  Compare with `any_required_touched?/1`: if even ONE required variable is present,
  `any_required_touched?/1` returns `true`. This function requires ALL of them.
  """
  @spec all_required_touched?(group_name :: atom(), GenServer.server()) :: boolean()
  def all_required_touched?(group_name, server \\ Confispex.Server) do
    GenServer.call(server, {:all_required_touched?, group_name})
  end
end
