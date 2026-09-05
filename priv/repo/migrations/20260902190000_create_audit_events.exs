defmodule Origen.Repo.Migrations.CreateAuditEvents do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE public.audit_events (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      actor_kind varchar(32) NOT NULL,
      actor_ref varchar(128),
      event varchar(64) NOT NULL,
      entity_kind varchar(32),
      entity_ref varchar(128),
      result varchar(32) NOT NULL,
      recorded_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT audit_events_actor_kind_format CHECK (actor_kind ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'),
      CONSTRAINT audit_events_actor_ref_presence CHECK (actor_kind IN ('system', 'anonymous') OR actor_ref IS NOT NULL),
      CONSTRAINT audit_events_actor_ref_nonblank CHECK (actor_ref IS NULL OR btrim(actor_ref) <> ''),
      CONSTRAINT audit_events_event_format CHECK (event ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'),
      CONSTRAINT audit_events_entity_pair CHECK ((entity_kind IS NULL) = (entity_ref IS NULL)),
      CONSTRAINT audit_events_entity_kind_format CHECK (entity_kind IS NULL OR entity_kind ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'),
      CONSTRAINT audit_events_entity_ref_nonblank CHECK (entity_ref IS NULL OR btrim(entity_ref) <> ''),
      CONSTRAINT audit_events_result_vocabulary CHECK (result IN ('allowed', 'denied', 'succeeded', 'failed'))
    )
    """)

    execute("""
    CREATE FUNCTION public.reject_audit_event_mutation() RETURNS trigger
    LANGUAGE plpgsql AS $$
    BEGIN
      RAISE EXCEPTION 'audit_events history is append-only' USING ERRCODE = '55000';
    END
    $$
    """)

    execute("""
    CREATE TRIGGER audit_events_reject_row_mutation
    BEFORE UPDATE OR DELETE ON public.audit_events
    FOR EACH ROW EXECUTE FUNCTION public.reject_audit_event_mutation()
    """)

    execute("""
    CREATE TRIGGER audit_events_reject_truncate
    BEFORE TRUNCATE ON public.audit_events
    FOR EACH STATEMENT EXECUTE FUNCTION public.reject_audit_event_mutation()
    """)

    execute("REVOKE ALL ON public.audit_events FROM PUBLIC")
    execute("REVOKE ALL ON FUNCTION public.reject_audit_event_mutation() FROM PUBLIC")
    execute("REVOKE ALL ON SEQUENCE public.audit_events_id_seq FROM PUBLIC")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT INSERT (actor_kind, actor_ref, event, entity_kind, entity_ref, result)
          ON public.audit_events TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.audit_events_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF to_regclass('public.audit_events') IS NOT NULL AND EXISTS (SELECT FROM public.audit_events) THEN
        RAISE EXCEPTION 'refusing to drop populated audit_events history' USING ERRCODE = '55000';
      END IF;
    END
    $$
    """)

    execute("DROP TABLE IF EXISTS public.audit_events")
    execute("DROP FUNCTION IF EXISTS public.reject_audit_event_mutation()")
  end
end
