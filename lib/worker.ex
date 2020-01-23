defmodule GenStageExample.Worker do
  @moduledoc """
  Worker for performing job steps

  ## Worker pattern

  Jobs are complex tasks that a user can ask the system to perform.

  A job is defined by a _worker_, a module implementing a GenServer using the
  `GenStageExample.Worker` macro.

  Jobs allow us to maintain the state of the complex task at each stage and to restart
  from a given stage after an error.

  ## Callbacks

  The following callbacks are defined by the ``GenStageExample.Worker` macro:

  - `init`

  If an entry with the same `job_id` exists in the cache, we assume this is
  a restart, and update the initial state with the values stored in the cache.
  Otherwise, we use add the process id to the initial values, store in the cache, and
  start the server with a `{:ok, new_state, {:continue, :start}}`.

  - `handle_call(:start, state)`

  Calls the `do_start` function defined in the worker implementation. This should
  return `{new_msg, new_state}`. The next state is provided to `after_start_response`
  which calculates a JSON-serializable response suitable for the API. The callback
  finishes by replying with the response and sending a `:continue` message with
  `{:reply, reply, new_state, {:continue, next_msg}}`. This stage should
  perform every task in the job up to the first asynchronous step.

  - `handle_continue(:restart, state)`

  Calls the `do_restart` function defined in the worker implementation. This should
  return `{new_msg, new_state}`, and the callback finished by sending a `:continue` message with
  `{:noreply, new_state, {:continue, next_msg}}`. This `do_restart` function should
  infer from the state what the last reliably performed step was, and provide a start
  message for the next step.

  - `handle_cast(:save_state, state)`

  Stores the current state of the worker under the `job_id` in the cache

  - `handle_call(:status, _from, state)`

  Used by APIs to provide updates on the state of the job. Calls the `status_response`
  function defined in the implementation. This should reply with a JSON-serializable
  term.

  ## Defining a worker

  The following functions must be implemented by a worker:

  | Function | Description | Example |
  | --- | --- | --- |
  | `status_response/1` | Returns JSON-serializable summary of state | example |
  | `after_start_response/1` | Returns JSON-serializable response to API | example |
  | `do_start/1` | Returns state (after sync steps) and next message | example |
  | `do_restart/1` | Returns state (after possible cleaning) and next message | example |
  """

  defmacro __using__(_opts) do
    quote do
      use GenServer

      import GenStageExample.Worker

      alias GenStageExample.JobSupervisorCache

      def handle_call(:status, _from, state) do
        {:reply, status_response(state), state}
      end

      def handle_call(:start, _from, state) do
        {next_msg, new_state} = do_start(state)
        reply = after_start_response(new_state)
        {:reply, reply, new_state, {:continue, next_msg}}
      end

      def handle_continue(:restart, state) do
#        TODO: Handle restart
        # {next_msg, new_state} = do_restart(state)
        # {:noreply, new_state, {:continue, next_msg}}
        {:noreply, state}
      end

      def handle_continue(:die, state) do
        rollback(state)
        GenServer.cast(JobSupervisorCache, {:remove, state.job_id})
        {:stop, :normal, state}
      end

      def handle_continue(:die_and_restart, state) do
        rollback(state)

        if state.restarts >= @max_restarts do
          {:stop, :normal, state}
        else
          {:stop, "job_id #{state.job_id} killed on purpose", state}
        end
      end

      def handle_continue({:die_and_restart, reason}, state) do
        if state.restarts >= @max_restarts do
          {:stop, :normal, state}
        else
          {:stop, "reason", state}
        end
      end

      def init(initial_state) do
        case old_state = GenServer.call(JobSupervisorCache, {:load, initial_state.job_id}) do
          %{} ->
            data =
              initial_state
              |> Map.merge(old_state)
              |> Map.put(:pid, self())
              |> Map.put(:restarts, old_state.restarts + 1)

            GenServer.cast(JobSupervisorCache, {:save, data.job_id, data})
            {:ok, data, {:continue, :restart}}

          nil ->
            new_state =
              initial_state
              |> Map.put(:pid, self())
              |> Map.put(:restarts, 0)

            GenServer.cast(JobSupervisorCache, {:save, new_state.job_id, new_state})
            {:ok, new_state}
        end
      end

      def start_link(initial_state, opts \\ []) do
        GenServer.start_link(
          __MODULE__,
          initial_state,
          opts ++ [name: {:global, initial_state.job_id}]
        )
      end

      def save_state(state) do
        job_id = state.job_id
        GenServer.cast(JobSupervisorCache, {:save, job_id, state})
      end

      def handle_cast(:save_state, state) do
        save_state(state)
        {:noreply, state}
      end
    end
  end
end
