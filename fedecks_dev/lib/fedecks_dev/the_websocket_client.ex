# credo:disable-for-this-file
defmodule FedecksDev.TheWebsocketClient do
  @moduledoc """
  For extracting / testing the Fedecks client
  """

  @behaviour :websocket_client_handler

  def start_link(url, opts \\ []) do
    :websocket_client.start_link(url, __MODULE__, opts)
  end

  @impl :websocket_client_handler
  def init(opts, conn_state) do
    IO.inspect({self(), opts, conn_state}, label: :init)
    {:ok, %{}}
  end

  @impl :websocket_client_handler
  def websocket_handle(msg, conn_state, state) do
    IO.inspect({self(), msg, conn_state}, label: :websocket_handle)
    {:ok, state}
  end

  @impl :websocket_client_handler
  def websocket_info(msg, conn_state, state) do
    IO.inspect({self(), msg, conn_state}, label: :websocket_info)
    {:reply, msg, state}
  end

  @impl :websocket_client_handler
  def websocket_terminate(reason, conn_state, _state) do
    IO.inspect({self(), reason, conn_state}, label: :websocket_terminate)
    :ok
  end
end
