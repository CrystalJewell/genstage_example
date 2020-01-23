defmodule GenStageExample.Controller do
  alias GenStageExample.JobSupervisor

  @doc """
  Creates a new job
  """

  def create_job(module, job_params = %{mock: true}) do
    case module.check_job(job_params) do
      :ok -> {:ok, Map.put(job_params, :job_id, UUID.uuid4())}
      :error -> {:error, job_params}
    end
  end

  def create_job(
        module,
        job_params = %{
          job_type: _job_type
        }
      ) do
    with :ok <- module.check_job(job_params),
         {:ok, worker_proc} <- JobSupervisor.start_child(module, job_params, UUID.uuid4()),
         response = %{job_id: _job_id} <- GenServer.call(worker_proc, :start) do
      {:ok, response}
    else
      :error -> {:error, :bad_job_params}
      {:error, reason} -> {:error, reason}
    end
  end

  def create_job(_), do: {:error, :bad_job_params}
end
