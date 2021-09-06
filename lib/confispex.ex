defmodule Confispex do
  @moduledoc """
  A tool which allows to define specs for runtime configuration, cast values according to specified types and inspect them.
  """
  @type store :: map()
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
            optional(:store) => store() | (() -> store())
          },
          GenServer.server()
        ) :: :ok
  def init(params, server \\ Confispex.Server) do
    {:ok, _} = Application.ensure_all_started(:confispex)
    GenServer.cast(server, {:init, params})
  end

  @doc """
  Initialize a state in server if it hasn't already been initialized

  ## Example

      Confispex.init(%{
        schema: MyApp.RuntimeConfigSchema,
        context: %{env: config_env(), target: config_target()}
      })

  By default, `Confispex` uses `System.get_env/0` to setup the store.
  """
  @spec init_once(
          %{
            required(:schema) => module(),
            required(:context) => context(),
            optional(:store) => store() | (() -> store())
          },
          GenServer.server()
        ) :: :ok
  def init_once(params, server \\ Confispex.Server) do
    {:ok, _} = Application.ensure_all_started(:confispex)
    GenServer.cast(server, {:init_once, params})
  end

  @doc """
  Update a store

  ## Example

      new_store = %{...}

      Confispex.update_store(&Map.merge(&1, new_store))
  """

  @spec update_store((store() -> store()), GenServer.server()) :: :ok
  def update_store(update_fn, server \\ Confispex.Server) when is_function(update_fn, 1) do
    GenServer.cast(server, {:update_store, update_fn})
  end

  @doc """
  Get a value from store by specified variable name (key) and cast it according to schema.

  ## Example

      config :my_app, MyApp.Repo, url: Confispex.get("DATABASE_URL")

  In case of any error during casting `nil` is returned, errors are saved and can be
  retrieved later using `report/1` function.
  """
  @spec get(Confispex.Schema.variable_name(), GenServer.server()) :: any()
  def get(variable_name, server \\ Confispex.Server) do
    GenServer.call(server, {:cast, variable_name})
  end

  @doc """
  Print report with variables usage to STDOUT.

  The difference between `:detailed` and `:brief` modes is that `:brief` doesn't print values of the store.
  Use `:brief` if you don't want to show sensitive data.

  ## Example

      Confispex.report(:detailed)
  """
  @spec report(:detailed | :brief, GenServer.server()) :: :ok
  def report(mode, server \\ Confispex.Server) when mode in [:detailed, :brief] do
    GenServer.cast(server, {:report, mode})
  end

  @doc """
  Returns `true` if any required variable in specified group is present in store.

  If variable is present, then it means you was trying to configure the group.
  This is needed for conditional configuration of applications that may shutdown the system if you try to configure
  the application with invalid params.

  ## Example

      if Confispex.any_required_touched?(:apns) do
        config :pigeon, :apns,
          sandbox: %{
            cert: Confispex.get("APNS_CERT"),
            key: Confispex.get("APNS_KEY"),
            mode: :dev
          }
      end
  """
  @spec any_required_touched?(group_name :: atom(), GenServer.server()) :: boolean()
  def any_required_touched?(group_name, server \\ Confispex.Server) do
    GenServer.call(server, {:any_required_touched?, group_name})
  end

  @doc """
  Returns `true` if all required variables in specified group are present in store.
  """
  @spec all_required_touched?(group_name :: atom(), GenServer.server()) :: boolean()
  def all_required_touched?(group_name, server \\ Confispex.Server) do
    GenServer.call(server, {:all_required_touched?, group_name})
  end
end
