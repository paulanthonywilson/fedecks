import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fedecks_dev, FedecksDevWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "O1wT1P3coyJ4BD9dNIXj8XBZaPifhjd/CGT1JhYcoS5zJu3RGuYQ+JCmRXEsgL/V",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :fedecks_dev, FedecksServer.SocketTest.Harness,
  secret: "ULO1b5eiGSPNcrnAvnIXGy7JhH0WorbLkVq/pT10V/0/Hq7Dw66A5XIbZT0X6zq4",
  salt: "b/BuhKLXOIqYM8sD53XnT51gwiBHmBpv+eM5I6HrvERTleoIq0EHYi76aNo+PP5E",
  token_refresh_millis: 1,
  token_expiry_secs: 123_456

config :fedecks_dev, FedecksServer.SocketTest.BareHarness,
  secret: "ULO1b5eiGSPNcrnAvnIXGy7JhH0WorbLkVq/pT10V/0/Hq7Dw66A5XIbZT0X6zq4",
  salt: "b/BuhKLXOIqYM8sD53XnT51gwiBHmBpv+eM5I6HrvERTleoIq0EHYi76aNo+PP5E"
