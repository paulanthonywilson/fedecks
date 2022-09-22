defmodule FedecksDevWeb.TheSocket do
  @moduledoc """
  Socket side of all of this
  """

  @behaviour Phoenix.Socket.Transport

  def child_spec(_) do
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(%{params: _params} = connection) do
    IO.inspect(connection, label: :connect)
    {:ok, %{}}
  end

  def init(_) do
    IO.inspect(self(), label: :init)
    {:ok, %{}}
  end

  def handle_info(message, state) do
    IO.inspect(message, label: :handle_info)
    {:push, {:text, "handle_info: #{inspect(message)}"}, state}
  end

  def handle_in({_message, _opcode} = message, state) do
    IO.inspect(message, label: :handle_in)
    {:reply, :ok, {:text, "handle_in: #{inspect(message)}"}, state}
  end

  def terminate(reason, _state) do
    IO.inspect(reason, label: :terminate)
    :ok
  end
end
