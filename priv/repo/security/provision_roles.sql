\set ON_ERROR_STOP on
\getenv owner_role ORIGEN_OWNER_ROLE
\getenv migrator_role ORIGEN_MIGRATOR_ROLE
\getenv runtime_role ORIGEN_RUNTIME_ROLE
\getenv verifier_role ORIGEN_VERIFIER_ROLE
\getenv migrator_password ORIGEN_MIGRATOR_PASSWORD
\getenv runtime_password ORIGEN_RUNTIME_PASSWORD
\getenv verifier_password ORIGEN_VERIFIER_PASSWORD

BEGIN;
-- A non-superuser cannot clear these attributes; reject unsafe existing roles
-- before creating or changing any role, regardless of the provisioner's rights.
SELECT format(
  'DO $do$ BEGIN IF EXISTS (SELECT FROM pg_roles WHERE rolname = ANY (ARRAY[%L, %L, %L, %L]) AND (rolsuper OR rolreplication OR rolbypassrls)) THEN RAISE EXCEPTION ''Existing application role has elevated attributes''; END IF; END $do$;',
  :'owner_role', :'migrator_role', :'runtime_role', :'verifier_role'
) \gexec

-- An application role must not retain access through another role. The only
-- expected incoming membership on rerun is migrator -> owner with exact rights.
SELECT format(
  'DO $do$ BEGIN IF EXISTS (
     SELECT FROM pg_auth_members membership
     JOIN pg_roles member ON member.oid = membership.member
     JOIN pg_roles parent ON parent.oid = membership.roleid
     WHERE member.rolname = ANY (ARRAY[%L, %L, %L, %L])
       AND NOT (member.rolname = %L AND parent.rolname = %L
         AND NOT membership.admin_option AND NOT membership.inherit_option
         AND membership.set_option)
   ) THEN RAISE EXCEPTION ''Existing application role has unexpected membership''; END IF; END $do$;',
  :'owner_role', :'migrator_role', :'runtime_role', :'verifier_role',
  :'migrator_role', :'owner_role'
) \gexec

SELECT format('CREATE ROLE %I', :'owner_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'owner_role') \gexec
SELECT format('CREATE ROLE %I', :'migrator_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'migrator_role') \gexec
SELECT format('CREATE ROLE %I', :'runtime_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'runtime_role') \gexec
SELECT format('CREATE ROLE %I', :'verifier_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'verifier_role') \gexec

SELECT format(
  'ALTER ROLE %I NOLOGIN INHERIT NOCREATEROLE NOCREATEDB%s',
  :'owner_role',
  CASE WHEN (SELECT rolsuper FROM pg_roles WHERE rolname = current_user)
    THEN ' NOSUPERUSER NOREPLICATION NOBYPASSRLS' ELSE '' END
) \gexec

SELECT format(
  'ALTER ROLE %I LOGIN NOINHERIT NOCREATEROLE NOCREATEDB%s PASSWORD %L',
  :'migrator_role',
  CASE WHEN (SELECT rolsuper FROM pg_roles WHERE rolname = current_user)
    THEN ' NOSUPERUSER NOREPLICATION NOBYPASSRLS' ELSE '' END,
  :'migrator_password'
) \gexec
SELECT format(
  'ALTER ROLE %I LOGIN NOINHERIT NOCREATEROLE NOCREATEDB%s PASSWORD %L',
  :'runtime_role',
  CASE WHEN (SELECT rolsuper FROM pg_roles WHERE rolname = current_user)
    THEN ' NOSUPERUSER NOREPLICATION NOBYPASSRLS' ELSE '' END,
  :'runtime_password'
) \gexec
SELECT format(
  'ALTER ROLE %I LOGIN NOINHERIT NOCREATEROLE NOCREATEDB%s PASSWORD %L',
  :'verifier_role',
  CASE WHEN (SELECT rolsuper FROM pg_roles WHERE rolname = current_user)
    THEN ' NOSUPERUSER NOREPLICATION NOBYPASSRLS' ELSE '' END,
  :'verifier_password'
) \gexec

SELECT format('REVOKE %I FROM %I', parent.rolname, member.rolname)
FROM pg_auth_members membership
JOIN pg_roles parent ON parent.oid = membership.roleid
JOIN pg_roles member ON member.oid = membership.member
WHERE parent.rolname = :'owner_role' AND member.rolname IN (:'runtime_role', :'verifier_role') \gexec
SELECT format('GRANT %I TO %I WITH INHERIT FALSE, SET TRUE', :'owner_role', :'migrator_role') \gexec

-- The creator's automatic ADMIN grant cannot SET ROLE. A separate, temporary grant
-- is needed to transfer ownership; the automatic ADMIN grant remains afterward.
SELECT format('GRANT %I TO %I WITH ADMIN FALSE, INHERIT FALSE, SET TRUE',
              :'owner_role', current_user) \gexec
-- public is initially owned by pg_database_owner; transfer it before the database.
SELECT format('GRANT CREATE ON DATABASE %I TO %I', current_database(), :'owner_role')
WHERE (SELECT datdba FROM pg_database WHERE datname = current_database()) = (SELECT oid FROM pg_roles WHERE rolname = current_user) \gexec
SELECT format('ALTER SCHEMA public OWNER TO %I', :'owner_role')
WHERE (SELECT nspowner::regrole::text FROM pg_namespace WHERE nspname = 'public') <> :'owner_role' \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), current_user)
WHERE (SELECT datdba FROM pg_database WHERE datname = current_database()) = (SELECT oid FROM pg_roles WHERE rolname = current_user) \gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', current_database(), :'owner_role')
WHERE (SELECT datdba::regrole::text FROM pg_database WHERE datname = current_database()) <> :'owner_role' \gexec

SELECT format('SET ROLE %I', :'owner_role') \gexec
REVOKE ALL ON DATABASE :DBNAME FROM PUBLIC;
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', current_database(), session_user) \gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I, %I, %I',
              current_database(), :'migrator_role', :'runtime_role', :'verifier_role') \gexec
REVOKE ALL ON SCHEMA public FROM PUBLIC;
SELECT format('GRANT USAGE ON SCHEMA public TO %I, %I, %I',
              :'migrator_role', :'runtime_role', :'verifier_role') \gexec

SELECT format('REVOKE ALL ON TABLE public.audit_events FROM %I, %I',
              :'runtime_role', :'verifier_role')
WHERE to_regclass('public.audit_events') IS NOT NULL \gexec
SELECT format('REVOKE ALL ON SEQUENCE public.audit_events_id_seq FROM %I, %I',
              :'runtime_role', :'verifier_role')
WHERE to_regclass('public.audit_events_id_seq') IS NOT NULL \gexec
SELECT format('REVOKE ALL ON FUNCTION public.reject_audit_event_mutation() FROM %I, %I',
              :'runtime_role', :'verifier_role')
WHERE to_regprocedure('public.reject_audit_event_mutation()') IS NOT NULL \gexec

SELECT format(
  'GRANT INSERT (actor_kind, actor_ref, event, entity_kind, entity_ref, result) ON public.audit_events TO %I',
  :'runtime_role'
) WHERE to_regclass('public.audit_events') IS NOT NULL \gexec
SELECT format('GRANT USAGE ON SEQUENCE public.audit_events_id_seq TO %I', :'runtime_role')
WHERE to_regclass('public.audit_events_id_seq') IS NOT NULL \gexec
SELECT format('GRANT SELECT, UPDATE, DELETE, TRUNCATE ON public.audit_events TO %I', :'verifier_role')
WHERE to_regclass('public.audit_events') IS NOT NULL \gexec

SELECT format('GRANT SELECT, INSERT, UPDATE ON public.internal_accounts TO %I', :'runtime_role')
WHERE to_regclass('public.internal_accounts') IS NOT NULL \gexec
SELECT format('GRANT SELECT, UPDATE ON public.admin_bootstrap_controls TO %I', :'runtime_role')
WHERE to_regclass('public.admin_bootstrap_controls') IS NOT NULL \gexec
SELECT format(
  'GRANT SELECT, INSERT, UPDATE ON public.internal_account_invitations TO %I',
  :'runtime_role'
) WHERE to_regclass('public.internal_account_invitations') IS NOT NULL \gexec
SELECT format(
  'GRANT USAGE ON SEQUENCE public.internal_accounts_id_seq, public.internal_account_invitations_id_seq TO %I',
  :'runtime_role'
) WHERE to_regclass('public.internal_accounts_id_seq') IS NOT NULL
  AND to_regclass('public.internal_account_invitations_id_seq') IS NOT NULL \gexec

SELECT format('REVOKE ALL ON public.internal_accounts FROM %I', :'verifier_role')
WHERE to_regclass('public.internal_accounts') IS NOT NULL \gexec
SELECT format(
  'GRANT SELECT ON public.internal_account_verifier_projection, public.admin_bootstrap_controls, public.internal_account_invitations TO %I',
  :'verifier_role'
) WHERE to_regclass('public.internal_account_verifier_projection') IS NOT NULL
  AND to_regclass('public.admin_bootstrap_controls') IS NOT NULL
  AND to_regclass('public.internal_account_invitations') IS NOT NULL \gexec

SELECT format('REVOKE ALL ON TABLE public.agenda_settings, public.consultation_types FROM %I, %I',
              :'runtime_role', :'verifier_role')
WHERE to_regclass('public.agenda_settings') IS NOT NULL
  AND to_regclass('public.consultation_types') IS NOT NULL \gexec
SELECT format('REVOKE ALL ON SEQUENCE public.agenda_settings_id_seq FROM %I, %I',
              :'runtime_role', :'verifier_role')
WHERE to_regclass('public.agenda_settings_id_seq') IS NOT NULL \gexec

SELECT format(
  'GRANT SELECT, INSERT, UPDATE ON public.agenda_settings, public.consultation_types TO %I',
  :'runtime_role'
) WHERE to_regclass('public.agenda_settings') IS NOT NULL
  AND to_regclass('public.consultation_types') IS NOT NULL \gexec
SELECT format('GRANT USAGE ON SEQUENCE public.agenda_settings_id_seq TO %I', :'runtime_role')
WHERE to_regclass('public.agenda_settings_id_seq') IS NOT NULL \gexec

RESET ROLE;
SELECT format('REVOKE %I FROM %I', :'owner_role', current_user) \gexec
COMMIT;
