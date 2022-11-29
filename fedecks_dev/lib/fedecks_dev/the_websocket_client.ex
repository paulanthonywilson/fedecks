# credo:disable-for-this-file
defmodule FedecksDev.TheWebsocketClient do
  @moduledoc """
  For extracting / testing the Fedecks client
  """

  @behaviour :websocket_client_handler

  def start_link(url, handler_opts \\ [], opts \\ []) do
    :websocket_client.start_link(url, __MODULE__, handler_opts, opts)
  end

  @impl :websocket_client_handler
  def init(_opts, _conn_state) do
    # IO.inspect({self(), opts, conn_state}, label: :init)
    {:ok, %{}}
  end

  @impl :websocket_client_handler
  def websocket_handle(_msg, _conn_state, state) do
    # IO.inspect({self(), msg, conn_state}, label: :websocket_handle)
    {:ok, state}
  end

  @impl :websocket_client_handler
  def websocket_info(msg, _conn_state, state) do
    # IO.inspect({self(), msg, conn_state}, label: :websocket_info)
    {:reply, msg, state}
  end

  @impl :websocket_client_handler
  def websocket_terminate(_reason, _conn_state, _state) do
    # IO.inspect({self(), reason, conn_state}, label: :websocket_terminate)
    :ok
  end
end
