defmodule OrigenWeb.Router do
  use OrigenWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {OrigenWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self' ws: wss:; img-src 'self' data:; font-src 'self' data:;"
    }
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
    get "/activar", InternalActivationController, :new
    post "/activar/intercambiar", InternalActivationController, :exchange
    post "/activar", InternalActivationController, :create
    get "/administrador/activar", AdminActivationController, :new
    post "/administrador/activar/intercambiar", AdminActivationController, :exchange
    post "/administrador/activar", AdminActivationController, :create

    # Keep credential-bearing invitations on the same handlers, never redirect POSTs.
    get "/activate", InternalActivationController, :new
    post "/activate/exchange", InternalActivationController, :exchange
    post "/activate", InternalActivationController, :create
    get "/admin/activate", AdminActivationController, :new
    post "/admin/activate/exchange", AdminActivationController, :exchange
    post "/admin/activate", AdminActivationController, :create

    get "/admin/internal", LegacyUrlController, :accounts
    get "/access", LegacyUrlController, :access
    get "/patient/calendar", LegacyUrlController, :booking
    get "/patient/phone/verify", LegacyUrlController, :phone

    live "/administrador/cuentas", AdminInternalLive, :index
    live "/secretaria/pacientes", SecretaryPatientLive, :index
    live "/secretaria/agenda", SecretaryAgendaLive, :index
    live "/paciente/acceso", PatientAccessLive, :index
    get "/paciente/acceso/verificar", PatientAccessController, :verify
    post "/paciente/cerrar-sesion", PatientAccessController, :delete
    get "/access/verify", PatientAccessController, :verify

    live_session :secretary_summary,
      on_mount: [{OrigenWeb.InternalAuthLive, :ensure_authenticated}] do
      live "/secretaria/resumen-economico", EconomicSummaryLive, :secretary
    end

    live_session :patient_access,
      on_mount: [{OrigenWeb.PatientSessionAuthLive, :ensure_authenticated}] do
      live "/paciente/telefono/verificar", PatientPhoneVerificationLive, :index
      live "/paciente/turnos", PatientAppointmentsLive, :index
      live "/paciente/turnos/reservar", PatientBookingCalendarLive, :index
    end

    live_session :patient_profile_edit,
      on_mount: [{OrigenWeb.PatientSessionAuthLive, :deny_self_edit}] do
      live "/patient/profile/complete", PatientProfileCompletionLive, :index
    end
  end

  scope "/profesional", OrigenWeb do
    pipe_through [:browser, :require_internal_session, :require_professional]

    live_session :professional_agenda,
      on_mount: [{OrigenWeb.InternalAuthLive, :ensure_professional}] do
      live "/resumen-economico", EconomicSummaryLive, :professional
      live "/solicitudes", ProfessionalRequestsLive, :index
      live "/agenda", ProfessionalAgendaLive, :index
      live "/agenda/crear", ProfessionalPatientSelectionLive, :index
    end

    live "/ajustes", ConsultationTypeCatalogLive
    live "/ajustes/perfil", ProfessionalProfileLive
  end

  scope "/configuracion", OrigenWeb do
    pipe_through [:browser, :require_internal_session, :require_professional]

    get "/profesional", LegacyUrlController, :settings
    get "/profesional/perfil", LegacyUrlController, :profile
  end

  scope "/api/bootstrap", OrigenWeb do
    pipe_through :api

    post "/provider-events", ProviderEventController, :create
  end

  scope "/", OrigenWeb do
    pipe_through :api

    get "/health", HealthController, :index
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

      live "/professional-availability", OrigenWeb.ProfessionalAvailabilityPreviewLive
      live "/pagos-turnos", OrigenWeb.AppointmentPaymentPreviewLive
      live_dashboard "/dashboard", metrics: OrigenWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
