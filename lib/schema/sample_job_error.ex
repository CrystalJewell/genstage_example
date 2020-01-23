defmodule GenStageExample.Schema.SampleJobError do
  @moduledoc """
  Sample job with error for testing
  """

  def schema(_), do: true

  def steps do
    [
      %{
        name: "step 1",
        state: :pending,
        func: fn _ ->
          Process.sleep(100)
          {:error, "error reason"}
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
