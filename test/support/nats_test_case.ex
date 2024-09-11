defmodule Commanded.NatsTestCase do
  use ExUnit.CaseTemplate

  alias Commanded.EventStore.Adapters.Nats

  setup do
    {:ok, event_store_meta} = start_event_store()

    [event_store_meta: event_store_meta]
  end

  def start_event_store(config \\ []) do
    config =
      Keyword.merge(
        [
          serializer: Commanded.Serialization.JsonSerializer,
          stream_prefix: "commandedtest" <> UUID.uuid4(:hex)
        ],
        config
      )

    {:ok, child_spec, event_store_meta} = Nats.child_spec(NatsApplication, config)

    for child <- child_spec do
      start_supervised!(child)
    end

    :timer.sleep(1000)

    {:ok, event_store_meta}
  end
end
