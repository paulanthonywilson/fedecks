defmodule FedecksServer.SocketTest do
  use ExUnit.Case
  alias FedecksServer.Socket

  defmodule Harness do
    use Socket, otp_app: :fedecks_dev

    @impl Socket
    def handle_incoming(:text, "no reply needed") do
      send(self(), :noreply_message)
      :ok
    end

    def handle_incoming(:text, "talk to me") do
      {:reply, :text, "wat?"}
    end

    def handle_incoming(:text, "stop!") do
      {:stop, "asked to stop"}
    end

    @impl Socket
    def do_handle_info(:hello_matey, state) do
      {:push, {:text, "hello matey boy"}, Map.put(state, :extra, :info)}
    end

    @impl Socket
    def connection_established(identifier) do
      send(self(), {:harness, :connected, identifier})
    end

    @impl Socket
    def authenticate?(%{
          "x-fedecks-username" => "marvin",
          "x-fedecks-password" => "paranoid-android"
        }),
        do: true

    def authenticate?(_), do: false
  end

  defmodule BareHarness do
    use Socket, otp_app: :fedecks_dev

    @impl Socket
    def authenticate?(_), do: false
  end

  describe "reconnect with token" do
    test "from refresh enables connection" do
      state = %{identifier: "nerves-987x"}

      assert {:push, {:text, "token:" <> token}, ^state} =
               Harness.handle_info(:refresh_token, state)

      assert {:ok, ^state} =
               [{"x-fedecks-token", token}, {"x-fedecks-device-id", "nerves-987x"}]
               |> x_headers()
               |> Harness.connect()
    end

    test "does not reconnect if identifier embedded in token does not match that passed as a parameter" do
      {:push, {:text, "token:" <> token}, _} =
        Harness.handle_info(:refresh_token, %{identifier: "nerves-111a"})

      assert :error =
               [{"x-fedecks-token", token}, {"x-fedecks-device-id", "sciatica-987x"}]
               |> x_headers()
               |> Harness.connect()
    end

    test "does not reconnect if token is invalid" do
      assert :error ==
               [{"x-fedecks-token", "hi"}, {"x-fedecks-device-id", "nerves-987x"}]
               |> x_headers()
               |> Harness.connect()
    end
  end

  test "refreshing a token schedules a new refresh" do
    {:push, _, _} = Harness.handle_info(:refresh_token, %{identifier: "x"})

    # Harness refresh is a milliseconds, so it will turn up
    assert_receive :refresh_token

    # BareHarness refresh is the default, which is hours, so will not turn up
    {:push, _, _} = BareHarness.handle_info(:refresh_token, %{identifier: "x"})

    # Harness refresh is a milliseconds, so it will turn up
    refute_receive :refresh_token
  end

  describe "configuration" do
    test "reads secrets from config" do
      assert String.ends_with?(Harness.secret(), "6zq4")
      assert String.ends_with?(Harness.salt(), "+PP5E")
    end

    test "can override timings" do
      assert Harness.token_refresh_millis() == 1
      assert Harness.token_expiry_secs() == 123_456
    end

    test "timings have defaults" do
      assert BareHarness.token_refresh_millis() == 10_800_000
      assert BareHarness.token_expiry_secs() == 2_419_200
    end
  end

  describe "connecting with authorisation" do
    test "when valid returns the identifier" do
      assert {:ok, %{identifier: "nerves-543x"}} =
               [
                 {"x-fedecks-username", "marvin"},
                 {"x-fedecks-password", "paranoid-android"},
                 {"x-fedecks-device-id", "nerves-543x"}
               ]
               |> x_headers()
               |> Harness.connect()
    end

    test "when incorrect, does not connect" do
      assert :error ==
               [
                 {"x-fedecks-username", "marvin@gpp.sirius"},
                 {"x-fedecks-password", "plastic-pal"},
                 {"x-fedecks-device-id", "nerves-543x"}
               ]
               |> x_headers()
               |> Harness.connect()
    end

    test "fails if identifier missing" do
      assert :error ==
               [
                 {"x-fedecks-username", "marvin"},
                 {"x-fedecks-password", "paranoid-android"}
               ]
               |> x_headers()
               |> Harness.connect()
    end
  end

  describe "init" do
    test "passes on the state" do
      assert {:ok, %{identifier: "nerves-123b"}} == Harness.init(%{identifier: "nerves-123b"})
    end

    test "initiates sending a new connection token" do
      {:ok, _} = Harness.init(%{identifier: "nerves-123b"})
      assert_received :refresh_token
    end

    test "connection established callback is, well, called" do
      {:ok, _} = Harness.init(%{identifier: "nerves-123b"})
      assert_received {:harness, :connected, "nerves-123b"}
    end
  end

  describe "incoming messages" do
    test "by default ignores messages" do
      assert {:ok, %{identifier: "y"}} ==
               BareHarness.handle_in({:text, "hello matey"}, %{identifier: "y"})
    end

    test "calls `handle_incoming_message` if provided" do
      assert {:ok, %{identifier: "xyz"}} ==
               Harness.handle_in({:text, "no reply needed"}, %{identifier: "xyz"})

      assert_received :noreply_message
    end

    test "can also reply" do
      assert {:reply, :ok, {:text, "wat?"}, %{identifier: "xyz"}} ==
               Harness.handle_in({:text, "talk to me"}, %{identifier: "xyz"})
    end

    test "can terminate the websocket" do
      assert {:stop, "asked to stop", %{identifier: "123"}} ==
               Harness.handle_in({:text, "stop!"}, %{identifier: "123"})
    end
  end

  describe "handling info messages" do
    test "passes on messages to the the callback" do
      assert {:push, {:text, "hello matey boy"}, %{identifier: "has-a-nerve", extra: :info}} ==
               Harness.handle_info(:hello_matey, %{identifier: "has-a-nerve"})
    end

    test "defaults to no op" do
      assert {:ok, %{identifier: "bobby"}} ==
               BareHarness.handle_info(:ola, %{identifier: "bobby"})
    end
  end

  defp x_headers(headers), do: %{connect_info: %{x_headers: headers}}
end
