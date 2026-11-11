/* Throwaway UI preview: three navbar compositions, ?variant=A|B|C.
 * All routes are simulated fragment state, never production requests.
 * Pure state helpers are exported only for local deterministic checks.
 */
const pages = {
  administrador: {
    accounts: { title: 'Cuentas', path: '/administrador/cuentas', section: 'accounts', pending: false }
  },
  paciente: {
    turns: { title: 'Mis turnos', path: '/paciente/turnos', section: 'turns', pending: true },
    booking: { title: 'Reservar turno', path: '/paciente/turnos/reservar', section: 'booking', pending: false }
  },
  secretaria: {
    agenda: { title: 'Agenda', path: '/secretaria/agenda', section: 'agenda', pending: true },
    patients: { title: 'Pacientes', path: '/secretaria/pacientes', section: 'patients', pending: false },
    summary: { title: 'Resumen económico', path: '/secretaria/resumen-economico', section: 'summary', pending: true }
  },
  profesional: {
    requests: { title: 'Solicitudes', path: null, section: 'requests', pending: true },
    agenda: { title: 'Agenda', path: '/profesional/agenda', section: 'agenda', pending: false },
    create: { title: 'Crear turno', path: '/profesional/agenda/crear', section: 'agenda', pending: false },
    summary: { title: 'Resumen económico', path: '/profesional/resumen-economico', section: 'summary', pending: true },
    settings: { title: 'Ajustes', path: '/profesional/ajustes', section: 'settings', pending: false },
    profile: { title: 'Mi perfil', path: '/profesional/ajustes/perfil', section: 'settings', pending: false }
  }
};
const menus = { paciente: ['turns', 'booking'], profesional: ['agenda', 'requests', 'summary', 'settings'], secretaria: ['agenda', 'patients', 'summary'], administrador: ['accounts'] };
const variants = { A: 'Una línea · fondo blanco', B: 'Una línea · fondo petróleo', C: 'Dos niveles · pestañas' };
function getState(search, hash) {
  const query = new URLSearchParams(search);
  const fragment = new URLSearchParams(hash.replace(/^#/, ''));
  const role = Object.hasOwn(pages, fragment.get('role')) ? fragment.get('role') : 'paciente';
  const candidate = fragment.get('page');
  return {
    role,
    page: Object.hasOwn(pages[role], candidate) ? candidate : menus[role][0],
    variant: Object.hasOwn(variants, query.get('variant')) ? query.get('variant') : 'A'
  };
}
function nextVariant(current, direction) {
  const keys = Object.keys(variants);
  return keys[(keys.indexOf(current) + direction + keys.length) % keys.length];
}
function link(role, page, label, className = '') {
  return `<a class="${className}" href="#role=${role}&page=${page}">${label}</a>`;
}
if (typeof module !== 'undefined') module.exports = { pages, menus, variants, getState, nextVariant };

if (typeof document !== 'undefined') {
  const $ = id => document.getElementById(id);
  let state;
  let simulatedExit = false;
  let previousLocation;
  let selectedProfessional = 'ana';
  function adminAccounts() {
    return title('Administración · cuentas internas', 'Cuentas', 'Gestión de cuentas de Profesional y Secretaría, sin acceso a información operativa de pacientes, agendas o pagos.') +
      '<div class="notice"><p>Actual: crear cuenta y emitir invitación en /admin/internal. Destino previsto: /administrador/cuentas. El ciclo completo de edición, desactivación y reactivación pertenece a #279 y todavía está pendiente. Todo lo que ves aquí es ficticio.</p></div>' +
      '<details class="panel"><summary>Crear cuenta / emitir invitación</summary><p>Representación del formulario existente. No se generan cuentas, invitaciones ni tokens.</p><div class="field"><label for="account-role">Rol de la cuenta</label><select id="account-role"><option value="professional">Profesional</option><option value="secretary">Secretaría</option></select></div><div class="field"><label for="account-email">Correo electrónico de ejemplo</label><input id="account-email" type="email" placeholder="persona@example.test" autocomplete="off"></div><button type="button" class="primary" data-feedback="Creación e invitación simuladas. No se guardó una cuenta ni se envió ningún correo.">Crear cuenta / emitir invitación</button></details>' +
      '<h2 style="margin-top:32px">Gestión de cuentas · propuesta #279</h2><div class="stack"><article class="panel"><div class="title-row"><div><h2>Ana Martínez · Profesional</h2><p>ana@example.test · Activa · datos ficticios</p></div><span class="pill">Ciclo de gestión pendiente</span></div><details><summary>Editar cuenta, incluido correo</summary><p>Ejemplo de edición dentro de Cuentas; no define una pantalla o URL nueva.</p><div class="field"><label for="edit-email">Correo de ejemplo</label><input id="edit-email" type="email" value="ana@example.test" autocomplete="off"></div><button type="button" data-feedback="Edición simulada. No se cambió el correo de ninguna cuenta.">Simular guardar cambios</button></details><details style="margin-top:24px"><summary>Desactivar cuenta</summary><p>Ejemplo: 4 turnos futuros afectados. La desactivación debe cortar el acceso y las nuevas reservas, conservar historia y turnos existentes, sin cancelarlos automáticamente. El seguimiento corresponde a Secretaría; no se exponen pacientes ni detalles de agenda aquí.</p><button type="button" data-feedback="Desactivación sólo ilustrativa: no se cortó ningún acceso ni se modificaron reservas. El contador de afectados es ficticio.">Simular desactivación</button></details></article><article class="panel"><h2>Laura Gómez · Secretaría</h2><p>laura@example.test · Inactiva · datos ficticios</p><details><summary>Reactivar cuenta</summary><p>Reactivar restablece el acceso, pero no restaura turnos cancelados. Este borrador no ejecuta cambios de estado.</p><button type="button" data-feedback="Reactivación simulada. No se restauró ninguna cuenta ni ningún turno cancelado.">Simular reactivación</button></details></article></div>';
  }
  function professionalSelector() {
    return `<div class="toolbar"><label for="professional">Profesional</label><select id="professional"><option value="ana"${selectedProfessional === 'ana' ? ' selected' : ''}>Dra. Ana Martínez · Clínica médica</option><option value="martin"${selectedProfessional === 'martin' ? ' selected' : ''}>Dr. Martín Suárez · Clínica médica</option></select><span class="pill">Un Profesional por vez · datos ficticios</span></div>`;
  }
  function secretaryAgenda() {
    const professional = selectedProfessional === 'ana' ? 'Dra. Ana Martínez' : 'Dr. Martín Suárez';
    return title('Operación del centro', 'Agenda', 'Seleccioná un Profesional para consultar su agenda. Esta vista es una propuesta, no una pantalla implementada.', button('patients', 'Agendar paciente')) +
      placeholder('Agenda de Secretaría pendiente. El acceso a la reserva asistida reutiliza Pacientes; es una conexión propuesta.') + professionalSelector() +
      `<div class="stack"><article class="panel appointment"><div class="day"><strong>09:00</strong>30 min</div><div class="grow"><h2>${selectedProfessional === 'ana' ? 'Lucía Fernández' : 'Sofía Pérez'}</h2><p>${professional} · Confirmado · Pago pendiente</p></div><button type="button" data-feedback="Acciones simuladas: cancelación, asistencia y pagos, según permisos de Secretaría. No se modifican turnos reales.">Ver acciones</button></article><article class="panel appointment"><div class="day"><strong>10:30</strong>30 min</div><div class="grow"><h2>Solicitud pendiente · ejemplo</h2><p>${professional} · Sólo el Profesional dueño puede aceptar o rechazar (#284).</p></div><span class="pill">Pendiente de resolución profesional</span></article></div>`;
  }
  function secretaryPatients() {
    return title('Atención asistida', 'Pacientes', 'Entrada al recorrido existente de búsqueda, registro, acceso por correo y reserva asistida.') +
      '<div class="panel"><h2>Buscar paciente</h2><p>Representación esquemática del recorrido actual; no consulta pacientes ni guarda datos.</p><div class="field"><label for="document-number">Documento ficticio</label><input id="document-number" placeholder="Ingresá un documento de ejemplo" inputmode="numeric"></div><div class="toolbar"><button type="button" data-feedback="Búsqueda simulada: no se envía el documento ni se consulta información real.">Buscar paciente</button><button type="button" data-feedback="Registro asistido simulado. No se crea ninguna persona o cuenta.">Registrar paciente</button></div></div><div class="panel" style="margin-top:24px"><h2>Lucía Fernández · paciente ficticia</h2><p>Ejemplo de resultado. Las acciones siguientes pertenecen al mismo recorrido, sin URLs nuevas.</p><div class="toolbar"><button type="button" data-feedback="Reserva asistida simulada. En modo manual, el resultado depende de la regla de Secretaría configurada por el Profesional (#284).">Reservar turno asistido</button><button type="button" data-feedback="Vinculación de acceso por correo simulada; no se envían mensajes.">Gestionar acceso por correo</button></div></div>';
  }
  function title(kicker, heading, description, action = '') {
    return `<div class="title-row"><div><div class="eyebrow">${kicker}</div><h1>${heading}</h1><p class="lead">${description}</p></div>${action}</div>`;
  }
  function button(page, label) { return `<button type="button" data-page="${page}" class="primary">${label}</button>`; }
  function placeholder(message) { return `<div class="notice"><p>${message} Vista de ejemplo; no es una pantalla productiva.</p></div>`; }
  function patientTurns() {
    return title('Tu atención, en un solo lugar', 'Mis turnos', 'Consultá tus próximas consultas y encontrá un nuevo horario cuando lo necesites.', button('booking', 'Reservar turno')) +
      placeholder('Pantalla prevista para la beta, todavía pendiente.') +
      '<div class="stack"><article class="panel appointment"><div class="day">JUN<strong>24</strong></div><div class="grow"><h2>Consulta de clínica médica</h2><p>Dra. Ana Martínez · 10:30 h · 30 minutos</p><p>Precio final: $18.000 · Pago pendiente</p></div><span class="pill">Confirmado · ejemplo</span><button type="button" data-feedback="Cancelación simulada: este ejemplo no modifica ningún turno.">Cancelar turno</button></article><article class="panel appointment"><div class="day">JUL<strong>02</strong></div><div class="grow"><h2>Consulta de seguimiento</h2><p>Dr. Martín Suárez · 15:00 h · 30 minutos</p><p>Precio final: $15.000 · Pago pendiente</p></div><span class="pill">Solicitud pendiente · ejemplo</span></article></div>';
  }
  function booking(professional = false) {
    return `<div class="subnav">${link(state.role, professional ? 'agenda' : 'turns', professional ? '← Volver a Agenda' : '← Volver a Mis turnos')}</div>` +
      title(professional ? 'Agenda propia' : 'Una nueva consulta', professional ? 'Crear turno' : 'Reservar turno', professional ? 'Ejemplo visual de la entrada al recorrido existente de selección o registro de paciente.' : 'Ejemplo visual del recorrido existente: Profesional, tipo de consulta y horario.') +
      '<div class="panel"><h2>Elegí cómo continuar</h2><p>Este contenido es una representación esquemática, no reemplaza ni rediseña el formulario existente.</p><div class="toolbar">' +
      (professional ? '<button type="button" data-feedback="Selección de paciente simulada. No se consultan pacientes reales.">Seleccionar paciente</button><button type="button" data-feedback="Registro asistido simulado. No se guardan datos.">Registrar paciente</button>' : '<button type="button" data-feedback="Selección de Profesional simulada. No se consulta disponibilidad real.">Elegir Profesional</button>') +
      '<button type="button" data-feedback="Selección de horario simulada; no se reserva ningún turno.">Consultar horarios</button></div></div>';
  }
  function agenda() {
    return title('Miércoles · ejemplo de agenda diaria', 'Tu agenda', 'La operación de tus turnos, sin salir de tu espacio de trabajo.', button('create', 'Crear turno')) +
      '<div class="toolbar"><button type="button" data-feedback="Día anterior: control ilustrativo de la agenda.">← Anterior</button><span class="pill">24 de junio · datos ficticios</span><button type="button" data-feedback="Día siguiente: control ilustrativo de la agenda.">Siguiente →</button></div><div class="stack">' +
      '<article class="panel appointment"><div class="day"><strong>09:00</strong>30 min</div><div class="grow"><h2>Lucía Fernández</h2><p>Consulta inicial · Confirmado · Pago pendiente</p></div><button type="button" data-feedback="Acciones de turno simuladas: asistencia, cancelación y pago. No hay cambios reales.">Ver acciones</button></article>' +
      '<article class="panel appointment"><div class="day"><strong>10:30</strong>30 min</div><div class="grow"><h2>Diego Torres</h2><p>Consulta de seguimiento · Solicitud pendiente</p></div><button type="button" data-feedback="Resolución de solicitud simulada. No se acepta ni rechaza un turno real.">Resolver solicitud</button></article></div>';
  }
  function summary() {
    const secretary = state.role === 'secretaria';
    const professional = selectedProfessional === 'ana' ? 'Dra. Ana Martínez' : 'Dr. Martín Suárez';
    const paid = secretary && selectedProfessional === 'martin' ? '$120.000' : '$180.000';
    const total = secretary && selectedProfessional === 'martin' ? '$165.000' : '$225.000';
    return title(secretary ? 'Un Profesional por vez' : 'Sólo tu actividad', 'Resumen económico', 'Consulta ilustrativa agrupada por fecha del turno, no por fecha de cobro.') +
      placeholder('Sección pendiente de #288. Los importes son ficticios.') +
      (secretary ? professionalSelector() + `<h2>Resumen de ${professional}</h2>` : '') +
      '<div class="grid"><article class="panel"><h2>Pagado</h2><strong>' + paid + '</strong><p>Incluye turnos pagados cancelados o con ausencia.</p></article><article class="panel"><h2>Pendiente</h2><strong>$45.000</strong><p>Sólo confirmados o asistidos impagos.</p></article><article class="panel"><h2>Total considerado</h2><strong>' + total + '</strong><p>No representa caja, deuda ni ingreso neto.</p></article></div>';
  }
  function settings() {
    return title('Tu espacio profesional', 'Ajustes', 'Una sola sección para preparar tu perfil y configurar tu agenda.') +
      '<div class="grid"><article class="panel"><h2>Mi perfil</h2><p>Nombre, especialidad y matrícula. Es una subpantalla de Ajustes, no un ítem extra de la navbar.</p>' + link('profesional', 'profile', 'Ver perfil →') + '</article><article class="panel"><h2>Tipos de consulta</h2><p>Catálogo, duración y precio. Se mantienen dentro de la configuración existente.</p><button type="button" data-feedback="Catálogo ilustrativo; no se editan tipos de consulta reales.">Ver configuración</button></article><article class="panel"><h2>Disponibilidad</h2><p>Intervalos y horarios semanales, sin crear otra pantalla.</p><button type="button" data-feedback="Disponibilidad ilustrativa; no se cambian horarios reales.">Ver horarios</button></article></div>';
  }
  function profile() {
    return `<div class="subnav">${link('profesional', 'settings', '← Volver a Ajustes')}</div>` +
      title('Ajustes / Mi perfil', 'Mi perfil profesional', 'La sección Ajustes permanece activa al entrar a esta subpantalla.') +
      '<div class="panel"><div class="field"><label for="profile-name">Nombre de ejemplo</label><input id="profile-name" value="Ana Martínez" readonly></div><div class="field"><label for="specialty">Especialidad de ejemplo</label><input id="specialty" value="Clínica médica" readonly></div><p>Vista de lectura con datos ficticios. No se guarda ni modifica un perfil.</p></div>';
  }
  function render() {
    state = getState(location.search, location.hash);
    if (previousLocation !== location.hash) simulatedExit = false;
    previousLocation = location.hash;
    const page = pages[state.role][state.page];
    document.body.className = state.variant === 'B' ? 'dark' : state.variant === 'C' ? 'two-row' : '';
    $('role').value = state.role;
    $('home').href = `#role=${state.role}&page=${menus[state.role][0]}`;
    $('logo').src = `../../priv/static/images/origen-logo-${state.variant === 'B' ? 'primary' : 'dark'}.png`;
    $('logo').height = state.variant === 'B' ? 55.2 : 55.25;
    $('nav').innerHTML = menus[state.role].map(key => {
      const active = page.section === key;
      return `<a href="#role=${state.role}&page=${key}"${active ? ' aria-current="page"' : ''}>${pages[state.role][key].title}</a>`;
    }).join('');
    const identity = { paciente: ['María López', 'ML', 'Paciente'], profesional: ['Ana Martínez', 'AM', 'Profesional'], secretaria: ['Laura Gómez', 'LG', 'Secretaría'], administrador: ['Alex Ríos', 'AR', 'Administrador'] }[state.role];
    $('name').textContent = identity[0];
    $('initials').textContent = identity[1];
    $('role-name').textContent = identity[2];
    $('account-description').textContent = state.role === 'paciente' ? 'Salida visual de demostración. El mecanismo real de cierre de Paciente no está definido aquí.' : 'En producción se reutilizaría POST /logout. Este prototipo no envía solicitudes.';
    $('variant-label').innerHTML = `<small>Comparador de prototipo · ${state.variant}</small>${variants[state.variant]}`;
    const views = { requests: () => title('Solicitudes', 'Próximo en implementar', 'Esta vista es sólo un marcador del prototipo. El diseño y la funcionalidad se definirán en la issue correspondiente.'), accounts: adminAccounts, turns: patientTurns, booking: () => booking(), agenda: state.role === 'secretaria' ? secretaryAgenda : agenda, patients: secretaryPatients, create: () => booking(true), summary, settings, profile };
    $('main').innerHTML = simulatedExit ? '<div class="panel empty"><div class="eyebrow">Simulación, no autenticación</div><h1>Salida simulada</h1><p>No se cerró ninguna sesión real. El selector de rol sigue disponible para explorar el diseño.</p><button type="button" class="primary" data-page="' + menus[state.role][0] + '">Volver a la simulación</button></div>' : views[state.page]() +
      `<div id="feedback" role="status" aria-live="polite"></div><div class="route"><p>${page.path ? `URL futura representada: <code>${page.path}</code>` : 'URL productiva: todavía no definida. Esta vista existe sólo en el prototipo.'}</p><p>${page.pending ? 'Pantalla productiva pendiente.' : 'Recorrido existente, representado aquí con contenido simplificado.'} Navegación por fragmentos; esta URL no se solicita al servidor.</p><p>Estado del prototipo: ${state.role} · ${state.page} · diseño ${state.variant}. Sin persistencia ni datos reales.</p></div>`;
    $('account').open = false;
  }
  function navigate(page) {
    simulatedExit = false;
    const hash = `#role=${state.role}&page=${page}`;
    if (location.hash === hash) render(); else location.hash = hash;
  }
  function changeVariant(direction) {
    const url = new URL(location.href);
    url.searchParams.set('variant', nextVariant(state.variant, direction));
    history.replaceState(null, '', url);
    render();
  }
  $('role').addEventListener('change', event => {
    const role = event.target.value;
    location.hash = `role=${role}&page=${menus[role][0]}`;
  });
  $('logout').addEventListener('click', () => {
    simulatedExit = true;
    render();
    $('main').focus();
  });
  $('main').addEventListener('change', event => {
    if (state.role === 'secretaria' && event.target.id === 'professional') {
      selectedProfessional = event.target.value === 'martin' ? 'martin' : 'ana';
      render();
      $('main').querySelector('#professional').focus();
    }
  });
  $('main').addEventListener('click', event => {
    const target = event.target.closest('button');
    if (!target) return;
    if (target.dataset.page) navigate(target.dataset.page);
    if (target.dataset.feedback) $('feedback').textContent = target.dataset.feedback;
  });
  $('previous').addEventListener('click', () => changeVariant(-1));
  $('next').addEventListener('click', () => changeVariant(1));
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && $('account').open) {
      $('account').open = false;
      $('account').querySelector('summary').focus();
    }
    if (event.target.closest('input, textarea, select, button, a, summary, [contenteditable]')) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      changeVariant(event.key === 'ArrowRight' ? 1 : -1);
    }
  });
  document.addEventListener('click', event => {
    if (!$('account').contains(event.target)) $('account').open = false;
  });
  window.addEventListener('hashchange', () => { render(); $('main').focus(); });
  window.addEventListener('popstate', render);
  render();
}
