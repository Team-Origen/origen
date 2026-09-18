defmodule OrigenWeb.Router do
  use OrigenWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OrigenWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :require_internal_session do
    plug OrigenWeb.Plugs.AuthenticateInternalSession
  end

  pipeline :require_professional do
    plug OrigenWeb.Plugs.RequireInternalRole, roles: [:professional]
  end

  scope "/", OrigenWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/login", InternalSessionController, :new
    post "/login", InternalSessionController, :create
    post "/logout", InternalSessionController, :delete
    get "/activate", InternalActivationController, :new
    post "/activate/exchange", InternalActivationController, :exchange
    post "/activate", InternalActivationController, :create
    get "/admin/activate", AdminActivationController, :new
    post "/admin/activate/exchange", AdminActivationController, :exchange
    post "/admin/activate", AdminActivationController, :create

    live "/admin/internal", AdminInternalLive, :index
  end

  if Application.compile_env(:origen, :consultation_catalog_demo_enabled, false) and
       Mix.env() != :prod do
    scope "/configuracion", OrigenWeb do
      pipe_through [:browser, :require_internal_session, :require_professional]

      live "/profesional", ConsultationTypeCatalogLive
    end
  end

  scope "/api/bootstrap", OrigenWeb do
    pipe_through :api

    post "/provider-events", ProviderEventController, :create
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:origen, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: OrigenWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
