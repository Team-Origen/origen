#!/usr/bin/env bash
set -euo pipefail

: "${ORIGEN_TEST_DB_USERNAME:?ORIGEN_TEST_DB_USERNAME must be supplied}"
: "${ORIGEN_TEST_DB_PASSWORD:?ORIGEN_TEST_DB_PASSWORD must be supplied}"

if [[ -n "${ORIGEN_DATABASE_URL:-}" ]]; then
  printf '%s\n' 'ORIGEN_DATABASE_URL must be unset for the disposable concurrency runner' >&2
  exit 2
fi

for command in mix psql; do
  command -v "$command" >/dev/null || {
    printf 'missing required command: %s\n' "$command" >&2
    exit 2
  }
done

[[ -d deps ]] || { printf '%s\n' 'deps directory is required' >&2; exit 2; }
[[ -d _build ]] || { printf '%s\n' '_build directory is required' >&2; exit 2; }
mix --version >/dev/null

available_kib=$(df -Pk . | awk 'NR == 2 { print $4 }')
if [[ ! "$available_kib" =~ ^[0-9]+$ ]] || ((available_kib < 1048576)); then
  printf '%s\n' 'at least 1 GiB of local filesystem capacity is required' >&2
  exit 2
fi

export PGHOST="${ORIGEN_TEST_DB_HOST:-localhost}"
export PGPORT="${ORIGEN_TEST_DB_PORT:-5432}"
export PGUSER="$ORIGEN_TEST_DB_USERNAME"
export PGPASSWORD="$ORIGEN_TEST_DB_PASSWORD"
unset PGDATABASE
management_db="${ORIGEN_TEST_DB_ADMIN_DATABASE:-postgres}"

partition="_385_concurrency_${BASHPID}_${RANDOM}"
database="origen_test${partition}"
if [[ ! "$partition" =~ ^_385_concurrency_[0-9]+_[0-9]+$ ]] ||
  [[ ! "$database" =~ ^origen_test_385_concurrency_[0-9]+_[0-9]+$ ]]; then
  printf '%s\n' 'generated database name failed its safety check' >&2
  exit 2
fi

if psql -X -v ON_ERROR_STOP=1 -At -d "$management_db" \
  -c "SELECT 1 FROM pg_database WHERE datname = '$database'" | grep -q '^1$'; then
  printf 'refusing to use pre-existing database: %s\n' "$database" >&2
  exit 2
fi

owned=0
cleanup() {
  local exit_code=$?

  if ((owned == 1)); then
    if ! psql -X -v ON_ERROR_STOP=1 -d "$management_db" \
      -c "DROP DATABASE $database WITH (FORCE)"; then
      printf 'failed to drop runner-owned disposable database: %s\n' "$database" >&2
      ((exit_code == 0)) && exit_code=1
    fi
  fi

  exit "$exit_code"
}
trap cleanup EXIT

psql -X -v ON_ERROR_STOP=1 -d "$management_db" -c "CREATE DATABASE $database"
owned=1

set +e
env \
  -u ORIGEN_DATABASE_URL \
  MIX_TEST_PARTITION="$partition" \
  ORIGEN_PAYMENT_CONCURRENCY=1 \
  mix test \
    test/origen/booking/payment_registration_test.exs \
    test/origen/booking/payment_pricing_test.exs \
    test/origen/booking/payment_persistence_test.exs \
    test/origen/booking/payments_test.exs \
    test/origen/booking/authorization_test.exs \
    test/origen/booking/appointment_test.exs \
    test/origen/booking/lifecycle_test.exs \
    test/origen/booking/attendance_test.exs \
    test/origen/booking/payment_concurrency_test.exs
mix_exit=$?
set -e

printf 'disposable concurrency mix test exit: %s\n' "$mix_exit" >&2
exit "$mix_exit"
