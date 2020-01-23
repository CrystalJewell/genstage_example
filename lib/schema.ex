defmodule GenStageExample.Schema do
  @moduledoc """
  Job schema defines the parameter map to be passed in to a particular job
  """

  @doc """
  ## Examples
  ```
  iex> GenStageExample.Schema.check_job(GenStageExample.Schema.SampleJob, %{})
  :ok
  ```
  """
  def check_job(mod, params) do
    if mod.schema(params) do
      :ok
    else
      :error
    end
  end
end
