defmodule Gg2048Web.Router do
  use Phoenix.Router

  use Gg2048Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Gg2048Web.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end


  scope "/", Gg2048Web do
    pipe_through :browser

    live "/", Lobby
    live "/games/:game_id", Game
  end
end
