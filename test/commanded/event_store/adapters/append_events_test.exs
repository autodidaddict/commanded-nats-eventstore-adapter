defmodule Commanded.EventStore.Adapters.Nats.AppendEventsTest do
  alias Commanded.EventStore.Adapters.Nats

  use Commanded.NatsTestCase
  use Commanded.EventStore.AppendEventsTestCase, event_store: Nats
end
