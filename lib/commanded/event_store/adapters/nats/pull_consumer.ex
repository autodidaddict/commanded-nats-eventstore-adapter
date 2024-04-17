defmodule Commanded.EventStore.Adapters.Nats.PullConsumer do
    use Gnat.Jetstream.PullConsumer

    def start_link(arg) do
      Gnat.Jetstream.PullConsumer.start_link(__MODULE__, arg)
    end

    @impl true
    def init(opts) do
      {:ok, nil, Keyword.merge([connection_name: :gnat_cesa], opts)}
    end

    @impl true
    def handle_message(message, state) do
      # Do some processing with the message.
      IO.inspect(message)
      {:ack, state}
    end
end
