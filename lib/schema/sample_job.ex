defmodule GenStageExample.Schema.SampleJob do
  @moduledoc """
  Sample job for testing
  """

  def schema(_), do: true

  def steps do
    [
      %{
        name: "step 1",
        state: :pending,
        func: fn data ->
          Process.sleep(100)
          {:ok, Map.put(data, :step_one, :done)}
        end
      },
      %{
        name: "step 2",
        state: :pending,
        func: fn data ->
          Process.sleep(100)
          {:ok, Map.put(data, :step_two, :done)}
        end
      }
    ]
  end

  def sync_step(params), do: {:ok, params}
end
