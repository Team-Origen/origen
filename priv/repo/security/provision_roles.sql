\set ON_ERROR_STOP on
\getenv owner_role ORIGEN_OWNER_ROLE
\getenv migrator_role ORIGEN_MIGRATOR_ROLE
\getenv runtime_role ORIGEN_RUNTIME_ROLE
\getenv verifier_role ORIGEN_VERIFIER_ROLE
\getenv migrator_password ORIGEN_MIGRATOR_PASSWORD
\getenv runtime_password ORIGEN_RUNTIME_PASSWORD
\getenv verifier_password ORIGEN_VERIFIER_PASSWORD

SELECT format('CREATE ROLE %I', :'owner_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'owner_role') \gexec
SELECT format('CREATE ROLE %I', :'migrator_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'migrator_role') \gexec
SELECT format('CREATE ROLE %I', :'runtime_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'runtime_role') \gexec
SELECT format('CREATE ROLE %I', :'verifier_role')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'verifier_role') \gexec

SELECT format(
  'ALTER ROLE %I NOLOGIN INHERIT NOCREATEROLE NOCREATEDB NOSUPERUSER NOREPLICATION NOBYPASSRLS',
  :'owner_role'
) \gexec

SELECT format(
  'ALTER ROLE %I LOGIN NOINHERIT NOCREATEROLE NOCREATEDB NOSUPERUSER NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'migrator_role', :'migrator_password'
) \gexec
SELECT format(
  'ALTER ROLE %I LOGIN NOINHERIT NOCREATEROLE NOCREATEDB NOSUPERUSER NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'runtime_role', :'runtime_password'
) \gexec
SELECT format(
  'ALTER ROLE %I LOGIN NOINHERIT NOCREATEROLE NOCREATEDB NOSUPERUSER NOREPLICATION NOBYPASSRLS PASSWORD %L',
  :'verifier_role', :'verifier_password'
) \gexec

SELECT format('REVOKE %I FROM %I', parent.rolname, member.rolname)
FROM pg_auth_members membership
JOIN pg_roles parent ON parent.oid = membership.roleid
JOIN pg_roles member ON member.oid = membership.member
WHERE parent.rolname = :'owner_role' AND member.rolname IN (:'runtime_role', :'verifier_role') \gexec
SELECT format('GRANT %I TO %I WITH INHERIT FALSE, SET TRUE', :'owner_role', :'migrator_role') \gexec

SELECT format('ALTER DATABASE %I OWNER TO %I', current_database(), :'owner_role') \gexec
REVOKE ALL ON DATABASE :DBNAME FROM PUBLIC;
SELECT format('GRANT CONNECT ON DATABASE %I TO %I, %I, %I',
              current_database(), :'migrator_role', :'runtime_role', :'verifier_role') \gexec

SELECT format('ALTER SCHEMA public OWNER TO %I', :'owner_role') \gexec
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
