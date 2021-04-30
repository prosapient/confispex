defmodule Confispex do
  @moduledoc """
  A tool which allows to define specs for runtime configuration, cast values according to specified types and inspect them.
  """

  @doc """
  Get a value from store by specified variable name (key) and cast it according to schema.

  ## Example

      config :my_app, MyApp.Repo, url: Confispex.get("DATABASE_URL")

  In case of any error during casting `nil` is returned, errors are saved and can be
  retrieved later using `report/1` function.
  """
  @spec get(variable_name :: any()) :: any()
  def get(variable_name) do
    GenServer.call(Confispex.Server, {:cast, variable_name})
  end

  @doc "Set schema."
  @spec set_schema(module()) :: :ok
  def set_schema(schema) when is_atom(schema) do
    GenServer.cast(Confispex.Server, {:set_schema, schema})
  end

  @doc """
  Set context.

  Most likely you'll want to setup `env` and `target`:

  ## Example

      Confispex.set_context(%{env: config_env(), target: config_target()})
  """
  @spec set_context(map()) :: :ok
  def set_context(context) when is_map(context) do
    GenServer.cast(Confispex.Server, {:set_context, context})
  end

  @doc """
  Set store unless it is already set.

  ## Example

      Confispex.set_new_store(System.get_env())
  """
  @spec set_new_store(map()) :: :ok
  def set_new_store(store) when is_map(store) do
    GenServer.cast(Confispex.Server, {:set_new_store, store})
  end

  @doc """
  Merge new store with the existing one overriding existing keys.

  Useful when updating config in runtime.

  ## Example

      Confispex.merge_store(Jason.decode!(File.read!("config.json")))

  """
  @spec merge_store(map()) :: :ok
  def merge_store(new_store) when is_map(new_store) do
    GenServer.cast(Confispex.Server, {:merge_store, new_store})
  end

  @doc """
  Print report with variables usage to STDOUT.

  The difference between `:detailed` and `:brief` modes is that `:brief` doesn't print values of the store.
  Use `:brief` if you don't want to show sensitive data.
  """
  @spec report(:detailed | :brief) :: :ok
  def report(mode) when mode in [:detailed, :brief] do
    GenServer.cast(Confispex.Server, {:report, mode})
  end

  @doc """
  Returns `true` if any required variable in specified group was invoked using `get/1`.
  """
  @spec any_required_touched?(group_name :: atom()) :: boolean()
  def any_required_touched?(group_name) do
    GenServer.call(Confispex.Server, {:any_required_touched?, group_name})
  end

  @doc """
  Returns `true` if all required variables in specified group were invoked using `get/1`.
  """
  @spec all_required_touched?(group_name :: atom()) :: boolean()
  def all_required_touched?(group_name) do
    GenServer.call(Confispex.Server, {:all_required_touched?, group_name})
  end
end
