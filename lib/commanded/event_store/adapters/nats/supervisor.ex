defmodule Commanded.EventStore.Adapters.Nats.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(config) do
    event_store = Keyword.fetch!(config, :event_store)
    name = Module.concat([event_store, Supervisor])

    Supervisor.start_link(__MODULE__, config, name: name)
  end

  @impl Supervisor
  def init(config) do
    Supervisor.init([], strategy: :one_for_one)
  end
end
