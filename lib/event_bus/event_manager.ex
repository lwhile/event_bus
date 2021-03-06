defmodule EventBus.EventManager do
  @moduledoc """
  Event Manager
  """

  require Logger
  use GenServer
  alias EventBus.EventStore
  alias EventBus.EventWatcher

  @logging_level :info

  @doc false
  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @doc false
  def notify(listeners, {_event_type, _event_data} = event) do
    GenServer.cast(__MODULE__, {:notify, listeners, event})
  end

  @doc false
  @spec handle_cast(tuple(), nil) :: no_return()
  def handle_cast({:notify, listeners, {topic, data} = _event}, state) do
    key = UUID.uuid1()
    :ok = EventStore.save({topic, key, data})
    :ok = EventWatcher.create({listeners, topic, key})

    notify_listeners(listeners, {topic, key})
    {:noreply, state}
  end

  @spec notify_listeners(list(module()), tuple()) :: no_return()
  defp notify_listeners(listeners, event_shadow) do
    Enum.each(listeners, fn listener ->
      notify_listener(listener, event_shadow)
    end)
  end

  @spec notify_listener(module(), tuple()) :: no_return()
  defp notify_listener(listener, {topic, key}) do
    try do
      listener.process({topic, key})
    rescue
      err ->
        Logger.log(@logging_level,
          fn -> "#{listener}.process/1 raised an error!\n#{inspect(err)}" end)
        EventWatcher.mark_as_skipped({listener, topic, key})
    end
  end
end
