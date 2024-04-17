defmodule Commanded.EventStore.Adapters.Nats.JsClient do
  @pull_timeout_millis 5000

  alias Commanded.EventStore.Adapters.Nats.PullConsumer
  alias Gnat.Jetstream.API.Stream
  alias Gnat.Jetstream.API.Consumer

  def ensure_stream_created(stream_name, stream_subject) do
    # This returns {:ok, info()} if the stream already exists (idempotent)
    Gnat.Jetstream.API.Stream.create(:gnat_cesa, %Stream{
      name: stream_name,
      subjects: [stream_subject]
    })
  end

  def publish_to_stream(subject, event, serializer) do
    # TODO - deal with expected version
    data = serializer.serialize(event.data)

    headers = [
      {"x-causation-id", event.causation_id},
      {"x-correlation-id", event.correlation_id},
      {"x-event-type", event.event_type},
      {"x-event-id", UUID.uuid4()}
    ]

    md = for {k, v} <- event.metadata, do: {"x-md-" <> k, v}

    headers = headers ++ md

    Gnat.request(:gnat_cesa, subject, data, headers: headers)
  end

  def stream_exists?(stream_name) do
    case Gnat.Jetstream.API.Stream.info(:gnat_cesa, stream_name) do
      {:error, %{"code" => 404}} -> false
      {:error, _} -> false
      {:ok, _} -> true
    end
  end

  def last_sequence_number(stream_name) do
    case Gnat.Jetstream.API.Stream.info(:gnat_cesa, stream_name) do
      {:ok, info} -> info.state.last_seq
      _ -> -1
    end
  end

  def read_stream(stream_name, start_version, batch_size) do
    consumer_name = "reader"

    consumer = %Consumer{
      stream_name: stream_name,
      durable_name: consumer_name,
      deliver_policy: :by_start_sequence,
      opt_start_seq: start_version
    }

    {:ok, _response} = Consumer.create(:gnat_cesa, consumer)
    {:ok, pid} = PullConsumer.start_link(stream_name: stream_name, consumer_name: consumer_name)

    # reply = "_INBOX." <> nuid()

    # with {:ok, consumer} <-
    #        Gnat.Jetstream.API.Consumer.create(:gnat_cesa, %Consumer{
    #          stream_name: stream_name,
    #          deliver_policy: :by_start_sequence,
    #          opt_start_seq: start_version
    #        }) do
    #   {:ok, sub} = Gnat.sub(gnat, self(), reply)
    #   {:ok, agent} = Agent.start_link(fn -> [] end)

    #   gather_messages(agent, stream_name, reply, batch_size)

    #   # Gnat.unsub(gnat, sub)
    # else
    #   e ->
    #     {:error,
    #      "Failed to create an ephemeral consumer for " <> stream_name <> ": " <> inspect(e)}
    # end
  end

  defp nuid(), do: :crypto.strong_rand_bytes(12) |> Base.encode64()
end
