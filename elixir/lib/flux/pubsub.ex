defmodule Flux.PubSub do
  @moduledoc """
  Pub/Sub system for routing data between workers.
  Abstracts Redis/in-memory pub/sub.
  """

  require Logger

  def subscribe(topic) do
    Logger.debug("Subscribing to topic: #{topic}")
    Phoenix.PubSub.subscribe(Flux.PubSub, topic)
  end

  def unsubscribe(topic) do
    Phoenix.PubSub.unsubscribe(Flux.PubSub, topic)
  end

  def publish(topic, message) do
    Phoenix.PubSub.broadcast(Flux.PubSub, topic, {Flux.PubSub, topic, message})
  end

  def broadcast(topic, message) do
    Phoenix.PubSub.broadcast(Flux.PubSub, topic, message)
  end
end
