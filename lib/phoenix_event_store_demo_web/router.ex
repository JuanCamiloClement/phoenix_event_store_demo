defmodule PhoenixEventStoreDemoWeb.Router do
  use PhoenixEventStoreDemoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixEventStoreDemoWeb.Layouts, :root}
    # plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixEventStoreDemoWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/something", CartController, :print_cart
    get "/create", CartController, :create
    post "/add-item", CartController, :add_item
    post "/add-coupon", CartController, :add_discount_coupon
    put "/update-item-quantity", CartController, :update_item_quantity
    delete "/remove-item/:name", CartController, :remove_item
    delete "/remove-coupon", CartController, :remove_discount_coupon
    delete "/empty-cart", CartController, :empty_cart
  end

  # Other scopes may use custom stacks.
  # scope "/api", PhoenixEventStoreDemoWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:phoenix_event_store_demo, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixEventStoreDemoWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
