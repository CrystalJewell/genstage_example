defmodule GenStageExample.ControllerTest do
  use ExUnit.Case

  alias GenStageExample.{Controller, SampleWorker, JobSupervisorCache}

  describe "create job" do
    test "with good params, create job worker" do
      {:ok, %{job_id: job_id}} = Controller.create_job(SampleWorker, %{job_type: "Some job"})
      pid = GenServer.call(JobSupervisorCache, {:find, job_id})
      assert Process.alive?(pid)
    end

    test "with good params and mock dont insert job" do
      {:ok, %{job_id: job_id}} = Controller.create_job(SampleWorker, %{job_type: "A Job", mock: true})
      assert is_nil(GenServer.call(JobSupervisorCache, {:find, job_id}))
    end
  end
end
