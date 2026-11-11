defmodule Origen.Repo.Migrations.AddAppointmentPayments do
  use Ecto.Migration

  @moduledoc """
  Adds the editable final price and one current payment row per appointment.

  Initialization copies the immutable reservation snapshot into `final_price_ars`
  and creates `pending` payment rows for every existing appointment. The down
  migration refuses to remove populated payment data or appointment metadata;
  rollback is therefore only safe on an empty database and never discards
  human payment or correction history.
  """

  def up do
    execute("ALTER TABLE public.appointments ADD COLUMN final_price_ars numeric")

    execute("""
    UPDATE public.appointments
    SET final_price_ars = snapshot_exact_price_ars
    WHERE final_price_ars IS NULL
    """)

    execute("""
    ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_final_price_check CHECK (
      final_price_ars >= 0
      AND final_price_ars NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric)
    )
    """)

    execute("ALTER TABLE public.appointments ALTER COLUMN final_price_ars SET NOT NULL")

    execute("""
    CREATE TABLE public.appointment_payments (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      appointment_id bigint NOT NULL UNIQUE
        REFERENCES public.appointments(id) ON DELETE RESTRICT,
      status varchar(16) NOT NULL DEFAULT 'pending',
      method varchar(16),
      paid_amount_ars numeric,
      paid_actor_kind varchar(16),
      paid_actor_ref varchar(128),
      paid_at timestamptz(6),
      created_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      updated_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT appointment_payments_status_check CHECK (status IN ('pending', 'paid')),
      CONSTRAINT appointment_payments_method_check CHECK (
        method IS NULL OR method IN ('cash', 'transfer')
      ),
      CONSTRAINT appointment_payments_amount_check CHECK (
        paid_amount_ars IS NULL OR (
          paid_amount_ars >= 0
          AND paid_amount_ars NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric)
        )
      ),
      CONSTRAINT appointment_payments_state_check CHECK (
        (status = 'pending' AND method IS NULL AND paid_amount_ars IS NULL
          AND paid_actor_kind IS NULL AND paid_actor_ref IS NULL AND paid_at IS NULL)
        OR
        (status = 'paid' AND method IS NOT NULL AND paid_amount_ars IS NOT NULL
          AND paid_actor_kind IS NOT NULL AND paid_actor_ref IS NOT NULL AND paid_at IS NOT NULL)
      )
    )
    """)

    execute("""
    INSERT INTO public.appointment_payments (appointment_id, status)
    SELECT id, 'pending'
    FROM public.appointments
    ON CONFLICT (appointment_id) DO NOTHING
    """)

    execute("""
    CREATE TABLE public.payment_actions (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      appointment_id bigint NOT NULL
        REFERENCES public.appointments(id) ON DELETE RESTRICT,
      action varchar(16) NOT NULL,
      amount_ars numeric NOT NULL,
      method varchar(16),
      actor_kind varchar(16) NOT NULL,
      actor_ref varchar(128) NOT NULL,
      occurred_at timestamptz(6) NOT NULL DEFAULT clock_timestamp(),
      CONSTRAINT payment_actions_action_check CHECK (action IN ('paid', 'reverted')),
      CONSTRAINT payment_actions_amount_check CHECK (
        amount_ars >= 0
        AND amount_ars NOT IN ('NaN'::numeric, 'Infinity'::numeric, '-Infinity'::numeric)
      ),
      CONSTRAINT payment_actions_method_check CHECK (
        method IS NULL OR method IN ('cash', 'transfer')
      )
    )
    """)

    execute("""
    CREATE FUNCTION public.initialize_appointment_final_price()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      NEW.final_price_ars := NEW.snapshot_exact_price_ars;
      RETURN NEW;
    END;
    $$
    """)

    execute("""
    CREATE TRIGGER appointments_initialize_final_price
    BEFORE INSERT ON public.appointments
    FOR EACH ROW EXECUTE FUNCTION public.initialize_appointment_final_price()
    """)

    execute("""
    CREATE FUNCTION public.initialize_appointment_payment()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      INSERT INTO public.appointment_payments (appointment_id, status)
      VALUES (NEW.id, 'pending')
      ON CONFLICT (appointment_id) DO NOTHING;
      RETURN NEW;
    END;
    $$
    """)

    execute("""
    CREATE TRIGGER appointments_initialize_payment
    AFTER INSERT ON public.appointments
    FOR EACH ROW EXECUTE FUNCTION public.initialize_appointment_payment()
    """)

    execute("""
    CREATE FUNCTION public.reject_payment_action_mutation()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'payment action history is append-only' USING ERRCODE = '23000';
    END;
    $$
    """)

    execute("""
    CREATE TRIGGER payment_actions_append_only
    BEFORE UPDATE OR DELETE ON public.payment_actions
    FOR EACH ROW EXECUTE FUNCTION public.reject_payment_action_mutation()
    """)

    execute("REVOKE ALL ON TABLE public.appointment_payments, public.payment_actions FROM PUBLIC")

    execute(
      "REVOKE ALL ON SEQUENCE public.appointment_payments_id_seq, public.payment_actions_id_seq FROM PUBLIC"
    )

    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT FROM pg_roles WHERE rolname = 'origen_runtime') THEN
        GRANT SELECT, INSERT, UPDATE ON public.appointment_payments TO origen_runtime;
        GRANT SELECT, INSERT ON public.payment_actions TO origen_runtime;
        GRANT USAGE ON SEQUENCE public.appointment_payments_id_seq, public.payment_actions_id_seq TO origen_runtime;
      END IF;
    END
    $$
    """)
  end

  def down do
    execute("""
    DO $$
    BEGIN
      LOCK TABLE public.payment_actions, public.appointment_payments, public.appointments
        IN ACCESS EXCLUSIVE MODE;

      IF EXISTS (SELECT FROM public.payment_actions)
        OR EXISTS (SELECT FROM public.appointment_payments)
        OR EXISTS (SELECT FROM public.appointments)
      THEN
        RAISE EXCEPTION 'refusing to remove populated appointment payment data or history'
          USING ERRCODE = '55000';
      END IF;
    END
    $$
    """)

    execute("DROP TRIGGER IF EXISTS payment_actions_append_only ON public.payment_actions")
    execute("DROP FUNCTION IF EXISTS public.reject_payment_action_mutation()")
    execute("DROP TRIGGER IF EXISTS appointments_initialize_payment ON public.appointments")
    execute("DROP FUNCTION IF EXISTS public.initialize_appointment_payment()")
    execute("DROP TRIGGER IF EXISTS appointments_initialize_final_price ON public.appointments")
    execute("DROP FUNCTION IF EXISTS public.initialize_appointment_final_price()")
    execute("DROP TABLE IF EXISTS public.payment_actions")
    execute("DROP TABLE IF EXISTS public.appointment_payments")
    execute("ALTER TABLE public.appointments DROP CONSTRAINT appointments_final_price_check")
    execute("ALTER TABLE public.appointments DROP COLUMN final_price_ars")
  end
end
