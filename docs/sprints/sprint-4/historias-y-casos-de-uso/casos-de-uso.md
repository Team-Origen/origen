# Diagramas de casos de uso — Sprint 4

Corte: `develop` @ `0c38d8a` (2026-11-11). Representan el mismo alcance que las [historias de usuario](./historias-de-usuario.md).

## 1. Criterio de selección y organización

**Qué se incluye**

- Solo capacidades **implementadas** al corte (secciones 1 a 5 de las historias). Lo pendiente, las maquetas con datos ficticios (pagos, resumen económico) y lo excluido de la beta no se dibujan.
- Cada caso de uso es un objetivo del actor frente al sistema («Reservar turno», «Resolver solicitud»), no una pantalla, botón ni ruta. Por eso, por ejemplo, configurar intervalo, tipos de consulta, disponibilidad, anticipación y horizonte se agrupan en un único caso «Configurar agenda».
- Se usan `«include»` solo cuando un paso es obligatorio y se repite en varios casos (verificar disponibilidad, registrar la relación Profesional–Paciente, buscar paciente por documento). No se usan `«extend»`: las variantes se describen en los criterios de aceptación.
- Las reglas de permisos (denegación por defecto, privacidad, estados) no se dibujan como casos; están en las reglas transversales de las historias.

**Actores**

| Actor | Tipo | Motivo de inclusión |
| --- | --- | --- |
| Paciente | Rol de aplicación | Reserva, consulta y cancela sus turnos. |
| Profesional | Rol de aplicación (usuario interno) | Configura y opera su agenda. |
| Secretaría | Rol de aplicación (usuario interno) | Registra pacientes y opera todas las agendas. |
| Administrador | Rol de aplicación (usuario interno) | Administra las cuentas del personal. |
| Usuario interno | Actor abstracto | Generaliza a Profesional, Secretaría y Administrador para activar cuenta e iniciar sesión. |
| Operador de despliegue | Actor externo | Único actor del alta del primer Administrador (fuera de la aplicación). |
| Sistema (temporizador) | Actor secundario | Vence solicitudes no resueltas. |

**Organización**

Se eligió una combinación: un **diagrama general** con los casos principales de cada actor para la visión de conjunto, y **un diagrama por rol** con el detalle legible. Un único diagrama con los 26 casos y sus relaciones resultaba ilegible; diagramas solo por funcionalidad repetían actores sin mostrar qué puede hacer cada rol, que es lo que pide la entrega.

**Notación**

Mermaid no tiene un tipo de diagrama de casos de uso, por lo que se usa un diagrama de flujo con convenciones UML: actores como nodos con «actor», casos de uso como elipses, el rectángulo del sistema como `subgraph`, asociaciones con líneas continuas e `«include»` con flechas punteadas. Los identificadores `HU-…` permiten trazar cada caso a su historia.

## 2. Diagrama general

```mermaid
flowchart LR
  PAC["«actor»<br/>Paciente"]
  PRO["«actor»<br/>Profesional"]
  SEC["«actor»<br/>Secretaría"]
  ADM["«actor»<br/>Administrador"]
  SIS["«actor»<br/>Sistema"]

  subgraph ORIGEN["Origen — Gestión de turnos (beta, Sprint 4)"]
    direction TB
    UC_ACC(["Ingresar al sistema"])
    UC_RES(["Reservar o agendar turno"])
    UC_MIS(["Consultar turnos"])
    UC_CAN(["Cancelar turno"])
    UC_CFG(["Configurar agenda y aprobación"])
    UC_SOL(["Resolver solicitud"])
    UC_ASI(["Registrar asistencia o ausencia"])
    UC_REG(["Registrar paciente"])
    UC_COR(["Vincular correo de acceso"])
    UC_CUE(["Administrar cuentas internas"])
    UC_VEN(["Vencer solicitud no resuelta"])
  end

  PAC --- UC_ACC
  PAC --- UC_RES
  PAC --- UC_MIS
  PAC --- UC_CAN

  PRO --- UC_ACC
  PRO --- UC_CFG
  PRO --- UC_SOL
  PRO --- UC_RES
  PRO --- UC_MIS
  PRO --- UC_CAN
  PRO --- UC_ASI
  PRO --- UC_REG
  PRO --- UC_COR

  SEC --- UC_ACC
  SEC --- UC_REG
  SEC --- UC_RES
  SEC --- UC_MIS
  SEC --- UC_CAN
  SEC --- UC_ASI
  SEC --- UC_COR

  ADM --- UC_ACC
  ADM --- UC_CUE

  SIS --- UC_VEN
```

## 3. Acceso al sistema

```mermaid
flowchart LR
  OPE["«actor»<br/>Operador de despliegue"]
  INT["«actor»<br/>Usuario interno"]
  PRO["«actor»<br/>Profesional"]
  SEC["«actor»<br/>Secretaría"]
  ADM["«actor»<br/>Administrador"]
  PAC["«actor»<br/>Paciente"]

  PRO -->|generaliza| INT
  SEC -->|generaliza| INT
  ADM -->|generaliza| INT

  subgraph ORIGEN["Origen"]
    direction TB
    A1(["Activar cuenta con invitación<br/>HU-INT-01"])
    A2(["Iniciar y cerrar sesión interna<br/>HU-INT-02"])
    A3(["Solicitar enlace de acceso e ingresar<br/>HU-PAC-01"])
  end

  BOOT(["Incorporar primer Administrador<br/>HU-ADM-01<br/>(proceso de despliegue, fuera de la aplicación)"])

  OPE --- BOOT
  INT --- A1
  INT --- A2
  PAC --- A3
```

## 4. Paciente

```mermaid
flowchart LR
  PAC["«actor»<br/>Paciente"]

  subgraph ORIGEN["Origen"]
    direction TB
    P1(["Solicitar enlace de acceso e ingresar<br/>HU-PAC-01"])
    P2(["Reservar turno propio<br/>HU-PAC-02"])
    P3(["Consultar Mis turnos<br/>HU-PAC-03"])
    P4(["Cancelar turno propio<br/>HU-PAC-04"])
    I1(["Verificar disponibilidad"])
    I2(["Registrar relación Profesional–Paciente"])
  end

  PAC --- P1
  PAC --- P2
  PAC --- P3
  PAC --- P4
  P2 -.->|«include»| I1
  P2 -.->|«include»| I2
```

## 5. Profesional

```mermaid
flowchart LR
  PRO["«actor»<br/>Profesional"]
  SIS["«actor»<br/>Sistema"]

  subgraph ORIGEN["Origen"]
    direction TB
    R1(["Completar perfil profesional<br/>HU-PRO-01"])
    R2(["Configurar agenda y tipos de consulta<br/>HU-PRO-02"])
    R3(["Elegir modalidad de aprobación<br/>HU-PRO-03"])
    R4(["Resolver solicitud de turno<br/>HU-PRO-04"])
    R5(["Consultar agenda propia<br/>HU-PRO-05"])
    R6(["Crear turno para paciente registrado<br/>HU-PRO-06"])
    R7(["Registrar paciente nuevo y agendarlo<br/>HU-PRO-07"])
    R8(["Cancelar turno con motivo<br/>HU-OPE-01"])
    R9(["Registrar asistencia o ausencia<br/>HU-OPE-02"])
    R10(["Vincular correo de acceso<br/>HU-OPE-03"])
    R11(["Vencer solicitud no resuelta<br/>HU-SIS-01"])
    I1(["Verificar disponibilidad"])
    I2(["Registrar relación Profesional–Paciente"])
    I3(["Buscar paciente por DNI exacto"])
  end

  PRO --- R1
  PRO --- R2
  PRO --- R3
  PRO --- R4
  PRO --- R5
  PRO --- R6
  PRO --- R7
  PRO --- R8
  PRO --- R9
  PRO --- R10
  SIS --- R11

  R6 -.->|«include»| I1
  R6 -.->|«include»| I2
  R7 -.->|«include»| I3
  R7 -.->|«include»| I1
  R7 -.->|«include»| I2
```

## 6. Secretaría

```mermaid
flowchart LR
  SEC["«actor»<br/>Secretaría"]

  subgraph ORIGEN["Origen"]
    direction TB
    S1(["Buscar paciente por documento<br/>HU-SEC-01"])
    S2(["Registrar paciente<br/>HU-SEC-02"])
    S3(["Agendar turno asistido<br/>HU-SEC-03"])
    S4(["Consultar agendas del centro<br/>HU-SEC-04"])
    S5(["Cancelar turno con motivo<br/>HU-OPE-01"])
    S6(["Registrar asistencia o ausencia<br/>HU-OPE-02"])
    S7(["Vincular correo de acceso<br/>HU-OPE-03"])
    I1(["Verificar disponibilidad"])
    I2(["Registrar relación Profesional–Paciente"])
  end

  SEC --- S1
  SEC --- S2
  SEC --- S3
  SEC --- S4
  SEC --- S5
  SEC --- S6
  SEC --- S7

  S2 -.->|«include»| S1
  S3 -.->|«include»| I1
  S3 -.->|«include»| I2
```

## 7. Administrador

```mermaid
flowchart LR
  ADM["«actor»<br/>Administrador"]

  subgraph ORIGEN["Origen"]
    direction TB
    D1(["Crear cuenta interna e invitar<br/>HU-ADM-02"])
    D2(["Reemitir invitación<br/>HU-ADM-03"])
    D3(["Editar correo de cuenta interna<br/>HU-ADM-04"])
    D4(["Desactivar cuenta interna<br/>HU-ADM-05"])
    D5(["Reactivar cuenta interna<br/>HU-ADM-05"])
  end

  ADM --- D1
  ADM --- D2
  ADM --- D3
  ADM --- D4
  ADM --- D5
```

El Administrador no tiene casos de uso sobre pacientes, agendas, turnos ni datos económicos (denegación por defecto, contrato #372).

## 8. Trazabilidad entre diagramas e historias

| Caso del diagrama general | Historias | Actores |
| --- | --- | --- |
| Ingresar al sistema | HU-INT-01, HU-INT-02, HU-PAC-01 (y HU-ADM-01 fuera de la aplicación) | Todos |
| Reservar o agendar turno | HU-PAC-02, HU-PRO-06, HU-PRO-07, HU-SEC-03 | Paciente, Profesional, Secretaría |
| Consultar turnos | HU-PAC-03, HU-PRO-05, HU-SEC-04 | Paciente, Profesional, Secretaría |
| Cancelar turno | HU-PAC-04, HU-OPE-01 | Paciente, Profesional, Secretaría |
| Configurar agenda y aprobación | HU-PRO-01, HU-PRO-02, HU-PRO-03 | Profesional |
| Resolver solicitud | HU-PRO-04 | Profesional |
| Registrar asistencia o ausencia | HU-OPE-02 | Profesional, Secretaría |
| Registrar paciente | HU-SEC-01, HU-SEC-02, HU-PRO-07 | Secretaría, Profesional |
| Vincular correo de acceso | HU-OPE-03 | Profesional, Secretaría |
| Administrar cuentas internas | HU-ADM-02 a HU-ADM-05 | Administrador |
| Vencer solicitud no resuelta | HU-SIS-01 | Sistema |
