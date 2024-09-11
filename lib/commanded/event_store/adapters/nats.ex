defmodule Commanded.EventStore.Adapters.Nats do
  @moduledoc """
  Adapter to use [NATS](https://nats.io) JetStream, via the Gnat client, with Commanded.

  Please check the [Getting started](getting-started.html) guide to learn more.
  """

  @behaviour Commanded.EventStore.Adapter

  require Logger

  alias Commanded.EventStore.Adapters.Nats.JsClient
  alias Commanded.EventStore.Adapters.Nats.Config
  alias Commanded.EventStore.EventData
  alias Commanded.EventStore.RecordedEvent
  alias Commanded.EventStore.SnapshotData
  alias Commanded.EventStore.TypeProvider

  @impl Commanded.EventStore.Adapter
  def child_spec(application, config) do

    event_store =
      case Keyword.get(config, :name) do
        nil -> Module.concat([application, Nats])
        name -> Module.concat([name, Nats])
      end

    # Rename `prefix` config to `stream_prefix`
    config =
      case Keyword.pop(config, :prefix) do
        {nil, config} -> config
        {prefix, config} -> Keyword.put(config, :stream_prefix, prefix)
      end

    gnat_supervisor_settings = %{
      # (required) the registered named you want to give the Gnat connection
      name: :gnat_cesa,
      # number of milliseconds to wait between consecutive reconnect attempts (default: 2_000)
      backoff_period: 4_000,
      connection_settings: [
        %{host: ~c"0.0.0.0", port: 4222}
      ]
    }

    # the order of these is critical
    child_spec = [
      Supervisor.child_spec(
        {Gnat.ConnectionSupervisor, gnat_supervisor_settings},
        id: :cesa_gnat_supervisor
      ),
      Supervisor.child_spec(
        {Commanded.EventStore.Adapters.Nats.Supervisor,
         Keyword.put(config, :event_store, event_store)},
        id: event_store
      ),
    ]

    adapter_meta = %{
      event_store: event_store,
      stream_prefix: Config.stream_prefix(config),
      serializer: Config.serializer(config)
    }

    {:ok, child_spec, adapter_meta}
  end

  @impl Commanded.EventStore.Adapter
  def stream_forward(
        adapter_meta,
        stream_uuid,
        start_version \\ 0,
        read_batch_size \\ 1_000
      ) do
    if !JsClient.stream_exists?(stream_uuid) do
      {:error, :stream_not_found}
    else
      JsClient.read_stream(stream_uuid, start_version, read_batch_size)
    end
  end

  @impl Commanded.EventStore.Adapter
  def subscribe(adapter_meta, stream_uuid) do
    event_store = Map.fetch!(adapter_meta, :event_store)
    pubsub_name = Module.concat([event_store, PubSub])

    with {:ok, _} <- Registry.register(pubsub_name, stream_uuid, []) do
      :ok
    end
  end

  def append_to_stream(adapter_meta, stream_uuid, expected_version, events) do
    append_to_stream(adapter_meta, stream_uuid, expected_version, events, [])
  end

  @impl Commanded.EventStore.Adapter
  def append_to_stream(adapter_meta, stream_uuid, :stream_exists, events, opts) do
    if !JsClient.stream_exists?(stream_uuid) do
      {:error, :stream_not_found}
    else
      append_to_stream(adapter_meta, stream_uuid, :any_version, events, opts)
    end
  end

  def append_to_stream(adapter_meta, stream_uuid, :no_stream, events, opts) do
    if JsClient.stream_exists?(stream_uuid) do
      {:error, :stream_exists}
    else
      append_to_stream(adapter_meta, stream_uuid, :any_version, events, opts)
    end
  end

  def append_to_stream(adapter_meta, stream_uuid, 0, events, opts) do
    append_to_stream(adapter_meta, stream_uuid, :any_version, events, opts)
  end

  def append_to_stream(adapter_meta, stream_uuid, :any_version, events, _opts) do
    stream = stream_name(adapter_meta, stream_uuid)
    stream_subject = stream_subject(adapter_meta, stream_uuid)

    Logger.debug(
      "NATS event store attempting to append to stream " <>
        inspect(stream) <> " " <> inspect(length(events)) <> " event(s)"
    )

    add_to_stream(adapter_meta, stream, stream_subject, events)
  end


  def append_to_stream(adapter_meta, stream_uuid, expected_version, events, opts \\ [])
      when is_integer(expected_version) do
    if !JsClient.stream_exists?(stream_uuid) do
      {:error, :wrong_expected_version}
    else
      if expected_version > JsClient.last_sequence_number(stream_uuid) do
        {:error, :wrong_expected_version}
      else
        append_to_stream(adapter_meta, stream_uuid, :any_version, events, opts)
      end
    end
  end


  @impl Commanded.EventStore.Adapter
  def subscribe_to(adapter_meta, :all, subscription_name, subscriber, start_from, opts) do
    IO.puts("subscribe_to/6:all")
  end

  @impl Commanded.EventStore.Adapter
  def subscribe_to(adapter_meta, stream_uuid, subscription_name, subscriber, start_from, opts) do
    IO.puts("subscribe_to/6")
  end

  @impl Commanded.EventStore.Adapter
  def ack_event(_adapter_meta, subscription, %RecordedEvent{event_number: event_number}) do
    IO.puts("ack_event")
  end

  @impl Commanded.EventStore.Adapter
  def unsubscribe(adapter_meta, subscription) do
    IO.puts("unsubscribe")
  end

  @impl Commanded.EventStore.Adapter
  def delete_subscription(adapter_meta, :all, subscription_name) do
    IO.puts("delete_subscription:all")
  end

  @impl Commanded.EventStore.Adapter
  def delete_subscription(adapter_meta, stream_uuid, subscription_name) do
    IO.puts("delete_subscription")
  end

  @impl Commanded.EventStore.Adapter
  def read_snapshot(adapter_meta, source_uuid) do
    IO.puts("read_snapshot")
  end

  @impl Commanded.EventStore.Adapter
  @spec record_snapshot(any(), Commanded.EventStore.SnapshotData.t()) :: :ok
  def record_snapshot(adapter_meta, %SnapshotData{} = snapshot) do
    IO.puts("record_snapshot")
  end

  @impl Commanded.EventStore.Adapter
  def delete_snapshot(adapter_meta, source_uuid) do
    IO.puts("delete_snapshot")
  end

  defp add_to_stream(adapter_meta, stream, stream_subject, events) do
    serializer = serializer(adapter_meta)

    # TODO - once all the tests pass remove this
    {:ok, _} = JsClient.ensure_stream_created(stream, stream_subject)

    for event <- events do
      JsClient.publish_to_stream(stream_subject, event, serializer)
    end

    :ok
  end

  defp gnat_connection(adapter_meta), do: Map.fetch!(adapter_meta, :gnat_connection)

  defp stream_name(adapter_meta, stream_uuid),
    do: Map.fetch!(adapter_meta, :stream_prefix) <> "-" <> stream_uuid

  defp stream_subject(adapter_meta, stream_uuid),
    do: "cesanats." <> Map.fetch!(adapter_meta, :stream_prefix) <> "." <> stream_uuid

  defp snapshot_stream_name(adapter_meta, source_uuid),
    do: Map.fetch!(adapter_meta, :stream_prefix) <> "-snapshot-" <> source_uuid

  defp serializer(adapter_meta), do: Map.fetch!(adapter_meta, :serializer)
end
