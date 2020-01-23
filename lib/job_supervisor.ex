defmodule GenStageExample.JobSupervisor do
  @moduledoc """
  Supervisor for worker processes

  Workers are GenServers that:
  - Have a unique name
  - Have a "status" callback that reports the status of the job in a meaningful way
  - Respond with sync data when started
  - Terminate normally when process is complete
  - Are given the name of a cache server to store state before error-prone steps
  - Check the cache server for state on init

  Things it does
  - Starts a cache server on startup
  - Starts a worker with a given module and params
  - Restarts a worker from saved state when it terminates with an error
  - Saves state in the cache server
  - Retrieves state from the cache server
  - Deletes state from the cache server
  """

  use DynamicSupervisor
  alias GenStageExample.JobSupervisorCache

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
    start_cache()
  end

  def start_child(module, initial, job_id) do
    initial = Map.put(initial, :job_id, job_id)
    spec = %{id: job_id, start: {module, :start_link, [initial]}, restart: :transient}

    with {:ok, pid} <- DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, pid}
    else
      {:error, err} ->
        {:error, err}
    end
  end

  def start_cache do
    spec = {JobSupervisorCache, %{}}

    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule GenStageExample.JobSupervisorCache do
  @moduledoc """
  Persist state for running worker
  """

  use GenServer

  def init(initial) do
    {:ok, initial}
  end

  def start_link(initial, opts \\ []) do
    GenServer.start_link(__MODULE__, initial, opts ++ [name: __MODULE__])
  end

  def handle_cast({:save, job_id, data}, state) do
    case map = state[job_id] do
      %{} ->
        new_job_state = Map.merge(map, data)
        {:noreply, Map.put(state, job_id, new_job_state)}

      nil ->
        {:noreply, Map.put(state, job_id, data)}
    end
  end

  def handle_cast({:remove, job_id}, state) do
    {:noreply, Map.delete(state, job_id)}
  end

  def handle_call(:report, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:load, name}, _from, state) do
    {:reply, state[name], state}
  end

  def handle_call({:find, job_id}, _from, state) do
    pid =
      case state[job_id] do
        nil -> nil
        _ -> state[job_id].pid
      end

    {:reply, pid, state}
  end
end
