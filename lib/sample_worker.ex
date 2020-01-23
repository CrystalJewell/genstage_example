defmodule GenStageExample.SampleWorker do
  @moduledoc """
  Sample worker module for testing and development
  """

  #  Setting a module attribute before a `use` does not follow community conventions however
  #  this attribute is needed for use `GenStageExample.Worker` too, which could technically
  #  be set in both places but if changes are needed to # you would need to remember to change there too
  @max_restarts 5

  use GenStageExample.Worker

  def check_job(%{bad: true}), do: :error
  def check_job(_), do: :ok

  def do_start(state) do
    {:second_step, Map.put(state, :step_one, "finished")}
  end

  def do_on_init(state) do
    state
  end

  def after_start_response(state) do
    state
  end

  def status_response(state) do
    state
  end

  def handle_continue(:second_step, state) do
    new_state = Map.put(state, :second_step, "finished")
    {:noreply, new_state}
  end

  def handle_call({:add_to_state, {key, val}}, _from, state) do
    new_state = Map.put(state, key, val)
    {:reply, new_state, new_state}
  end

  def handle_cast(:make_restart_error, state) do
    {:noreply, state, {:continue, :die_and_restart}}
  end

  def handle_cast(:make_no_restart_error, state) do
    {:noreply, state, {:continue, :die}}
  end

  def rollback(_), do: nil
end
