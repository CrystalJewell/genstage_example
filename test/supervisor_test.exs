defmodule GenStageExample.JobSupervisorTest do
  use ExUnit.Case
  alias GenStageExample.{SampleWorker, JobSupervisor, JobSupervisorCache}

  setup do
    job_supervisor = Process.whereis(JobSupervisor)

    job_id = UUID.uuid4()
    {:ok, sample_worker} = JobSupervisor.start_child(SampleWorker, %{step_1: "not done", step_2: "not_done"}, job_id)

    %{job_supervisor: job_supervisor, sample_worker: sample_worker, job_id: job_id}
  end

  describe "starts a cache server" do
    test "starts a cache server" do
      refute is_nil(Process.whereis(JobSupervisorCache))
    end

    test "cache server exposes save", %{sample_worker: sample_worker, job_id: job_id} do
      GenServer.cast(sample_worker, :save_state)
      Process.sleep(2)
      cache_state = GenServer.call(JobSupervisorCache, :report)
      assert job_id in Map.keys(cache_state)
      assert GenServer.call(sample_worker, :status) == cache_state[job_id]
    end

    test "cache server exposes load", %{sample_worker: sample_worker, job_id: job_id} do
      GenServer.cast(sample_worker, :save_state)
      Process.sleep(20)

      cache_state = GenServer.call(JobSupervisorCache, :report)

      assert GenServer.call(JobSupervisorCache, {:load, job_id}) == cache_state[job_id]
    end

    test "cache server exposes find", %{sample_worker: sample_worker, job_id: job_id} do
      assert GenServer.call(JobSupervisorCache, {:find, job_id}) == sample_worker
    end
  end

  describe "can start a new worker" do
    test "start a worker with a unique job_id", %{job_id: job_id, sample_worker: sample_worker} do
      state = GenServer.call(sample_worker, :status)
      assert :job_id in Map.keys(state)
      assert state.job_id == job_id
    end

    test "restarts with saved state on a restart error", %{sample_worker: sample_worker, job_id: job_id} do
      old_state = GenServer.call(sample_worker, :status)
      GenServer.cast(sample_worker, :make_restart_error)
      ensure_dead(sample_worker)

      new_pid = new_pid_after_restart(sample_worker, job_id)
      new_state = GenServer.call(new_pid, :status)

      refute Process.alive?(sample_worker)
      assert Process.alive?(new_pid)
      assert new_state.restarts == old_state.restarts + 1
      assert Map.drop(new_state, [:pid, :restarts]) == Map.drop(old_state, [:pid, :restarts])
    end

    test "can die and not restart", %{sample_worker: sample_worker, job_supervisor: job_supervisor} do
      GenServer.cast(sample_worker, :make_no_restart_error)
      ensure_dead(sample_worker)

      refute Process.alive?(sample_worker)
    end
  end

  defp new_pid_after_restart(old_pid, job_id) do
    new_pid = GenServer.call(JobSupervisorCache, {:find, job_id})

    if new_pid == old_pid do
      new_pid_after_restart(old_pid, job_id)
    else
      new_pid
    end
  end

  defp ensure_dead(pid) do
    if Process.alive?(pid) do
      ensure_dead(pid)
    else
      nil
    end
  end
end
