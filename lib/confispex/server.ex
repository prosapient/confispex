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
    {:ok,
     %{
       variables_store: nil,
       variables_schema: nil,
       invocations: %{},
       context: nil,
       touched_groups: []
     }}
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

  def handle_call({:any_required_touched?, group_name}, _from, state) do
    touched? =
      state.variables_schema
      |> Confispex.Schema.variables_in_context(state.context)
      |> Enum.filter(fn {_variable_name, spec} ->
        is_list(spec[:required]) and group_name in spec[:required]
      end)
      |> Enum.any?(fn {variable_name, _spec} ->
        match?({:ok, _}, Access.fetch(state.variables_store, variable_name))
      end)

    {:reply, touched?, state}
  end

  def handle_call({:all_required_touched?, group_name}, _from, state) do
    touched? =
      state.variables_schema
      |> Confispex.Schema.variables_in_context(state.context)
      |> Enum.filter(fn {_variable_name, spec} ->
        is_list(spec[:required]) and group_name in spec[:required]
      end)
      |> Enum.all?(fn {variable_name, _spec} ->
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

  def handle_cast({:set_schema, schema}, state) do
    state = %{state | variables_schema: schema.variables_schema()}

    {:noreply, state}
  end

  def handle_cast({:set_context, context}, state) do
    state = %{state | context: context}

    {:noreply, state}
  end

  def handle_cast({:set_new_store, store}, state) do
    state =
      if is_nil(state.variables_store) do
        %{state | variables_store: store}
      else
        state
      end

    {:noreply, state}
  end

  def handle_cast({:merge_store, store}, state) do
    state = %{state | variables_store: Map.merge(state.variables_store, store)}

    {:noreply, state}
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
end
