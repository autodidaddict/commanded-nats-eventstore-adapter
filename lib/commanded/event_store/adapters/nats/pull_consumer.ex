defmodule Commanded.EventStore.Adapters.Nats.PullConsumer do
  use Gnat.Jetstream.PullConsumer

  def start_link(args) do
    Gnat.Jetstream.PullConsumer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    IO.puts("initted")
    IO.inspect(args)

    {:ok, %{count: Keyword.get(args, :count), target: Keyword.get(args, :target), msgs: []},
     connection_name: :gnat_cesa,
     stream_name: Keyword.get(args, :stream_name),
     consumer_name: Keyword.get(args, :consumer_name)}
  end

  @impl true
  def handle_message(message, state = %{count: count, target: target, msgs: msgs}) do
    # Do some processing with the message.
    IO.inspect(state)
    IO.inspect(message)

    msgs = msgs ++ [message]

    if length(msgs) == count do
      IO.puts("reached max")
      Process.send(target, msgs, [:nosuspend])
    else
      IO.puts("waiting for more")
    end

    {:ack, %{state | msgs: msgs}}
  end
end
