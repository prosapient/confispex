defmodule Confispex.Server do
  @moduledoc false
  use GenServer

  def start_link(opts) do
    GenServer.start_link(
      __MODULE__,
      [],
      name: Keyword.get(opts, :name, __MODULE__)
    )
  end

  @impl true
  def init(_opts) do
    {:ok, nil}
  end

  @impl true
  def handle_call(
        {:cast, variable_name},
        _from,
        %{variables_store: variables_store, variables_schema: variables_schema, context: context} =
          state
      ) do
    invocation =
      Confispex.Invocation.new(variable_name, context, variables_store, variables_schema)

    new_state = %{state | invocations: Map.put(state.invocations, variable_name, invocation)}

    value =
      case invocation.value do
        {:store, value, _} -> value
        {:default, value, _} -> value
      end

    {:reply, value, new_state}
  end

  def handle_call({action, group_name}, _from, state)
      when action in [:any_required_touched?, :all_required_touched?] do
    checker =
      case action do
        :any_required_touched? -> &Enum.any?/2
        :all_required_touched? -> &Enum.all?/2
      end

    touched? =
      state.variables_schema
      |> Enum.filter(fn {_variable_name, spec} ->
        Confispex.Schema.variable_required?(spec, group_name, state.context)
      end)
      |> checker.(fn {variable_name, _spec} ->
        match?({:ok, _}, Access.fetch(state.variables_store, variable_name))
      end)

    {:reply, touched?, state}
  end

  @impl true
  def handle_cast({:report, mode}, state) do
    state.invocations
    |> Confispex.ANSI.prepare_report(state.variables_schema, state.context, mode)
    |> IO.puts()

    {:noreply, state}
  end

  def handle_cast({:init, params}, _state) do
    state = init_state(params)

    {:noreply, state}
  end

  def handle_cast({:init_once, params}, nil) do
    state = init_state(params)

    {:noreply, state}
  end

  def handle_cast({:init_once, _}, state) do
    {:noreply, state}
  end

  def handle_cast({:update_store, update_fn}, state) do
    store = state.variables_store |> update_fn.() |> ensure_map!()
    {:noreply, %{state | variables_store: store}}
  end

  def child_spec(opts) do
    %{
      id: Confispex.Server,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  defp init_state(%{context: context, schema: schema} = params) do
    %{
      variables_store:
        case Map.get(params, :store, &System.get_env/0) do
          store when is_map(store) -> store
          fun when is_function(fun, 0) -> ensure_map!(fun.())
        end,
      variables_schema:
        schema.variables_schema() |> Confispex.Schema.variables_in_context(context) |> Map.new(),
      invocations: %{},
      context: context,
      touched_groups: []
    }
  end

  defp ensure_map!(%{} = map), do: map
end
