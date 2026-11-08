defmodule OrigenWeb.Navigation do
  use OrigenWeb, :html

  attr :current, :atom, default: nil

  def patient_navigation(assigns) do
    ~H"""
    <nav
      id="patient-navigation"
      aria-label="Navegación de paciente"
      class="border-b border-stone-200 bg-white px-4 py-3 sm:px-6"
    >
      <div class="mx-auto flex max-w-4xl flex-wrap items-center gap-2">
        <.link
          navigate={~p"/paciente/turnos"}
          aria-current={if @current == :appointments, do: "page"}
          class={nav_class(@current == :appointments)}
        >
          Mis turnos
        </.link>
        <.link
          navigate={~p"/paciente/turnos/reservar"}
          aria-current={if @current == :booking, do: "page"}
          class={nav_class(@current == :booking)}
        >
          Reservar turno
        </.link>
      </div>
    </nav>
    """
  end

  def secretary_navigation(assigns) do
    ~H"""
    <nav
      id="secretary-navigation"
      aria-label="Navegación de Secretaría"
      class="border-b border-stone-200 bg-white px-4 py-3 sm:px-6"
    >
      <div class="mx-auto flex max-w-5xl flex-wrap items-center gap-2">
        <.link
          navigate={~p"/secretaria/agenda"}
          aria-current={if @current == :agenda, do: "page"}
          class={nav_class(@current == :agenda)}
        >
          Agenda del centro
        </.link>
        <.link
          navigate={~p"/secretaria/pacientes"}
          aria-current={if @current == :patients, do: "page"}
          class={nav_class(@current == :patients)}
        >
          Pacientes
        </.link>
      </div>
    </nav>
    """
  end

  defp nav_class(true),
    do: "rounded-md bg-[#DDE6DB] px-3 py-2 text-sm font-semibold text-[#0A3847]"

  defp nav_class(false),
    do: "rounded-md px-3 py-2 text-sm font-medium text-[#35545A] hover:bg-[#F6F6F4]"
end
