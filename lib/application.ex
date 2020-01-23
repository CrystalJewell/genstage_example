defmodule GenStageExample.Application do
  @moduledoc """
  Application settings.
  """
  use Application

  def start(_type, _args) do
    # Wait for Mnesia application to create Jobs table
    with :ok <- :mnesia.create_schema([node()]),
         :ok <- :mnesia.start() do
      :mnesia.create_table(Job, attributes: [:job_id, :pid, :params, :steps, :state, :time])
    end

    # List all child processes to be supervised
    children = [
      GenStageExample.JobSupervisor
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one]

    Supervisor.start_link(children, opts)
  end
end
