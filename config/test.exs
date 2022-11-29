import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :gg2048_web, Gg2048Web.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "vGhUYEVbG+HsIO/oy6ErYG2o+I1uYxvRkx6qCmaCTiuTVGUgg2L5qpnV10qdOhVn",
  server: false

config :logger, level: :debug

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
