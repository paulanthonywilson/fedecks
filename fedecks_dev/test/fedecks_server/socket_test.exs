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
          "username" => "marvin",
          "password" => "paranoid-android"
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
               %{"fedecks-token" => token, "fedecks-device-id" => "nerves-987x"}
               |> add_auth_to_headers
               |> Harness.connect()
    end

    test "does not reconnect if token is invalid" do
      assert :error ==
               %{"fedecks-token" => "hi", "fedecks-device-id" => "nerves-987x"}
               |> add_auth_to_headers
               |> Harness.connect()
    end

    test "does not reconnect if identifier embedded in token does not match that passed as a parameter" do
      {:push, {:text, "token:" <> token}, _} =
        Harness.handle_info(:refresh_token, %{identifier: "nerves-111a"})

      assert :error =
               %{"fedecks-token" => token, "fedecks-device-id" => "sciatica-987x"}
               |> add_auth_to_headers
               |> Harness.connect()
    end
  end

  describe "connecting with authorisation" do
    test "when valid returns the identifier" do
      assert {:ok, %{identifier: "nerves-543x"}} =
               %{
                 "username" => "marvin",
                 "password" => "paranoid-android",
                 "fedecks-device-id" => "nerves-543x"
               }
               |> add_auth_to_headers
               |> Harness.connect()
    end

    test "when incorrect, does not connect" do
      assert :error ==
               %{
                 "username" => "marvin@gpp.sirius",
                 "password" => "plastic-pal",
                 "fedecks-device-id" => "nerves-543x"
               }
               |> add_auth_to_headers
               |> Harness.connect()
    end

    test "fails if identifier missing" do
      assert :error ==
               %{"username" => "marvin", "password" => "paranoid-android"}
               |> add_auth_to_headers
               |> Harness.connect()
    end
  end

  describe "fails when fedecks auth header is invalid because" do
    test "it is missing" do
      assert :error == Harness.connect(%{connect_info: %{x_headers: []}})
    end

    test "it is not base 64 encoded" do
      assert :error ==
               Harness.connect(%{connect_info: %{x_headers: [{"x-fedecks-auth", "1"}]}})
    end

    test "it does not encode to a binary term" do
      assert :error ==
               Harness.connect(%{
                 connect_info: %{x_headers: [{"x-fedecks-auth", Base.encode64("nope")}]}
               })
    end

    test "it does not encode to a map" do
      val = "hello matey" |> :erlang.term_to_binary() |> Base.encode64()

      assert :error ==
               Harness.connect(%{
                 connect_info: %{x_headers: [{"x-fedecks-auth", val}]}
               })
    end

    test "it encodes an unsafe term" do
      # Base 64 binary term for
      # iex(28)> h
      # %{
      #   "fedecks-device-id" => "nerves-543x",
      #   "other" => :not_existing_atom,
      #   "password" => "paranoid-android",
      #   "username" => "marvin"
      # }
      val =
        "g3QAAAAEbQAAABFmZWRlY2tzLWRldmljZS1pZG0AAAALbmVydmVzLTU0M3htAAAABW90aGVyZAARbm90X2V4aXN0aW5nX2F0b21tAAAACHBhc3N3b3JkbQAAABBwYXJhbm9pZC1hbmRyb2lkbQAAAAh1c2VybmFtZW0AAAAGbWFydmlu"

      assert :error == Harness.connect(%{connect_info: %{x_headers: [{"x-fedecks-auth", val}]}})
    end

    test "headers over 1k (ish) rejected" do
      device_id = String.pad_leading("123b", 1_000, "0")

      assert :error ==
               %{
                 "username" => "marvin",
                 "password" => "paranoid-android",
                 "fedecks-device-id" => device_id
               }
               |> add_auth_to_headers()
               |> Harness.connect()
    end
  end

  # too long?

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

  defp add_auth_to_headers(headers) do
    auth = headers |> :erlang.term_to_binary() |> Base.encode64()
    %{connect_info: %{x_headers: [{"x-fedecks-auth", auth}]}}
  end
end
