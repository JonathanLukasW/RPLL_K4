--
-- PostgreSQL database dump
--

\restrict rTvgH2GGhohk2mjPnlhXahepc7DflZtUWV6b2Sv4lXd7rkmegicR9HYqNqHk7qo

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.1 (Ubuntu 18.1-1.pgdg24.04+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: extensions; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA extensions;


--
-- Name: graphql; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql;


--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: pgbouncer; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgbouncer;


--
-- Name: realtime; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA realtime;


--
-- Name: storage; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA storage;


--
-- Name: vault; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA vault;


--
-- Name: pg_graphql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_graphql WITH SCHEMA graphql;


--
-- Name: EXTENSION pg_graphql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_graphql IS 'pg_graphql: GraphQL support';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: supabase_vault; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;


--
-- Name: EXTENSION supabase_vault; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION supabase_vault IS 'Supabase Vault Extension';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: aal_level; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.aal_level AS ENUM (
    'aal1',
    'aal2',
    'aal3'
);


--
-- Name: code_challenge_method; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.code_challenge_method AS ENUM (
    's256',
    'plain'
);


--
-- Name: factor_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_status AS ENUM (
    'unverified',
    'verified'
);


--
-- Name: factor_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.factor_type AS ENUM (
    'totp',
    'webauthn',
    'phone'
);


--
-- Name: oauth_authorization_status; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_authorization_status AS ENUM (
    'pending',
    'approved',
    'denied',
    'expired'
);


--
-- Name: oauth_client_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_client_type AS ENUM (
    'public',
    'confidential'
);


--
-- Name: oauth_registration_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_registration_type AS ENUM (
    'dynamic',
    'manual'
);


--
-- Name: oauth_response_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.oauth_response_type AS ENUM (
    'code'
);


--
-- Name: one_time_token_type; Type: TYPE; Schema: auth; Owner: -
--

CREATE TYPE auth.one_time_token_type AS ENUM (
    'confirmation_token',
    'reauthentication_token',
    'recovery_token',
    'email_change_token_new',
    'email_change_token_current',
    'phone_change_token'
);


--
-- Name: action; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.action AS ENUM (
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'ERROR'
);


--
-- Name: equality_op; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.equality_op AS ENUM (
    'eq',
    'neq',
    'lt',
    'lte',
    'gt',
    'gte',
    'in'
);


--
-- Name: user_defined_filter; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.user_defined_filter AS (
	column_name text,
	op realtime.equality_op,
	value text
);


--
-- Name: wal_column; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_column AS (
	name text,
	type_name text,
	type_oid oid,
	value jsonb,
	is_pkey boolean,
	is_selectable boolean
);


--
-- Name: wal_rls; Type: TYPE; Schema: realtime; Owner: -
--

CREATE TYPE realtime.wal_rls AS (
	wal jsonb,
	is_rls_enabled boolean,
	subscription_ids uuid[],
	errors text[]
);


--
-- Name: buckettype; Type: TYPE; Schema: storage; Owner: -
--

CREATE TYPE storage.buckettype AS ENUM (
    'STANDARD',
    'ANALYTICS',
    'VECTOR'
);


--
-- Name: email(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.email() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.email', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'email')
  )::text
$$;


--
-- Name: FUNCTION email(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.email() IS 'Deprecated. Use auth.jwt() -> ''email'' instead.';


--
-- Name: jwt(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.jwt() RETURNS jsonb
    LANGUAGE sql STABLE
    AS $$
  select 
    coalesce(
        nullif(current_setting('request.jwt.claim', true), ''),
        nullif(current_setting('request.jwt.claims', true), '')
    )::jsonb
$$;


--
-- Name: role(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.role() RETURNS text
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.role', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'role')
  )::text
$$;


--
-- Name: FUNCTION role(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.role() IS 'Deprecated. Use auth.jwt() -> ''role'' instead.';


--
-- Name: uid(); Type: FUNCTION; Schema: auth; Owner: -
--

CREATE FUNCTION auth.uid() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  select 
  coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;


--
-- Name: FUNCTION uid(); Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON FUNCTION auth.uid() IS 'Deprecated. Use auth.jwt() -> ''sub'' instead.';


--
-- Name: grant_pg_cron_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_cron_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_cron'
  )
  THEN
    grant usage on schema cron to postgres with grant option;

    alter default privileges in schema cron grant all on tables to postgres with grant option;
    alter default privileges in schema cron grant all on functions to postgres with grant option;
    alter default privileges in schema cron grant all on sequences to postgres with grant option;

    alter default privileges for user supabase_admin in schema cron grant all
        on sequences to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on tables to postgres with grant option;
    alter default privileges for user supabase_admin in schema cron grant all
        on functions to postgres with grant option;

    grant all privileges on all tables in schema cron to postgres with grant option;
    revoke all on table cron.job from postgres;
    grant select on table cron.job to postgres with grant option;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_cron_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_cron_access() IS 'Grants access to pg_cron';


--
-- Name: grant_pg_graphql_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_graphql_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    func_is_graphql_resolve bool;
BEGIN
    func_is_graphql_resolve = (
        SELECT n.proname = 'resolve'
        FROM pg_event_trigger_ddl_commands() AS ev
        LEFT JOIN pg_catalog.pg_proc AS n
        ON ev.objid = n.oid
    );

    IF func_is_graphql_resolve
    THEN
        -- Update public wrapper to pass all arguments through to the pg_graphql resolve func
        DROP FUNCTION IF EXISTS graphql_public.graphql;
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language sql
        as $$
            select graphql.resolve(
                query := query,
                variables := coalesce(variables, '{}'),
                "operationName" := "operationName",
                extensions := extensions
            );
        $$;

        -- This hook executes when `graphql.resolve` is created. That is not necessarily the last
        -- function in the extension so we need to grant permissions on existing entities AND
        -- update default permissions to any others that are created after `graphql.resolve`
        grant usage on schema graphql to postgres, anon, authenticated, service_role;
        grant select on all tables in schema graphql to postgres, anon, authenticated, service_role;
        grant execute on all functions in schema graphql to postgres, anon, authenticated, service_role;
        grant all on all sequences in schema graphql to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on tables to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on functions to postgres, anon, authenticated, service_role;
        alter default privileges in schema graphql grant all on sequences to postgres, anon, authenticated, service_role;

        -- Allow postgres role to allow granting usage on graphql and graphql_public schemas to custom roles
        grant usage on schema graphql_public to postgres with grant option;
        grant usage on schema graphql to postgres with grant option;
    END IF;

END;
$_$;


--
-- Name: FUNCTION grant_pg_graphql_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_graphql_access() IS 'Grants access to pg_graphql';


--
-- Name: grant_pg_net_access(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.grant_pg_net_access() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_event_trigger_ddl_commands() AS ev
    JOIN pg_extension AS ext
    ON ev.objid = ext.oid
    WHERE ext.extname = 'pg_net'
  )
  THEN
    IF NOT EXISTS (
      SELECT 1
      FROM pg_roles
      WHERE rolname = 'supabase_functions_admin'
    )
    THEN
      CREATE USER supabase_functions_admin NOINHERIT CREATEROLE LOGIN NOREPLICATION;
    END IF;

    GRANT USAGE ON SCHEMA net TO supabase_functions_admin, postgres, anon, authenticated, service_role;

    IF EXISTS (
      SELECT FROM pg_extension
      WHERE extname = 'pg_net'
      -- all versions in use on existing projects as of 2025-02-20
      -- version 0.12.0 onwards don't need these applied
      AND extversion IN ('0.2', '0.6', '0.7', '0.7.1', '0.8', '0.10.0', '0.11.0')
    ) THEN
      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SECURITY DEFINER;

      ALTER function net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;
      ALTER function net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) SET search_path = net;

      REVOKE ALL ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;
      REVOKE ALL ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) FROM PUBLIC;

      GRANT EXECUTE ON FUNCTION net.http_get(url text, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
      GRANT EXECUTE ON FUNCTION net.http_post(url text, body jsonb, params jsonb, headers jsonb, timeout_milliseconds integer) TO supabase_functions_admin, postgres, anon, authenticated, service_role;
    END IF;
  END IF;
END;
$$;


--
-- Name: FUNCTION grant_pg_net_access(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.grant_pg_net_access() IS 'Grants access to pg_net';


--
-- Name: pgrst_ddl_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_ddl_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN SELECT * FROM pg_event_trigger_ddl_commands()
  LOOP
    IF cmd.command_tag IN (
      'CREATE SCHEMA', 'ALTER SCHEMA'
    , 'CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO', 'ALTER TABLE'
    , 'CREATE FOREIGN TABLE', 'ALTER FOREIGN TABLE'
    , 'CREATE VIEW', 'ALTER VIEW'
    , 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW'
    , 'CREATE FUNCTION', 'ALTER FUNCTION'
    , 'CREATE TRIGGER'
    , 'CREATE TYPE', 'ALTER TYPE'
    , 'CREATE RULE'
    , 'COMMENT'
    )
    -- don't notify in case of CREATE TEMP table or other objects created on pg_temp
    AND cmd.schema_name is distinct from 'pg_temp'
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: pgrst_drop_watch(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.pgrst_drop_watch() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  obj record;
BEGIN
  FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
  LOOP
    IF obj.object_type IN (
      'schema'
    , 'table'
    , 'foreign table'
    , 'view'
    , 'materialized view'
    , 'function'
    , 'trigger'
    , 'type'
    , 'rule'
    )
    AND obj.is_temporary IS false -- no pg_temp objects
    THEN
      NOTIFY pgrst, 'reload schema';
    END IF;
  END LOOP;
END; $$;


--
-- Name: set_graphql_placeholder(); Type: FUNCTION; Schema: extensions; Owner: -
--

CREATE FUNCTION extensions.set_graphql_placeholder() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $_$
    DECLARE
    graphql_is_dropped bool;
    BEGIN
    graphql_is_dropped = (
        SELECT ev.schema_name = 'graphql_public'
        FROM pg_event_trigger_dropped_objects() AS ev
        WHERE ev.schema_name = 'graphql_public'
    );

    IF graphql_is_dropped
    THEN
        create or replace function graphql_public.graphql(
            "operationName" text default null,
            query text default null,
            variables jsonb default null,
            extensions jsonb default null
        )
            returns jsonb
            language plpgsql
        as $$
            DECLARE
                server_version float;
            BEGIN
                server_version = (SELECT (SPLIT_PART((select version()), ' ', 2))::float);

                IF server_version >= 14 THEN
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql extension is not enabled.'
                            )
                        )
                    );
                ELSE
                    RETURN jsonb_build_object(
                        'errors', jsonb_build_array(
                            jsonb_build_object(
                                'message', 'pg_graphql is only available on projects running Postgres 14 onwards.'
                            )
                        )
                    );
                END IF;
            END;
        $$;
    END IF;

    END;
$_$;


--
-- Name: FUNCTION set_graphql_placeholder(); Type: COMMENT; Schema: extensions; Owner: -
--

COMMENT ON FUNCTION extensions.set_graphql_placeholder() IS 'Reintroduces placeholder function for graphql_public.graphql';


--
-- Name: get_auth(text); Type: FUNCTION; Schema: pgbouncer; Owner: -
--

CREATE FUNCTION pgbouncer.get_auth(p_usename text) RETURNS TABLE(username text, password text)
    LANGUAGE plpgsql SECURITY DEFINER
    AS $_$
begin
    raise debug 'PgBouncer auth request: %', p_usename;

    return query
    select 
        rolname::text, 
        case when rolvaliduntil < now() 
            then null 
            else rolpassword::text 
        end 
    from pg_authid 
    where rolname=$1 and rolcanlogin;
end;
$_$;


--
-- Name: delete_sppg_complete(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_sppg_complete(target_sppg_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  DELETE FROM auth.users
  WHERE id IN (
    SELECT id FROM public.profiles WHERE sppg_id = target_sppg_id
  );

  DELETE FROM public.sppgs WHERE id = target_sppg_id;
END;
$$;


--
-- Name: delete_user_and_profile(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_user_and_profile(user_id_input uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
  -- 1. Hapus dari public.profiles (Safety measure, though the FK constraint should handle this via cascade)
  DELETE FROM public.profiles WHERE id = user_id_input;

  -- 2. Hapus dari auth.users. THIS IS THE CRUCIAL STEP.
  -- This action will automatically delete related records in public.profiles and other linked tables (if CASCADE is set).
  DELETE FROM auth.users WHERE id = user_id_input;
END;
$$;


--
-- Name: apply_rls(jsonb, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.apply_rls(wal jsonb, max_record_bytes integer DEFAULT (1024 * 1024)) RETURNS SETOF realtime.wal_rls
    LANGUAGE plpgsql
    AS $$
declare
-- Regclass of the table e.g. public.notes
entity_ regclass = (quote_ident(wal ->> 'schema') || '.' || quote_ident(wal ->> 'table'))::regclass;

-- I, U, D, T: insert, update ...
action realtime.action = (
    case wal ->> 'action'
        when 'I' then 'INSERT'
        when 'U' then 'UPDATE'
        when 'D' then 'DELETE'
        else 'ERROR'
    end
);

-- Is row level security enabled for the table
is_rls_enabled bool = relrowsecurity from pg_class where oid = entity_;

subscriptions realtime.subscription[] = array_agg(subs)
    from
        realtime.subscription subs
    where
        subs.entity = entity_;

-- Subscription vars
roles regrole[] = array_agg(distinct us.claims_role::text)
    from
        unnest(subscriptions) us;

working_role regrole;
claimed_role regrole;
claims jsonb;

subscription_id uuid;
subscription_has_access bool;
visible_to_subscription_ids uuid[] = '{}';

-- structured info for wal's columns
columns realtime.wal_column[];
-- previous identity values for update/delete
old_columns realtime.wal_column[];

error_record_exceeds_max_size boolean = octet_length(wal::text) > max_record_bytes;

-- Primary jsonb output for record
output jsonb;

begin
perform set_config('role', null, true);

columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'columns') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

old_columns =
    array_agg(
        (
            x->>'name',
            x->>'type',
            x->>'typeoid',
            realtime.cast(
                (x->'value') #>> '{}',
                coalesce(
                    (x->>'typeoid')::regtype, -- null when wal2json version <= 2.4
                    (x->>'type')::regtype
                )
            ),
            (pks ->> 'name') is not null,
            true
        )::realtime.wal_column
    )
    from
        jsonb_array_elements(wal -> 'identity') x
        left join jsonb_array_elements(wal -> 'pk') pks
            on (x ->> 'name') = (pks ->> 'name');

for working_role in select * from unnest(roles) loop

    -- Update `is_selectable` for columns and old_columns
    columns =
        array_agg(
            (
                c.name,
                c.type_name,
                c.type_oid,
                c.value,
                c.is_pkey,
                pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
            )::realtime.wal_column
        )
        from
            unnest(columns) c;

    old_columns =
            array_agg(
                (
                    c.name,
                    c.type_name,
                    c.type_oid,
                    c.value,
                    c.is_pkey,
                    pg_catalog.has_column_privilege(working_role, entity_, c.name, 'SELECT')
                )::realtime.wal_column
            )
            from
                unnest(old_columns) c;

    if action <> 'DELETE' and count(1) = 0 from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            -- subscriptions is already filtered by entity
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 400: Bad Request, no primary key']
        )::realtime.wal_rls;

    -- The claims role does not have SELECT permission to the primary key of entity
    elsif action <> 'DELETE' and sum(c.is_selectable::int) <> count(1) from unnest(columns) c where c.is_pkey then
        return next (
            jsonb_build_object(
                'schema', wal ->> 'schema',
                'table', wal ->> 'table',
                'type', action
            ),
            is_rls_enabled,
            (select array_agg(s.subscription_id) from unnest(subscriptions) as s where claims_role = working_role),
            array['Error 401: Unauthorized']
        )::realtime.wal_rls;

    else
        output = jsonb_build_object(
            'schema', wal ->> 'schema',
            'table', wal ->> 'table',
            'type', action,
            'commit_timestamp', to_char(
                ((wal ->> 'timestamp')::timestamptz at time zone 'utc'),
                'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'
            ),
            'columns', (
                select
                    jsonb_agg(
                        jsonb_build_object(
                            'name', pa.attname,
                            'type', pt.typname
                        )
                        order by pa.attnum asc
                    )
                from
                    pg_attribute pa
                    join pg_type pt
                        on pa.atttypid = pt.oid
                where
                    attrelid = entity_
                    and attnum > 0
                    and pg_catalog.has_column_privilege(working_role, entity_, pa.attname, 'SELECT')
            )
        )
        -- Add "record" key for insert and update
        || case
            when action in ('INSERT', 'UPDATE') then
                jsonb_build_object(
                    'record',
                    (
                        select
                            jsonb_object_agg(
                                -- if unchanged toast, get column name and value from old record
                                coalesce((c).name, (oc).name),
                                case
                                    when (c).name is null then (oc).value
                                    else (c).value
                                end
                            )
                        from
                            unnest(columns) c
                            full outer join unnest(old_columns) oc
                                on (c).name = (oc).name
                        where
                            coalesce((c).is_selectable, (oc).is_selectable)
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                    )
                )
            else '{}'::jsonb
        end
        -- Add "old_record" key for update and delete
        || case
            when action = 'UPDATE' then
                jsonb_build_object(
                        'old_record',
                        (
                            select jsonb_object_agg((c).name, (c).value)
                            from unnest(old_columns) c
                            where
                                (c).is_selectable
                                and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                        )
                    )
            when action = 'DELETE' then
                jsonb_build_object(
                    'old_record',
                    (
                        select jsonb_object_agg((c).name, (c).value)
                        from unnest(old_columns) c
                        where
                            (c).is_selectable
                            and ( not error_record_exceeds_max_size or (octet_length((c).value::text) <= 64))
                            and ( not is_rls_enabled or (c).is_pkey ) -- if RLS enabled, we can't secure deletes so filter to pkey
                    )
                )
            else '{}'::jsonb
        end;

        -- Create the prepared statement
        if is_rls_enabled and action <> 'DELETE' then
            if (select 1 from pg_prepared_statements where name = 'walrus_rls_stmt' limit 1) > 0 then
                deallocate walrus_rls_stmt;
            end if;
            execute realtime.build_prepared_statement_sql('walrus_rls_stmt', entity_, columns);
        end if;

        visible_to_subscription_ids = '{}';

        for subscription_id, claims in (
                select
                    subs.subscription_id,
                    subs.claims
                from
                    unnest(subscriptions) subs
                where
                    subs.entity = entity_
                    and subs.claims_role = working_role
                    and (
                        realtime.is_visible_through_filters(columns, subs.filters)
                        or (
                          action = 'DELETE'
                          and realtime.is_visible_through_filters(old_columns, subs.filters)
                        )
                    )
        ) loop

            if not is_rls_enabled or action = 'DELETE' then
                visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
            else
                -- Check if RLS allows the role to see the record
                perform
                    -- Trim leading and trailing quotes from working_role because set_config
                    -- doesn't recognize the role as valid if they are included
                    set_config('role', trim(both '"' from working_role::text), true),
                    set_config('request.jwt.claims', claims::text, true);

                execute 'execute walrus_rls_stmt' into subscription_has_access;

                if subscription_has_access then
                    visible_to_subscription_ids = visible_to_subscription_ids || subscription_id;
                end if;
            end if;
        end loop;

        perform set_config('role', null, true);

        return next (
            output,
            is_rls_enabled,
            visible_to_subscription_ids,
            case
                when error_record_exceeds_max_size then array['Error 413: Payload Too Large']
                else '{}'
            end
        )::realtime.wal_rls;

    end if;
end loop;

perform set_config('role', null, true);
end;
$$;


--
-- Name: broadcast_changes(text, text, text, text, text, record, record, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.broadcast_changes(topic_name text, event_name text, operation text, table_name text, table_schema text, new record, old record, level text DEFAULT 'ROW'::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    -- Declare a variable to hold the JSONB representation of the row
    row_data jsonb := '{}'::jsonb;
BEGIN
    IF level = 'STATEMENT' THEN
        RAISE EXCEPTION 'function can only be triggered for each row, not for each statement';
    END IF;
    -- Check the operation type and handle accordingly
    IF operation = 'INSERT' OR operation = 'UPDATE' OR operation = 'DELETE' THEN
        row_data := jsonb_build_object('old_record', OLD, 'record', NEW, 'operation', operation, 'table', table_name, 'schema', table_schema);
        PERFORM realtime.send (row_data, event_name, topic_name);
    ELSE
        RAISE EXCEPTION 'Unexpected operation type: %', operation;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Failed to process the row: %', SQLERRM;
END;

$$;


--
-- Name: build_prepared_statement_sql(text, regclass, realtime.wal_column[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.build_prepared_statement_sql(prepared_statement_name text, entity regclass, columns realtime.wal_column[]) RETURNS text
    LANGUAGE sql
    AS $$
      /*
      Builds a sql string that, if executed, creates a prepared statement to
      tests retrive a row from *entity* by its primary key columns.
      Example
          select realtime.build_prepared_statement_sql('public.notes', '{"id"}'::text[], '{"bigint"}'::text[])
      */
          select
      'prepare ' || prepared_statement_name || ' as
          select
              exists(
                  select
                      1
                  from
                      ' || entity || '
                  where
                      ' || string_agg(quote_ident(pkc.name) || '=' || quote_nullable(pkc.value #>> '{}') , ' and ') || '
              )'
          from
              unnest(columns) pkc
          where
              pkc.is_pkey
          group by
              entity
      $$;


--
-- Name: cast(text, regtype); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime."cast"(val text, type_ regtype) RETURNS jsonb
    LANGUAGE plpgsql IMMUTABLE
    AS $$
    declare
      res jsonb;
    begin
      execute format('select to_jsonb(%L::'|| type_::text || ')', val)  into res;
      return res;
    end
    $$;


--
-- Name: check_equality_op(realtime.equality_op, regtype, text, text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.check_equality_op(op realtime.equality_op, type_ regtype, val_1 text, val_2 text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
      /*
      Casts *val_1* and *val_2* as type *type_* and check the *op* condition for truthiness
      */
      declare
          op_symbol text = (
              case
                  when op = 'eq' then '='
                  when op = 'neq' then '!='
                  when op = 'lt' then '<'
                  when op = 'lte' then '<='
                  when op = 'gt' then '>'
                  when op = 'gte' then '>='
                  when op = 'in' then '= any'
                  else 'UNKNOWN OP'
              end
          );
          res boolean;
      begin
          execute format(
              'select %L::'|| type_::text || ' ' || op_symbol
              || ' ( %L::'
              || (
                  case
                      when op = 'in' then type_::text || '[]'
                      else type_::text end
              )
              || ')', val_1, val_2) into res;
          return res;
      end;
      $$;


--
-- Name: is_visible_through_filters(realtime.wal_column[], realtime.user_defined_filter[]); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.is_visible_through_filters(columns realtime.wal_column[], filters realtime.user_defined_filter[]) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
    /*
    Should the record be visible (true) or filtered out (false) after *filters* are applied
    */
        select
            -- Default to allowed when no filters present
            $2 is null -- no filters. this should not happen because subscriptions has a default
            or array_length($2, 1) is null -- array length of an empty array is null
            or bool_and(
                coalesce(
                    realtime.check_equality_op(
                        op:=f.op,
                        type_:=coalesce(
                            col.type_oid::regtype, -- null when wal2json version <= 2.4
                            col.type_name::regtype
                        ),
                        -- cast jsonb to text
                        val_1:=col.value #>> '{}',
                        val_2:=f.value
                    ),
                    false -- if null, filter does not match
                )
            )
        from
            unnest(filters) f
            join unnest(columns) col
                on f.column_name = col.name;
    $_$;


--
-- Name: list_changes(name, name, integer, integer); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.list_changes(publication name, slot_name name, max_changes integer, max_record_bytes integer) RETURNS SETOF realtime.wal_rls
    LANGUAGE sql
    SET log_min_messages TO 'fatal'
    AS $$
      with pub as (
        select
          concat_ws(
            ',',
            case when bool_or(pubinsert) then 'insert' else null end,
            case when bool_or(pubupdate) then 'update' else null end,
            case when bool_or(pubdelete) then 'delete' else null end
          ) as w2j_actions,
          coalesce(
            string_agg(
              realtime.quote_wal2json(format('%I.%I', schemaname, tablename)::regclass),
              ','
            ) filter (where ppt.tablename is not null and ppt.tablename not like '% %'),
            ''
          ) w2j_add_tables
        from
          pg_publication pp
          left join pg_publication_tables ppt
            on pp.pubname = ppt.pubname
        where
          pp.pubname = publication
        group by
          pp.pubname
        limit 1
      ),
      w2j as (
        select
          x.*, pub.w2j_add_tables
        from
          pub,
          pg_logical_slot_get_changes(
            slot_name, null, max_changes,
            'include-pk', 'true',
            'include-transaction', 'false',
            'include-timestamp', 'true',
            'include-type-oids', 'true',
            'format-version', '2',
            'actions', pub.w2j_actions,
            'add-tables', pub.w2j_add_tables
          ) x
      )
      select
        xyz.wal,
        xyz.is_rls_enabled,
        xyz.subscription_ids,
        xyz.errors
      from
        w2j,
        realtime.apply_rls(
          wal := w2j.data::jsonb,
          max_record_bytes := max_record_bytes
        ) xyz(wal, is_rls_enabled, subscription_ids, errors)
      where
        w2j.w2j_add_tables <> ''
        and xyz.subscription_ids[1] is not null
    $$;


--
-- Name: quote_wal2json(regclass); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.quote_wal2json(entity regclass) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
      select
        (
          select string_agg('' || ch,'')
          from unnest(string_to_array(nsp.nspname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
        )
        || '.'
        || (
          select string_agg('' || ch,'')
          from unnest(string_to_array(pc.relname::text, null)) with ordinality x(ch, idx)
          where
            not (x.idx = 1 and x.ch = '"')
            and not (
              x.idx = array_length(string_to_array(nsp.nspname::text, null), 1)
              and x.ch = '"'
            )
          )
      from
        pg_class pc
        join pg_namespace nsp
          on pc.relnamespace = nsp.oid
      where
        pc.oid = entity
    $$;


--
-- Name: send(jsonb, text, text, boolean); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.send(payload jsonb, event text, topic text, private boolean DEFAULT true) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  generated_id uuid;
  final_payload jsonb;
BEGIN
  BEGIN
    -- Generate a new UUID for the id
    generated_id := gen_random_uuid();

    -- Check if payload has an 'id' key, if not, add the generated UUID
    IF payload ? 'id' THEN
      final_payload := payload;
    ELSE
      final_payload := jsonb_set(payload, '{id}', to_jsonb(generated_id));
    END IF;

    -- Set the topic configuration
    EXECUTE format('SET LOCAL realtime.topic TO %L', topic);

    -- Attempt to insert the message
    INSERT INTO realtime.messages (id, payload, event, topic, private, extension)
    VALUES (generated_id, final_payload, event, topic, private, 'broadcast');
  EXCEPTION
    WHEN OTHERS THEN
      -- Capture and notify the error
      RAISE WARNING 'ErrorSendingBroadcastMessage: %', SQLERRM;
  END;
END;
$$;


--
-- Name: subscription_check_filters(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.subscription_check_filters() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    /*
    Validates that the user defined filters for a subscription:
    - refer to valid columns that the claimed role may access
    - values are coercable to the correct column type
    */
    declare
        col_names text[] = coalesce(
                array_agg(c.column_name order by c.ordinal_position),
                '{}'::text[]
            )
            from
                information_schema.columns c
            where
                format('%I.%I', c.table_schema, c.table_name)::regclass = new.entity
                and pg_catalog.has_column_privilege(
                    (new.claims ->> 'role'),
                    format('%I.%I', c.table_schema, c.table_name)::regclass,
                    c.column_name,
                    'SELECT'
                );
        filter realtime.user_defined_filter;
        col_type regtype;

        in_val jsonb;
    begin
        for filter in select * from unnest(new.filters) loop
            -- Filtered column is valid
            if not filter.column_name = any(col_names) then
                raise exception 'invalid column for filter %', filter.column_name;
            end if;

            -- Type is sanitized and safe for string interpolation
            col_type = (
                select atttypid::regtype
                from pg_catalog.pg_attribute
                where attrelid = new.entity
                      and attname = filter.column_name
            );
            if col_type is null then
                raise exception 'failed to lookup type for column %', filter.column_name;
            end if;

            -- Set maximum number of entries for in filter
            if filter.op = 'in'::realtime.equality_op then
                in_val = realtime.cast(filter.value, (col_type::text || '[]')::regtype);
                if coalesce(jsonb_array_length(in_val), 0) > 100 then
                    raise exception 'too many values for `in` filter. Maximum 100';
                end if;
            else
                -- raises an exception if value is not coercable to type
                perform realtime.cast(filter.value, col_type);
            end if;

        end loop;

        -- Apply consistent order to filters so the unique constraint on
        -- (subscription_id, entity, filters) can't be tricked by a different filter order
        new.filters = coalesce(
            array_agg(f order by f.column_name, f.op, f.value),
            '{}'
        ) from unnest(new.filters) f;

        return new;
    end;
    $$;


--
-- Name: to_regrole(text); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.to_regrole(role_name text) RETURNS regrole
    LANGUAGE sql IMMUTABLE
    AS $$ select role_name::regrole $$;


--
-- Name: topic(); Type: FUNCTION; Schema: realtime; Owner: -
--

CREATE FUNCTION realtime.topic() RETURNS text
    LANGUAGE sql STABLE
    AS $$
select nullif(current_setting('realtime.topic', true), '')::text;
$$;


--
-- Name: add_prefixes(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.add_prefixes(_bucket_id text, _name text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    prefixes text[];
BEGIN
    prefixes := "storage"."get_prefixes"("_name");

    IF array_length(prefixes, 1) > 0 THEN
        INSERT INTO storage.prefixes (name, bucket_id)
        SELECT UNNEST(prefixes) as name, "_bucket_id" ON CONFLICT DO NOTHING;
    END IF;
END;
$$;


--
-- Name: can_insert_object(text, text, uuid, jsonb); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.can_insert_object(bucketid text, name text, owner uuid, metadata jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO "storage"."objects" ("bucket_id", "name", "owner", "metadata") VALUES (bucketid, name, owner, metadata);
  -- hack to rollback the successful insert
  RAISE sqlstate 'PT200' using
  message = 'ROLLBACK',
  detail = 'rollback successful insert';
END
$$;


--
-- Name: delete_leaf_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_leaf_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_rows_deleted integer;
BEGIN
    LOOP
        WITH candidates AS (
            SELECT DISTINCT
                t.bucket_id,
                unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        ),
        uniq AS (
             SELECT
                 bucket_id,
                 name,
                 storage.get_level(name) AS level
             FROM candidates
             WHERE name <> ''
             GROUP BY bucket_id, name
        ),
        leaf AS (
             SELECT
                 p.bucket_id,
                 p.name,
                 p.level
             FROM storage.prefixes AS p
                  JOIN uniq AS u
                       ON u.bucket_id = p.bucket_id
                           AND u.name = p.name
                           AND u.level = p.level
             WHERE NOT EXISTS (
                 SELECT 1
                 FROM storage.objects AS o
                 WHERE o.bucket_id = p.bucket_id
                   AND o.level = p.level + 1
                   AND o.name COLLATE "C" LIKE p.name || '/%'
             )
             AND NOT EXISTS (
                 SELECT 1
                 FROM storage.prefixes AS c
                 WHERE c.bucket_id = p.bucket_id
                   AND c.level = p.level + 1
                   AND c.name COLLATE "C" LIKE p.name || '/%'
             )
        )
        DELETE
        FROM storage.prefixes AS p
            USING leaf AS l
        WHERE p.bucket_id = l.bucket_id
          AND p.name = l.name
          AND p.level = l.level;

        GET DIAGNOSTICS v_rows_deleted = ROW_COUNT;
        EXIT WHEN v_rows_deleted = 0;
    END LOOP;
END;
$$;


--
-- Name: delete_prefix(text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix(_bucket_id text, _name text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
BEGIN
    -- Check if we can delete the prefix
    IF EXISTS(
        SELECT FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name") + 1
          AND "prefixes"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    )
    OR EXISTS(
        SELECT FROM "storage"."objects"
        WHERE "objects"."bucket_id" = "_bucket_id"
          AND "storage"."get_level"("objects"."name") = "storage"."get_level"("_name") + 1
          AND "objects"."name" COLLATE "C" LIKE "_name" || '/%'
        LIMIT 1
    ) THEN
    -- There are sub-objects, skip deletion
    RETURN false;
    ELSE
        DELETE FROM "storage"."prefixes"
        WHERE "prefixes"."bucket_id" = "_bucket_id"
          AND level = "storage"."get_level"("_name")
          AND "prefixes"."name" = "_name";
        RETURN true;
    END IF;
END;
$$;


--
-- Name: delete_prefix_hierarchy_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.delete_prefix_hierarchy_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    prefix text;
BEGIN
    prefix := "storage"."get_prefix"(OLD."name");

    IF coalesce(prefix, '') != '' THEN
        PERFORM "storage"."delete_prefix"(OLD."bucket_id", prefix);
    END IF;

    RETURN OLD;
END;
$$;


--
-- Name: enforce_bucket_name_length(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.enforce_bucket_name_length() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    if length(new.name) > 100 then
        raise exception 'bucket name "%" is too long (% characters). Max is 100.', new.name, length(new.name);
    end if;
    return new;
end;
$$;


--
-- Name: extension(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.extension(name text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
    _filename text;
BEGIN
    SELECT string_to_array(name, '/') INTO _parts;
    SELECT _parts[array_length(_parts,1)] INTO _filename;
    RETURN reverse(split_part(reverse(_filename), '.', 1));
END
$$;


--
-- Name: filename(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.filename(name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
_parts text[];
BEGIN
	select string_to_array(name, '/') into _parts;
	return _parts[array_length(_parts,1)];
END
$$;


--
-- Name: foldername(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.foldername(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
    _parts text[];
BEGIN
    -- Split on "/" to get path segments
    SELECT string_to_array(name, '/') INTO _parts;
    -- Return everything except the last segment
    RETURN _parts[1 : array_length(_parts,1) - 1];
END
$$;


--
-- Name: get_level(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_level(name text) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
SELECT array_length(string_to_array("name", '/'), 1);
$$;


--
-- Name: get_prefix(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefix(name text) RETURNS text
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$
SELECT
    CASE WHEN strpos("name", '/') > 0 THEN
             regexp_replace("name", '[\/]{1}[^\/]+\/?$', '')
         ELSE
             ''
        END;
$_$;


--
-- Name: get_prefixes(text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_prefixes(name text) RETURNS text[]
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
DECLARE
    parts text[];
    prefixes text[];
    prefix text;
BEGIN
    -- Split the name into parts by '/'
    parts := string_to_array("name", '/');
    prefixes := '{}';

    -- Construct the prefixes, stopping one level below the last part
    FOR i IN 1..array_length(parts, 1) - 1 LOOP
            prefix := array_to_string(parts[1:i], '/');
            prefixes := array_append(prefixes, prefix);
    END LOOP;

    RETURN prefixes;
END;
$$;


--
-- Name: get_size_by_bucket(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.get_size_by_bucket() RETURNS TABLE(size bigint, bucket_id text)
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    return query
        select sum((metadata->>'size')::bigint) as size, obj.bucket_id
        from "storage".objects as obj
        group by obj.bucket_id;
END
$$;


--
-- Name: list_multipart_uploads_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_multipart_uploads_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, next_key_token text DEFAULT ''::text, next_upload_token text DEFAULT ''::text) RETURNS TABLE(key text, id text, created_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(key COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                        substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1)))
                    ELSE
                        key
                END AS key, id, created_at
            FROM
                storage.s3_multipart_uploads
            WHERE
                bucket_id = $5 AND
                key ILIKE $1 || ''%'' AND
                CASE
                    WHEN $4 != '''' AND $6 = '''' THEN
                        CASE
                            WHEN position($2 IN substring(key from length($1) + 1)) > 0 THEN
                                substring(key from 1 for length($1) + position($2 IN substring(key from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                key COLLATE "C" > $4
                            END
                    ELSE
                        true
                END AND
                CASE
                    WHEN $6 != '''' THEN
                        id COLLATE "C" > $6
                    ELSE
                        true
                    END
            ORDER BY
                key COLLATE "C" ASC, created_at ASC) as e order by key COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_key_token, bucket_id, next_upload_token;
END;
$_$;


--
-- Name: list_objects_with_delimiter(text, text, text, integer, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.list_objects_with_delimiter(bucket_id text, prefix_param text, delimiter_param text, max_keys integer DEFAULT 100, start_after text DEFAULT ''::text, next_token text DEFAULT ''::text) RETURNS TABLE(name text, id uuid, metadata jsonb, updated_at timestamp with time zone)
    LANGUAGE plpgsql
    AS $_$
BEGIN
    RETURN QUERY EXECUTE
        'SELECT DISTINCT ON(name COLLATE "C") * from (
            SELECT
                CASE
                    WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                        substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1)))
                    ELSE
                        name
                END AS name, id, metadata, updated_at
            FROM
                storage.objects
            WHERE
                bucket_id = $5 AND
                name ILIKE $1 || ''%'' AND
                CASE
                    WHEN $6 != '''' THEN
                    name COLLATE "C" > $6
                ELSE true END
                AND CASE
                    WHEN $4 != '''' THEN
                        CASE
                            WHEN position($2 IN substring(name from length($1) + 1)) > 0 THEN
                                substring(name from 1 for length($1) + position($2 IN substring(name from length($1) + 1))) COLLATE "C" > $4
                            ELSE
                                name COLLATE "C" > $4
                            END
                    ELSE
                        true
                END
            ORDER BY
                name COLLATE "C" ASC) as e order by name COLLATE "C" LIMIT $3'
        USING prefix_param, delimiter_param, max_keys, next_token, bucket_id, start_after;
END;
$_$;


--
-- Name: lock_top_prefixes(text[], text[]); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.lock_top_prefixes(bucket_ids text[], names text[]) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket text;
    v_top text;
BEGIN
    FOR v_bucket, v_top IN
        SELECT DISTINCT t.bucket_id,
            split_part(t.name, '/', 1) AS top
        FROM unnest(bucket_ids, names) AS t(bucket_id, name)
        WHERE t.name <> ''
        ORDER BY 1, 2
        LOOP
            PERFORM pg_advisory_xact_lock(hashtextextended(v_bucket || '/' || v_top, 0));
        END LOOP;
END;
$$;


--
-- Name: objects_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: objects_insert_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_insert_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    NEW.level := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: objects_update_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    -- NEW - OLD (destinations to create prefixes for)
    v_add_bucket_ids text[];
    v_add_names      text[];

    -- OLD - NEW (sources to prune)
    v_src_bucket_ids text[];
    v_src_names      text[];
BEGIN
    IF TG_OP <> 'UPDATE' THEN
        RETURN NULL;
    END IF;

    -- 1) Compute NEW−OLD (added paths) and OLD−NEW (moved-away paths)
    WITH added AS (
        SELECT n.bucket_id, n.name
        FROM new_rows n
        WHERE n.name <> '' AND position('/' in n.name) > 0
        EXCEPT
        SELECT o.bucket_id, o.name FROM old_rows o WHERE o.name <> ''
    ),
    moved AS (
         SELECT o.bucket_id, o.name
         FROM old_rows o
         WHERE o.name <> ''
         EXCEPT
         SELECT n.bucket_id, n.name FROM new_rows n WHERE n.name <> ''
    )
    SELECT
        -- arrays for ADDED (dest) in stable order
        COALESCE( (SELECT array_agg(a.bucket_id ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        COALESCE( (SELECT array_agg(a.name      ORDER BY a.bucket_id, a.name) FROM added a), '{}' ),
        -- arrays for MOVED (src) in stable order
        COALESCE( (SELECT array_agg(m.bucket_id ORDER BY m.bucket_id, m.name) FROM moved m), '{}' ),
        COALESCE( (SELECT array_agg(m.name      ORDER BY m.bucket_id, m.name) FROM moved m), '{}' )
    INTO v_add_bucket_ids, v_add_names, v_src_bucket_ids, v_src_names;

    -- Nothing to do?
    IF (array_length(v_add_bucket_ids, 1) IS NULL) AND (array_length(v_src_bucket_ids, 1) IS NULL) THEN
        RETURN NULL;
    END IF;

    -- 2) Take per-(bucket, top) locks: ALL prefixes in consistent global order to prevent deadlocks
    DECLARE
        v_all_bucket_ids text[];
        v_all_names text[];
    BEGIN
        -- Combine source and destination arrays for consistent lock ordering
        v_all_bucket_ids := COALESCE(v_src_bucket_ids, '{}') || COALESCE(v_add_bucket_ids, '{}');
        v_all_names := COALESCE(v_src_names, '{}') || COALESCE(v_add_names, '{}');

        -- Single lock call ensures consistent global ordering across all transactions
        IF array_length(v_all_bucket_ids, 1) IS NOT NULL THEN
            PERFORM storage.lock_top_prefixes(v_all_bucket_ids, v_all_names);
        END IF;
    END;

    -- 3) Create destination prefixes (NEW−OLD) BEFORE pruning sources
    IF array_length(v_add_bucket_ids, 1) IS NOT NULL THEN
        WITH candidates AS (
            SELECT DISTINCT t.bucket_id, unnest(storage.get_prefixes(t.name)) AS name
            FROM unnest(v_add_bucket_ids, v_add_names) AS t(bucket_id, name)
            WHERE name <> ''
        )
        INSERT INTO storage.prefixes (bucket_id, name)
        SELECT c.bucket_id, c.name
        FROM candidates c
        ON CONFLICT DO NOTHING;
    END IF;

    -- 4) Prune source prefixes bottom-up for OLD−NEW
    IF array_length(v_src_bucket_ids, 1) IS NOT NULL THEN
        -- re-entrancy guard so DELETE on prefixes won't recurse
        IF current_setting('storage.gc.prefixes', true) <> '1' THEN
            PERFORM set_config('storage.gc.prefixes', '1', true);
        END IF;

        PERFORM storage.delete_leaf_prefixes(v_src_bucket_ids, v_src_names);
    END IF;

    RETURN NULL;
END;
$$;


--
-- Name: objects_update_level_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_level_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Set the new level
        NEW."level" := "storage"."get_level"(NEW."name");
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: objects_update_prefix_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.objects_update_prefix_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    old_prefixes TEXT[];
BEGIN
    -- Ensure this is an update operation and the name has changed
    IF TG_OP = 'UPDATE' AND (NEW."name" <> OLD."name" OR NEW."bucket_id" <> OLD."bucket_id") THEN
        -- Retrieve old prefixes
        old_prefixes := "storage"."get_prefixes"(OLD."name");

        -- Remove old prefixes that are only used by this object
        WITH all_prefixes as (
            SELECT unnest(old_prefixes) as prefix
        ),
        can_delete_prefixes as (
             SELECT prefix
             FROM all_prefixes
             WHERE NOT EXISTS (
                 SELECT 1 FROM "storage"."objects"
                 WHERE "bucket_id" = OLD."bucket_id"
                   AND "name" <> OLD."name"
                   AND "name" LIKE (prefix || '%')
             )
         )
        DELETE FROM "storage"."prefixes" WHERE name IN (SELECT prefix FROM can_delete_prefixes);

        -- Add new prefixes
        PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    END IF;
    -- Set the new level
    NEW."level" := "storage"."get_level"(NEW."name");

    RETURN NEW;
END;
$$;


--
-- Name: operation(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.operation() RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
    RETURN current_setting('storage.operation', true);
END;
$$;


--
-- Name: prefixes_delete_cleanup(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_delete_cleanup() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_bucket_ids text[];
    v_names      text[];
BEGIN
    IF current_setting('storage.gc.prefixes', true) = '1' THEN
        RETURN NULL;
    END IF;

    PERFORM set_config('storage.gc.prefixes', '1', true);

    SELECT COALESCE(array_agg(d.bucket_id), '{}'),
           COALESCE(array_agg(d.name), '{}')
    INTO v_bucket_ids, v_names
    FROM deleted AS d
    WHERE d.name <> '';

    PERFORM storage.lock_top_prefixes(v_bucket_ids, v_names);
    PERFORM storage.delete_leaf_prefixes(v_bucket_ids, v_names);

    RETURN NULL;
END;
$$;


--
-- Name: prefixes_insert_trigger(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.prefixes_insert_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM "storage"."add_prefixes"(NEW."bucket_id", NEW."name");
    RETURN NEW;
END;
$$;


--
-- Name: search(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql
    AS $$
declare
    can_bypass_rls BOOLEAN;
begin
    SELECT rolbypassrls
    INTO can_bypass_rls
    FROM pg_roles
    WHERE rolname = coalesce(nullif(current_setting('role', true), 'none'), current_user);

    IF can_bypass_rls THEN
        RETURN QUERY SELECT * FROM storage.search_v1_optimised(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    ELSE
        RETURN QUERY SELECT * FROM storage.search_legacy_v1(prefix, bucketname, limits, levels, offsets, search, sortcolumn, sortorder);
    END IF;
end;
$$;


--
-- Name: search_legacy_v1(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_legacy_v1(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select path_tokens[$1] as folder
           from storage.objects
             where objects.name ilike $2 || $3 || ''%''
               and bucket_id = $4
               and array_length(objects.path_tokens, 1) <> $1
           group by folder
           order by folder ' || v_sort_order || '
     )
     (select folder as "name",
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[$1] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where objects.name ilike $2 || $3 || ''%''
       and bucket_id = $4
       and array_length(objects.path_tokens, 1) = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v1_optimised(text, text, integer, integer, integer, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v1_optimised(prefix text, bucketname text, limits integer DEFAULT 100, levels integer DEFAULT 1, offsets integer DEFAULT 0, search text DEFAULT ''::text, sortcolumn text DEFAULT 'name'::text, sortorder text DEFAULT 'asc'::text) RETURNS TABLE(name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
declare
    v_order_by text;
    v_sort_order text;
begin
    case
        when sortcolumn = 'name' then
            v_order_by = 'name';
        when sortcolumn = 'updated_at' then
            v_order_by = 'updated_at';
        when sortcolumn = 'created_at' then
            v_order_by = 'created_at';
        when sortcolumn = 'last_accessed_at' then
            v_order_by = 'last_accessed_at';
        else
            v_order_by = 'name';
        end case;

    case
        when sortorder = 'asc' then
            v_sort_order = 'asc';
        when sortorder = 'desc' then
            v_sort_order = 'desc';
        else
            v_sort_order = 'asc';
        end case;

    v_order_by = v_order_by || ' ' || v_sort_order;

    return query execute
        'with folders as (
           select (string_to_array(name, ''/''))[level] as name
           from storage.prefixes
             where lower(prefixes.name) like lower($2 || $3) || ''%''
               and bucket_id = $4
               and level = $1
           order by name ' || v_sort_order || '
     )
     (select name,
            null as id,
            null as updated_at,
            null as created_at,
            null as last_accessed_at,
            null as metadata from folders)
     union all
     (select path_tokens[level] as "name",
            id,
            updated_at,
            created_at,
            last_accessed_at,
            metadata
     from storage.objects
     where lower(objects.name) like lower($2 || $3) || ''%''
       and bucket_id = $4
       and level = $1
     order by ' || v_order_by || ')
     limit $5
     offset $6' using levels, prefix, search, bucketname, limits, offsets;
end;
$_$;


--
-- Name: search_v2(text, text, integer, integer, text, text, text, text); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.search_v2(prefix text, bucket_name text, limits integer DEFAULT 100, levels integer DEFAULT 1, start_after text DEFAULT ''::text, sort_order text DEFAULT 'asc'::text, sort_column text DEFAULT 'name'::text, sort_column_after text DEFAULT ''::text) RETURNS TABLE(key text, name text, id uuid, updated_at timestamp with time zone, created_at timestamp with time zone, last_accessed_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE
    AS $_$
DECLARE
    sort_col text;
    sort_ord text;
    cursor_op text;
    cursor_expr text;
    sort_expr text;
BEGIN
    -- Validate sort_order
    sort_ord := lower(sort_order);
    IF sort_ord NOT IN ('asc', 'desc') THEN
        sort_ord := 'asc';
    END IF;

    -- Determine cursor comparison operator
    IF sort_ord = 'asc' THEN
        cursor_op := '>';
    ELSE
        cursor_op := '<';
    END IF;
    
    sort_col := lower(sort_column);
    -- Validate sort column  
    IF sort_col IN ('updated_at', 'created_at') THEN
        cursor_expr := format(
            '($5 = '''' OR ROW(date_trunc(''milliseconds'', %I), name COLLATE "C") %s ROW(COALESCE(NULLIF($6, '''')::timestamptz, ''epoch''::timestamptz), $5))',
            sort_col, cursor_op
        );
        sort_expr := format(
            'COALESCE(date_trunc(''milliseconds'', %I), ''epoch''::timestamptz) %s, name COLLATE "C" %s',
            sort_col, sort_ord, sort_ord
        );
    ELSE
        cursor_expr := format('($5 = '''' OR name COLLATE "C" %s $5)', cursor_op);
        sort_expr := format('name COLLATE "C" %s', sort_ord);
    END IF;

    RETURN QUERY EXECUTE format(
        $sql$
        SELECT * FROM (
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    NULL::uuid AS id,
                    updated_at,
                    created_at,
                    NULL::timestamptz AS last_accessed_at,
                    NULL::jsonb AS metadata
                FROM storage.prefixes
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
            UNION ALL
            (
                SELECT
                    split_part(name, '/', $4) AS key,
                    name,
                    id,
                    updated_at,
                    created_at,
                    last_accessed_at,
                    metadata
                FROM storage.objects
                WHERE name COLLATE "C" LIKE $1 || '%%'
                    AND bucket_id = $2
                    AND level = $4
                    AND %s
                ORDER BY %s
                LIMIT $3
            )
        ) obj
        ORDER BY %s
        LIMIT $3
        $sql$,
        cursor_expr,    -- prefixes WHERE
        sort_expr,      -- prefixes ORDER BY
        cursor_expr,    -- objects WHERE
        sort_expr,      -- objects ORDER BY
        sort_expr       -- final ORDER BY
    )
    USING prefix, bucket_name, limits, levels, start_after, sort_column_after;
END;
$_$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: storage; Owner: -
--

CREATE FUNCTION storage.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW; 
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log_entries; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.audit_log_entries (
    instance_id uuid,
    id uuid NOT NULL,
    payload json,
    created_at timestamp with time zone,
    ip_address character varying(64) DEFAULT ''::character varying NOT NULL
);


--
-- Name: TABLE audit_log_entries; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.audit_log_entries IS 'Auth: Audit trail for user actions.';


--
-- Name: flow_state; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.flow_state (
    id uuid NOT NULL,
    user_id uuid,
    auth_code text NOT NULL,
    code_challenge_method auth.code_challenge_method NOT NULL,
    code_challenge text NOT NULL,
    provider_type text NOT NULL,
    provider_access_token text,
    provider_refresh_token text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    authentication_method text NOT NULL,
    auth_code_issued_at timestamp with time zone
);


--
-- Name: TABLE flow_state; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.flow_state IS 'stores metadata for pkce logins';


--
-- Name: identities; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.identities (
    provider_id text NOT NULL,
    user_id uuid NOT NULL,
    identity_data jsonb NOT NULL,
    provider text NOT NULL,
    last_sign_in_at timestamp with time zone,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    email text GENERATED ALWAYS AS (lower((identity_data ->> 'email'::text))) STORED,
    id uuid DEFAULT gen_random_uuid() NOT NULL
);


--
-- Name: TABLE identities; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.identities IS 'Auth: Stores identities associated to a user.';


--
-- Name: COLUMN identities.email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.identities.email IS 'Auth: Email is a generated column that references the optional email property in the identity_data';


--
-- Name: instances; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.instances (
    id uuid NOT NULL,
    uuid uuid,
    raw_base_config text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
);


--
-- Name: TABLE instances; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.instances IS 'Auth: Manages users across multiple sites.';


--
-- Name: mfa_amr_claims; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_amr_claims (
    session_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    authentication_method text NOT NULL,
    id uuid NOT NULL
);


--
-- Name: TABLE mfa_amr_claims; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_amr_claims IS 'auth: stores authenticator method reference claims for multi factor authentication';


--
-- Name: mfa_challenges; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_challenges (
    id uuid NOT NULL,
    factor_id uuid NOT NULL,
    created_at timestamp with time zone NOT NULL,
    verified_at timestamp with time zone,
    ip_address inet NOT NULL,
    otp_code text,
    web_authn_session_data jsonb
);


--
-- Name: TABLE mfa_challenges; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_challenges IS 'auth: stores metadata about challenge requests made';


--
-- Name: mfa_factors; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa_factors (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    friendly_name text,
    factor_type auth.factor_type NOT NULL,
    status auth.factor_status NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    secret text,
    phone text,
    last_challenged_at timestamp with time zone,
    web_authn_credential jsonb,
    web_authn_aaguid uuid,
    last_webauthn_challenge_data jsonb
);


--
-- Name: TABLE mfa_factors; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa_factors IS 'auth: stores metadata about factors';


--
-- Name: COLUMN mfa_factors.last_webauthn_challenge_data; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa_factors.last_webauthn_challenge_data IS 'Stores the latest WebAuthn challenge data including attestation/assertion for customer verification';


--
-- Name: oauth_authorizations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_authorizations (
    id uuid NOT NULL,
    authorization_id text NOT NULL,
    client_id uuid NOT NULL,
    user_id uuid,
    redirect_uri text NOT NULL,
    scope text NOT NULL,
    state text,
    resource text,
    code_challenge text,
    code_challenge_method auth.code_challenge_method,
    response_type auth.oauth_response_type DEFAULT 'code'::auth.oauth_response_type NOT NULL,
    status auth.oauth_authorization_status DEFAULT 'pending'::auth.oauth_authorization_status NOT NULL,
    authorization_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '00:03:00'::interval) NOT NULL,
    approved_at timestamp with time zone,
    nonce text,
    CONSTRAINT oauth_authorizations_authorization_code_length CHECK ((char_length(authorization_code) <= 255)),
    CONSTRAINT oauth_authorizations_code_challenge_length CHECK ((char_length(code_challenge) <= 128)),
    CONSTRAINT oauth_authorizations_expires_at_future CHECK ((expires_at > created_at)),
    CONSTRAINT oauth_authorizations_nonce_length CHECK ((char_length(nonce) <= 255)),
    CONSTRAINT oauth_authorizations_redirect_uri_length CHECK ((char_length(redirect_uri) <= 2048)),
    CONSTRAINT oauth_authorizations_resource_length CHECK ((char_length(resource) <= 2048)),
    CONSTRAINT oauth_authorizations_scope_length CHECK ((char_length(scope) <= 4096)),
    CONSTRAINT oauth_authorizations_state_length CHECK ((char_length(state) <= 4096))
);


--
-- Name: oauth_clients; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_clients (
    id uuid NOT NULL,
    client_secret_hash text,
    registration_type auth.oauth_registration_type NOT NULL,
    redirect_uris text NOT NULL,
    grant_types text NOT NULL,
    client_name text,
    client_uri text,
    logo_uri text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    client_type auth.oauth_client_type DEFAULT 'confidential'::auth.oauth_client_type NOT NULL,
    CONSTRAINT oauth_clients_client_name_length CHECK ((char_length(client_name) <= 1024)),
    CONSTRAINT oauth_clients_client_uri_length CHECK ((char_length(client_uri) <= 2048)),
    CONSTRAINT oauth_clients_logo_uri_length CHECK ((char_length(logo_uri) <= 2048))
);


--
-- Name: oauth_consents; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.oauth_consents (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    client_id uuid NOT NULL,
    scopes text NOT NULL,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    CONSTRAINT oauth_consents_revoked_after_granted CHECK (((revoked_at IS NULL) OR (revoked_at >= granted_at))),
    CONSTRAINT oauth_consents_scopes_length CHECK ((char_length(scopes) <= 2048)),
    CONSTRAINT oauth_consents_scopes_not_empty CHECK ((char_length(TRIM(BOTH FROM scopes)) > 0))
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.one_time_tokens (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_type auth.one_time_token_type NOT NULL,
    token_hash text NOT NULL,
    relates_to text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT one_time_tokens_token_hash_check CHECK ((char_length(token_hash) > 0))
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.refresh_tokens (
    instance_id uuid,
    id bigint NOT NULL,
    token character varying(255),
    user_id character varying(255),
    revoked boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    parent character varying(255),
    session_id uuid
);


--
-- Name: TABLE refresh_tokens; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.refresh_tokens IS 'Auth: Store of tokens used to refresh JWT tokens once they expire.';


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE; Schema: auth; Owner: -
--

CREATE SEQUENCE auth.refresh_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: auth; Owner: -
--

ALTER SEQUENCE auth.refresh_tokens_id_seq OWNED BY auth.refresh_tokens.id;


--
-- Name: saml_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_providers (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    entity_id text NOT NULL,
    metadata_xml text NOT NULL,
    metadata_url text,
    attribute_mapping jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    name_id_format text,
    CONSTRAINT "entity_id not empty" CHECK ((char_length(entity_id) > 0)),
    CONSTRAINT "metadata_url not empty" CHECK (((metadata_url = NULL::text) OR (char_length(metadata_url) > 0))),
    CONSTRAINT "metadata_xml not empty" CHECK ((char_length(metadata_xml) > 0))
);


--
-- Name: TABLE saml_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_providers IS 'Auth: Manages SAML Identity Provider connections.';


--
-- Name: saml_relay_states; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.saml_relay_states (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    request_id text NOT NULL,
    for_email text,
    redirect_to text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    flow_state_id uuid,
    CONSTRAINT "request_id not empty" CHECK ((char_length(request_id) > 0))
);


--
-- Name: TABLE saml_relay_states; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.saml_relay_states IS 'Auth: Contains SAML Relay State information for each Service Provider initiated login.';


--
-- Name: schema_migrations; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.schema_migrations (
    version character varying(255) NOT NULL
);


--
-- Name: TABLE schema_migrations; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.schema_migrations IS 'Auth: Manages updates to the auth system.';


--
-- Name: sessions; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sessions (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    factor_id uuid,
    aal auth.aal_level,
    not_after timestamp with time zone,
    refreshed_at timestamp without time zone,
    user_agent text,
    ip inet,
    tag text,
    oauth_client_id uuid,
    refresh_token_hmac_key text,
    refresh_token_counter bigint,
    scopes text,
    CONSTRAINT sessions_scopes_length CHECK ((char_length(scopes) <= 4096))
);


--
-- Name: TABLE sessions; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sessions IS 'Auth: Stores session data associated to a user.';


--
-- Name: COLUMN sessions.not_after; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.not_after IS 'Auth: Not after is a nullable column that contains a timestamp after which the session should be regarded as expired.';


--
-- Name: COLUMN sessions.refresh_token_hmac_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_hmac_key IS 'Holds a HMAC-SHA256 key used to sign refresh tokens for this session.';


--
-- Name: COLUMN sessions.refresh_token_counter; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sessions.refresh_token_counter IS 'Holds the ID (counter) of the last issued refresh token.';


--
-- Name: sso_domains; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_domains (
    id uuid NOT NULL,
    sso_provider_id uuid NOT NULL,
    domain text NOT NULL,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    CONSTRAINT "domain not empty" CHECK ((char_length(domain) > 0))
);


--
-- Name: TABLE sso_domains; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_domains IS 'Auth: Manages SSO email address domain mapping to an SSO Identity Provider.';


--
-- Name: sso_providers; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.sso_providers (
    id uuid NOT NULL,
    resource_id text,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    disabled boolean,
    CONSTRAINT "resource_id not empty" CHECK (((resource_id = NULL::text) OR (char_length(resource_id) > 0)))
);


--
-- Name: TABLE sso_providers; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.sso_providers IS 'Auth: Manages SSO identity provider information; see saml_providers for SAML.';


--
-- Name: COLUMN sso_providers.resource_id; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.sso_providers.resource_id IS 'Auth: Uniquely identifies a SSO provider according to a user-chosen resource ID (case insensitive), useful in infrastructure as code.';


--
-- Name: users; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.users (
    instance_id uuid,
    id uuid NOT NULL,
    aud character varying(255),
    role character varying(255),
    email character varying(255),
    encrypted_password character varying(255),
    email_confirmed_at timestamp with time zone,
    invited_at timestamp with time zone,
    confirmation_token character varying(255),
    confirmation_sent_at timestamp with time zone,
    recovery_token character varying(255),
    recovery_sent_at timestamp with time zone,
    email_change_token_new character varying(255),
    email_change character varying(255),
    email_change_sent_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    raw_app_meta_data jsonb,
    raw_user_meta_data jsonb,
    is_super_admin boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    phone text DEFAULT NULL::character varying,
    phone_confirmed_at timestamp with time zone,
    phone_change text DEFAULT ''::character varying,
    phone_change_token character varying(255) DEFAULT ''::character varying,
    phone_change_sent_at timestamp with time zone,
    confirmed_at timestamp with time zone GENERATED ALWAYS AS (LEAST(email_confirmed_at, phone_confirmed_at)) STORED,
    email_change_token_current character varying(255) DEFAULT ''::character varying,
    email_change_confirm_status smallint DEFAULT 0,
    banned_until timestamp with time zone,
    reauthentication_token character varying(255) DEFAULT ''::character varying,
    reauthentication_sent_at timestamp with time zone,
    is_sso_user boolean DEFAULT false NOT NULL,
    deleted_at timestamp with time zone,
    is_anonymous boolean DEFAULT false NOT NULL,
    CONSTRAINT users_email_change_confirm_status_check CHECK (((email_change_confirm_status >= 0) AND (email_change_confirm_status <= 2)))
);


--
-- Name: TABLE users; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.users IS 'Auth: Stores user login data within a secure schema.';


--
-- Name: COLUMN users.is_sso_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.users.is_sso_user IS 'Auth: Set this column to true when the account comes from SSO. These accounts can have duplicate emails.';


--
-- Name: change_request_details; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.change_request_details (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    request_id uuid NOT NULL,
    menu_id uuid NOT NULL,
    new_quantity integer,
    new_schedule_time time without time zone,
    new_schedule_date date,
    old_quantity integer
);


--
-- Name: change_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.change_requests (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    sppg_id uuid,
    school_id uuid,
    requester_id uuid,
    request_type text,
    old_notes text,
    status text DEFAULT 'pending'::text,
    admin_response text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone
);


--
-- Name: class_receptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.class_receptions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    stop_id uuid,
    teacher_id uuid,
    class_name text,
    qty_received integer DEFAULT 0,
    notes text,
    created_at timestamp with time zone DEFAULT now(),
    issue_type text,
    proof_photo_url text,
    admin_response text,
    resolved_at timestamp with time zone
);


--
-- Name: delivery_routes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_routes (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    date date DEFAULT CURRENT_DATE,
    sppg_id uuid,
    vehicle_id uuid,
    courier_id uuid,
    status text DEFAULT 'pending'::text,
    start_time timestamp with time zone,
    end_time timestamp with time zone,
    load_proof_photo_url text,
    menu_id uuid,
    departure_time time without time zone,
    CONSTRAINT delivery_routes_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'completed'::text])))
);


--
-- Name: delivery_stops; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.delivery_stops (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    route_id uuid,
    school_id uuid,
    sequence_order integer,
    status text DEFAULT 'pending'::text,
    arrival_time timestamp with time zone,
    completion_time timestamp with time zone,
    received_qty integer DEFAULT 0,
    reception_notes text,
    proof_photo_url text,
    recipient_name text,
    admin_response text,
    resolved_at timestamp with time zone,
    courier_proof_photo_url text,
    estimated_arrival_time time without time zone,
    CONSTRAINT delivery_stops_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'arrived'::text, 'completed'::text, 'received'::text, 'issue_reported'::text])))
);


--
-- Name: menus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menus (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    sppg_id uuid,
    name text NOT NULL,
    category text,
    cooking_duration_minutes integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    type text,
    is_read boolean DEFAULT false,
    related_id uuid,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: production_schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.production_schedules (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    sppg_id uuid,
    date date NOT NULL,
    menu_id uuid,
    total_portions integer DEFAULT 0,
    start_cooking_time time without time zone,
    target_finish_time time without time zone,
    notes text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    full_name text,
    role text,
    sppg_id uuid,
    school_id uuid,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    email text,
    class_name text,
    dob date,
    address text,
    "position" text,
    CONSTRAINT profiles_role_check CHECK ((role = ANY (ARRAY['bgn'::text, 'admin_sppg'::text, 'kurir'::text, 'koordinator'::text, 'walikelas'::text])))
);


--
-- Name: qc_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.qc_reports (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    school_id uuid,
    reporter_id uuid,
    report_type text,
    description text,
    photo_url text,
    is_resolved boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: schools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schools (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    sppg_id uuid,
    name text NOT NULL,
    address text,
    gps_lat double precision,
    gps_long double precision,
    student_count integer DEFAULT 0,
    deadline_time time without time zone,
    service_time_minutes integer DEFAULT 10,
    is_high_risk boolean DEFAULT false,
    tolerance_minutes integer DEFAULT 45,
    menu_default text
);


--
-- Name: sppgs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sppgs (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    address text,
    gps_lat double precision,
    gps_long double precision,
    created_at timestamp with time zone DEFAULT now(),
    email text,
    phone text,
    established_date date
);


--
-- Name: vehicles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicles (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    sppg_id uuid,
    plate_number text NOT NULL,
    driver_name text,
    capacity_limit integer DEFAULT 0,
    is_active boolean DEFAULT true
);


--
-- Name: messages; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.messages (
    topic text NOT NULL,
    extension text NOT NULL,
    payload jsonb,
    event text,
    private boolean DEFAULT false,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    inserted_at timestamp without time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL
)
PARTITION BY RANGE (inserted_at);


--
-- Name: schema_migrations; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: subscription; Type: TABLE; Schema: realtime; Owner: -
--

CREATE TABLE realtime.subscription (
    id bigint NOT NULL,
    subscription_id uuid NOT NULL,
    entity regclass NOT NULL,
    filters realtime.user_defined_filter[] DEFAULT '{}'::realtime.user_defined_filter[] NOT NULL,
    claims jsonb NOT NULL,
    claims_role regrole GENERATED ALWAYS AS (realtime.to_regrole((claims ->> 'role'::text))) STORED NOT NULL,
    created_at timestamp without time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: subscription_id_seq; Type: SEQUENCE; Schema: realtime; Owner: -
--

ALTER TABLE realtime.subscription ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME realtime.subscription_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: buckets; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets (
    id text NOT NULL,
    name text NOT NULL,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    public boolean DEFAULT false,
    avif_autodetection boolean DEFAULT false,
    file_size_limit bigint,
    allowed_mime_types text[],
    owner_id text,
    type storage.buckettype DEFAULT 'STANDARD'::storage.buckettype NOT NULL
);


--
-- Name: COLUMN buckets.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.buckets.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: buckets_analytics; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_analytics (
    name text NOT NULL,
    type storage.buckettype DEFAULT 'ANALYTICS'::storage.buckettype NOT NULL,
    format text DEFAULT 'ICEBERG'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: buckets_vectors; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.buckets_vectors (
    id text NOT NULL,
    type storage.buckettype DEFAULT 'VECTOR'::storage.buckettype NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: migrations; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.migrations (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


--
-- Name: objects; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    bucket_id text,
    name text,
    owner uuid,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    last_accessed_at timestamp with time zone DEFAULT now(),
    metadata jsonb,
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/'::text)) STORED,
    version text,
    owner_id text,
    user_metadata jsonb,
    level integer
);


--
-- Name: COLUMN objects.owner; Type: COMMENT; Schema: storage; Owner: -
--

COMMENT ON COLUMN storage.objects.owner IS 'Field is deprecated, use owner_id instead';


--
-- Name: prefixes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.prefixes (
    bucket_id text NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    level integer GENERATED ALWAYS AS (storage.get_level(name)) STORED NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


--
-- Name: s3_multipart_uploads; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads (
    id text NOT NULL,
    in_progress_size bigint DEFAULT 0 NOT NULL,
    upload_signature text NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    version text NOT NULL,
    owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_metadata jsonb
);


--
-- Name: s3_multipart_uploads_parts; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.s3_multipart_uploads_parts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    upload_id text NOT NULL,
    size bigint DEFAULT 0 NOT NULL,
    part_number integer NOT NULL,
    bucket_id text NOT NULL,
    key text NOT NULL COLLATE pg_catalog."C",
    etag text NOT NULL,
    owner_id text,
    version text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vector_indexes; Type: TABLE; Schema: storage; Owner: -
--

CREATE TABLE storage.vector_indexes (
    id text DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL COLLATE pg_catalog."C",
    bucket_id text NOT NULL,
    data_type text NOT NULL,
    dimension integer NOT NULL,
    distance_metric text NOT NULL,
    metadata_configuration jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens id; Type: DEFAULT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens ALTER COLUMN id SET DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass);


--
-- Data for Name: audit_log_entries; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.audit_log_entries (instance_id, id, payload, created_at, ip_address) FROM stdin;
\.


--
-- Data for Name: flow_state; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.flow_state (id, user_id, auth_code, code_challenge_method, code_challenge, provider_type, provider_access_token, provider_refresh_token, created_at, updated_at, authentication_method, auth_code_issued_at) FROM stdin;
2bec93fd-c42b-4e7c-b09c-20dedbc5c713	87c98256-6c40-4fe4-a83c-67f11730b937	747fcfae-2b72-440e-b9d9-4ada5a67d16b	s256	nMJZxMP3arfsKz35lpnvD4h-4vAMshlM5WJdZ27c_Lc	recovery			2025-11-26 16:48:58.847741+00	2025-11-26 16:49:15.285169+00	recovery	2025-11-26 16:49:15.285109+00
18f7cb02-e214-4035-9143-c7f8b715e218	87c98256-6c40-4fe4-a83c-67f11730b937	3a79c25a-71c1-4660-93d4-301a1fcc7378	s256	wCySVDIMopCfl7GguiuKHlY0KNjUL1QUPirx_1vrnlw	magiclink			2025-11-26 16:52:46.48507+00	2025-11-26 16:52:55.877383+00	magiclink	2025-11-26 16:52:55.877347+00
f8ace35a-a3c5-4bfa-af15-28cd922139ae	87c98256-6c40-4fe4-a83c-67f11730b937	a6ffd157-2b8f-4f43-9366-4b39fae489a7	s256	V4UZ4mfmSOjcEMQX9k9nqjhch5CNrjgUuCITeVhL5O8	magiclink			2025-11-26 17:02:38.117431+00	2025-11-26 17:04:32.389565+00	magiclink	2025-11-26 17:04:32.387112+00
f8774cc9-57a2-4a6b-8c11-70b7994d2aee	87c98256-6c40-4fe4-a83c-67f11730b937	31ff49ce-06b7-4d24-b5db-b055d1798982	s256	vr8STw3M9FYLYiuxEoqz2o9xEa5U6sOHzIqXLoECfas	magiclink			2025-11-26 17:09:07.438685+00	2025-11-26 17:09:07.438685+00	magiclink	\N
a2bcf22e-2df1-436b-b253-dbec32aae3d1	299ae383-acb7-40ea-a9c4-28c517d2e602	53f2fb43-863f-44b3-9ddc-162c0b65abce	s256	xM26rUNWvJn8LrkJcxYjqhSaDsGNyPv5p2n4ILVSSCU	magiclink			2025-11-28 02:32:18.749424+00	2025-11-28 02:32:18.749424+00	magiclink	\N
5e5a7519-1288-4a22-9cb0-df2b889c2f38	e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	56ae4233-9a35-4b2d-8da6-9a9e5ab686bd	s256	xjmakKf6HcNIit37deAwg7T5G-bGgDJ4Lz-LVc9J6eY	magiclink			2025-12-01 05:27:33.851688+00	2025-12-01 05:27:33.851688+00	magiclink	\N
45e96f03-8d40-4a6a-b9cc-f13a8f6b55c4	4f8f6708-17d2-4df7-a0fd-8046df660ca4	f74fac0b-8518-47e1-a407-fb89856f945d	s256	pWUHC7Zru30jzr53XayFxi1XNmwc7wrSf-T4D0tJktI	magiclink			2025-12-01 05:27:56.534116+00	2025-12-01 05:27:56.534116+00	magiclink	\N
9be03c84-dfa1-4242-9595-7556b8153cc6	df5a3994-22e3-4049-bd49-4a02a52828e6	43f5832d-019d-4a4e-8b99-91c83b077a2c	s256	J8vkZIQegQXvgsIlpDdyybjljQe128dut8YokKKs4-A	magiclink			2025-12-01 05:28:08.199225+00	2025-12-01 05:28:08.199225+00	magiclink	\N
2fe99c19-3c3d-4488-9adf-99b45a03238a	fbc43a0a-9cf3-47e3-be55-d8c4456582dd	d1573cc4-6833-4b1b-8d02-4c21c76ccda2	s256	Jhr82gmJSVRz44O65Jnas0wsIdL55dPZWRJFgSzV0T8	magiclink			2025-12-01 11:33:39.110883+00	2025-12-01 11:33:39.110883+00	magiclink	\N
\.


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) FROM stdin;
87c98256-6c40-4fe4-a83c-67f11730b937	87c98256-6c40-4fe4-a83c-67f11730b937	{"sub": "87c98256-6c40-4fe4-a83c-67f11730b937", "email": "pengawasbgn@gmail.com", "email_verified": false, "phone_verified": false}	email	2025-11-19 06:22:50.74942+00	2025-11-19 06:22:50.751167+00	2025-11-19 06:22:50.751167+00	3115d2fd-2388-47fa-9c27-bbd09ce14d52
575538d0-ec9f-4ade-ac19-8c17f1453900	575538d0-ec9f-4ade-ac19-8c17f1453900	{"sub": "575538d0-ec9f-4ade-ac19-8c17f1453900", "email": "sukajaya@gmail.com", "full_name": "Admin SPPG Sukajaya Lembang 1", "email_verified": false, "phone_verified": false}	email	2025-11-19 10:53:10.927946+00	2025-11-19 10:53:10.927999+00	2025-11-19 10:53:10.927999+00	e32b86aa-eda3-4e44-8b56-5ef97d13f50f
99edd030-5b13-4596-bf3a-d8a94b4cb4c0	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	{"sub": "99edd030-5b13-4596-bf3a-d8a94b4cb4c0", "email": "udin12@gmail.com", "full_name": "Udin Jamaludin", "email_verified": false, "phone_verified": false}	email	2025-11-19 12:04:25.662401+00	2025-11-19 12:04:25.662454+00	2025-11-19 12:04:25.662454+00	66e20714-98df-434e-8f4c-0bf44a428fcf
299ae383-acb7-40ea-a9c4-28c517d2e602	299ae383-acb7-40ea-a9c4-28c517d2e602	{"sub": "299ae383-acb7-40ea-a9c4-28c517d2e602", "email": "bahlil@gmail.com", "full_name": "bahlil", "email_verified": false, "phone_verified": false}	email	2025-11-23 11:12:02.091414+00	2025-11-23 11:12:02.091475+00	2025-11-23 11:12:02.091475+00	581ae29a-824a-4c01-b3e7-8b171edbe8f6
52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	{"sub": "52df0c3d-084d-4e3d-a9fe-8ae9ce923b95", "email": "fufufafa@gmail.com", "full_name": "Gibran", "email_verified": false, "phone_verified": false}	email	2025-11-23 12:59:48.849064+00	2025-11-23 12:59:48.849138+00	2025-11-23 12:59:48.849138+00	ab1a2b61-1afd-4ed8-9815-3685dfd871bc
239cad3e-219d-428f-ac63-fb8b902f4857	239cad3e-219d-428f-ac63-fb8b902f4857	{"sub": "239cad3e-219d-428f-ac63-fb8b902f4857", "email": "budikurir@gmail.com", "full_name": "budi", "email_verified": false, "phone_verified": false}	email	2025-11-25 06:57:19.6832+00	2025-11-25 06:57:19.68325+00	2025-11-25 06:57:19.68325+00	ac83e0cf-6aee-47df-b96d-c01583ac1123
8b89ca5b-b221-49d3-a28d-484338103877	8b89ca5b-b221-49d3-a28d-484338103877	{"sub": "8b89ca5b-b221-49d3-a28d-484338103877", "email": "perahbowoh12@gmail.com", "full_name": "perabowo", "email_verified": false, "phone_verified": false}	email	2025-11-26 16:03:50.55059+00	2025-11-26 16:03:50.550645+00	2025-11-26 16:03:50.550645+00	81a80803-60a7-4ad0-a76f-37103eb36437
87c2a543-1b4d-486f-b39c-16f213644e40	87c2a543-1b4d-486f-b39c-16f213644e40	{"sub": "87c2a543-1b4d-486f-b39c-16f213644e40", "email": "jorayapbesi@gmail.com", "full_name": "Jonathan", "email_verified": false, "phone_verified": false}	email	2025-11-27 05:23:42.410975+00	2025-11-27 05:23:42.411024+00	2025-11-27 05:23:42.411024+00	466fa470-fcc7-49a9-9bf9-dfe971b463b7
9603807d-79b5-45d6-8115-c66031ca5eaa	9603807d-79b5-45d6-8115-c66031ca5eaa	{"sub": "9603807d-79b5-45d6-8115-c66031ca5eaa", "email": "adam@gmail.com", "full_name": "Pak Adam", "email_verified": false, "phone_verified": false}	email	2025-11-30 16:52:21.995134+00	2025-11-30 16:52:21.995199+00	2025-11-30 16:52:21.995199+00	f9eda1d4-2f9b-4716-b492-007016250664
4f8f6708-17d2-4df7-a0fd-8046df660ca4	4f8f6708-17d2-4df7-a0fd-8046df660ca4	{"sub": "4f8f6708-17d2-4df7-a0fd-8046df660ca4", "email": "rezkysukajaya@gmail.com", "full_name": "Rezky Asmir", "email_verified": false, "phone_verified": false}	email	2025-12-01 04:16:15.134379+00	2025-12-01 04:16:15.134438+00	2025-12-01 04:16:15.134438+00	3ab0e794-0015-4a7b-a39e-e2ebb9dfd6af
fbc43a0a-9cf3-47e3-be55-d8c4456582dd	fbc43a0a-9cf3-47e3-be55-d8c4456582dd	{"sub": "fbc43a0a-9cf3-47e3-be55-d8c4456582dd", "email": "amandakayuambon@gmail.com", "full_name": "Amanda Juliet", "email_verified": false, "phone_verified": false}	email	2025-12-01 04:24:16.930022+00	2025-12-01 04:24:16.930071+00	2025-12-01 04:24:16.930071+00	6ef38ace-a583-45a9-8a84-5b950328f41d
854b3bf3-77a5-46ae-8c00-d2ab86f78cbb	854b3bf3-77a5-46ae-8c00-d2ab86f78cbb	{"sub": "854b3bf3-77a5-46ae-8c00-d2ab86f78cbb", "email": "lewis@gmail.com", "full_name": "Lewis Hamilton", "email_verified": false, "phone_verified": false}	email	2025-12-01 04:59:31.407903+00	2025-12-01 04:59:31.407953+00	2025-12-01 04:59:31.407953+00	9ee67812-9920-4e2b-a8c1-ec64535a51ee
89c9ec4e-8319-4966-b292-ce7c256c7b31	89c9ec4e-8319-4966-b292-ce7c256c7b31	{"sub": "89c9ec4e-8319-4966-b292-ce7c256c7b31", "email": "max@gmail.com", "full_name": "Max Verstappen", "email_verified": false, "phone_verified": false}	email	2025-12-01 04:59:46.773294+00	2025-12-01 04:59:46.773347+00	2025-12-01 04:59:46.773347+00	8d4693fa-fb78-4f97-8aeb-dd98df086dc5
62e03fa9-7cbb-4090-b5c2-d59bfc268bda	62e03fa9-7cbb-4090-b5c2-d59bfc268bda	{"sub": "62e03fa9-7cbb-4090-b5c2-d59bfc268bda", "email": "vincentsmpn6@gmail.com", "full_name": "Vincent Hernandes", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:00:31.200761+00	2025-12-01 05:00:31.200815+00	2025-12-01 05:00:31.200815+00	09381b81-c679-42a8-aeb1-17470e2bd0b1
21ece05e-1290-49e2-8b53-ec02e97c673a	21ece05e-1290-49e2-8b53-ec02e97c673a	{"sub": "21ece05e-1290-49e2-8b53-ec02e97c673a", "email": "andikabinawisata@gmail.com", "full_name": "Andika Rill", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:01:01.150424+00	2025-12-01 05:01:01.151095+00	2025-12-01 05:01:01.151095+00	7e0ed5a1-6daf-4f65-9650-47e559c83452
759f9b43-ea4d-44fb-a90c-54283028423c	759f9b43-ea4d-44fb-a90c-54283028423c	{"sub": "759f9b43-ea4d-44fb-a90c-54283028423c", "email": "aryabhayangkari19@gmail.com", "full_name": "Arya Well", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:01:30.390213+00	2025-12-01 05:01:30.390263+00	2025-12-01 05:01:30.390263+00	7455b616-ba03-448e-937c-4ab11badc9c9
31c9657e-17b6-4f66-b3a3-d623c78dbdac	31c9657e-17b6-4f66-b3a3-d623c78dbdac	{"sub": "31c9657e-17b6-4f66-b3a3-d623c78dbdac", "email": "deffapgri@gmail.com", "full_name": "Deffa Momo", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:02:08.506131+00	2025-12-01 05:02:08.506205+00	2025-12-01 05:02:08.506205+00	1c38d9ff-0648-4343-af18-97596caf0f9a
e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	{"sub": "e590dca8-4e0b-4aeb-9021-fe5ac9157f3f", "email": "khaerulpancasila@gmail.com", "full_name": "Khaerul Gacor", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:03:17.519959+00	2025-12-01 05:03:17.520004+00	2025-12-01 05:03:17.520004+00	3304bceb-14e7-40a6-9e43-9311517a705f
a1c4810c-8829-4f1d-a1c3-691c8c573c29	a1c4810c-8829-4f1d-a1c3-691c8c573c29	{"sub": "a1c4810c-8829-4f1d-a1c3-691c8c573c29", "email": "smpn6_7a@gmail.com", "full_name": "Siti Nurhaliza", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:06:38.031919+00	2025-12-01 05:06:38.031968+00	2025-12-01 05:06:38.031968+00	ed50fc41-b539-42e1-aab0-2005b756b399
3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf	3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf	{"sub": "3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf", "email": "smpn6_7b@gmail.com", "full_name": "Eiza Sahputra", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:06:58.605146+00	2025-12-01 05:06:58.605204+00	2025-12-01 05:06:58.605204+00	b8da789a-b957-4e3e-ada3-f7e9094020e5
56624f75-13c4-4487-ae0f-87f4f9115a42	56624f75-13c4-4487-ae0f-87f4f9115a42	{"sub": "56624f75-13c4-4487-ae0f-87f4f9115a42", "email": "smpn6_8a@gmail.com", "full_name": "William Nicole", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:07:24.164707+00	2025-12-01 05:07:24.164756+00	2025-12-01 05:07:24.164756+00	423d567b-53d9-49c2-b518-6a37633cbc58
7d65be34-1117-4e69-a6c5-cc3866400df5	7d65be34-1117-4e69-a6c5-cc3866400df5	{"sub": "7d65be34-1117-4e69-a6c5-cc3866400df5", "email": "smpn6_8b@gmail.com", "full_name": "Kevin Just", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:08:01.011466+00	2025-12-01 05:08:01.011529+00	2025-12-01 05:08:01.011529+00	45752a87-d08e-4ec6-85e5-3dc1dfca2983
df5a3994-22e3-4049-bd49-4a02a52828e6	df5a3994-22e3-4049-bd49-4a02a52828e6	{"sub": "df5a3994-22e3-4049-bd49-4a02a52828e6", "email": "aleykaryawangi@gmail.com", "full_name": "Aley Tirta", "email_verified": false, "phone_verified": false}	email	2025-12-01 05:19:18.055032+00	2025-12-01 05:19:18.05508+00	2025-12-01 05:19:18.05508+00	12c5c868-155a-4541-b069-dda7eae28728
\.


--
-- Data for Name: instances; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.instances (id, uuid, raw_base_config, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: mfa_amr_claims; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_amr_claims (session_id, created_at, updated_at, authentication_method, id) FROM stdin;
13c8c8dd-ab4a-4ca1-b4a9-330c17b61027	2025-11-27 05:17:17.98692+00	2025-11-27 05:17:17.98692+00	password	29a2a0f0-2f89-42bb-b176-9a677137af0c
7bc55c61-5a14-4c6b-8745-4a6937ec5b05	2025-12-01 05:19:18.070887+00	2025-12-01 05:19:18.070887+00	password	3b8c7da3-1c9e-4746-97fe-d4c7ffc3889c
1a6835eb-ea88-4b5d-87a4-07367cd00081	2025-12-01 05:19:28.259147+00	2025-12-01 05:19:28.259147+00	password	b74fa6e4-0b6f-496a-a7ec-021dde388bc3
70ead88a-4460-45ce-ba3d-9e38726fc8e8	2025-11-27 05:23:42.42105+00	2025-11-27 05:23:42.42105+00	password	652cb0c1-5424-4a4d-aa8a-665b4564f724
7f4bc089-e09c-42a1-bd7a-63b5060585bf	2025-11-27 05:26:22.40044+00	2025-11-27 05:26:22.40044+00	password	ea0e58df-cf52-4be3-a749-249ddd1d532a
ef35b9b2-5826-4bc3-a2a1-d91591f0b813	2025-11-27 06:51:48.688753+00	2025-11-27 06:51:48.688753+00	password	1d0c0bda-093f-497c-ba24-e51e75268b04
f8048689-2a7e-44e1-b635-d3bad4ccfe36	2025-11-27 07:25:32.869028+00	2025-11-27 07:25:32.869028+00	password	13ea5a18-4482-41cc-8480-b8aba7780f79
3967c48a-2884-4bf8-8a56-67c4f2928431	2025-11-27 07:33:45.684797+00	2025-11-27 07:33:45.684797+00	password	27c5780b-63c3-48a0-97ee-0a35681975fb
62b5344c-696b-46dd-a001-0ad90c292859	2025-11-27 08:31:29.904952+00	2025-11-27 08:31:29.904952+00	password	e4585a31-cade-4a8c-b9c3-767bda89cc36
7c9717b2-6cb5-41ba-9277-48b8b03f6ff8	2025-11-28 02:37:32.534684+00	2025-11-28 02:37:32.534684+00	password	d5e1a862-18a5-493d-9b3e-090b2b2e36b7
96938d54-bba1-4521-a580-6955e6a08bd6	2025-11-30 11:35:11.68447+00	2025-11-30 11:35:11.68447+00	password	bd2863b7-04a5-4ce7-9acb-3351226660d6
49b43e3f-c369-409c-8860-e979f6949f3f	2025-11-30 12:28:03.925034+00	2025-11-30 12:28:03.925034+00	password	20b6a405-daa7-429c-8533-2c8ed9c3348d
9879ad54-515e-4f0f-a913-fa49ce72a002	2025-11-30 12:43:48.377565+00	2025-11-30 12:43:48.377565+00	password	6a70fb5e-7934-494c-9f58-c330cf4f5c10
e078405c-e3f0-4290-924a-5dca06358208	2025-11-30 13:07:47.947779+00	2025-11-30 13:07:47.947779+00	password	87c3f085-83e3-4043-a6ab-26619c5dd584
2c6860db-3ff5-47fb-b6e7-045be9d0f79e	2025-11-30 14:06:17.888001+00	2025-11-30 14:06:17.888001+00	password	2a824e26-949f-4220-9717-9df537618ebb
3203841c-da76-4941-85c8-8dde8e0e810c	2025-11-30 14:37:48.971374+00	2025-11-30 14:37:48.971374+00	password	c3e8b69b-6cee-45b4-9048-77f8f166a110
d06eb9f8-951e-43f2-a3f3-5ec742787e70	2025-11-30 15:29:55.612299+00	2025-11-30 15:29:55.612299+00	password	a5f50836-45a2-48ca-a8fd-1a9208924d38
ce9f6eec-b4b7-4c6b-b88e-fe14ade0288d	2025-11-30 16:23:20.910225+00	2025-11-30 16:23:20.910225+00	password	a25ea838-f7a0-4352-a754-e649596dfbd9
2977e116-4c40-4f65-b487-b95ab8726f4c	2025-11-30 16:52:22.01071+00	2025-11-30 16:52:22.01071+00	password	65270c20-c57c-4122-9ad1-054d129145b9
7377664c-2637-4987-9764-2a658cb81df6	2025-11-30 17:00:49.666225+00	2025-11-30 17:00:49.666225+00	password	0f55ddc5-16ea-4a28-9506-3c54720bd3a6
bbf12034-df64-4c2e-a179-3252e8179e13	2025-11-30 17:04:50.028837+00	2025-11-30 17:04:50.028837+00	password	ae0d0726-fcdc-4b8b-971f-6420b572653b
7b691036-d5f5-4703-af04-0d3ee7fa094c	2025-11-30 17:11:37.82975+00	2025-11-30 17:11:37.82975+00	password	c5d67e6b-556e-4364-a393-b9383aeec2fa
8a95a400-52ba-495d-bf88-fcb3aa994e68	2025-11-30 17:43:25.500038+00	2025-11-30 17:43:25.500038+00	password	cea197a8-5de9-4b44-86f1-f54cf3dd36e1
459a35c2-20d8-465b-9d7a-886887f92d10	2025-11-25 05:49:54.438437+00	2025-11-25 05:49:54.438437+00	password	0d82ae19-eb02-4251-a7a6-ea8d1e68bcba
f091237e-2fa2-466d-89ac-454bd9893867	2025-11-30 18:08:09.627045+00	2025-11-30 18:08:09.627045+00	password	80236a65-4fcd-4aca-be83-d554b551c3f7
1e0e562f-3b8b-4437-8c48-1eeb848bd829	2025-12-01 03:57:01.687469+00	2025-12-01 03:57:01.687469+00	password	67099995-b858-4e4e-b21d-bd1fb0b94580
4ac1e10f-c6b9-4d3e-8a75-30a3c0eac6f4	2025-11-23 12:59:48.886132+00	2025-11-23 12:59:48.886132+00	password	f65f677a-f4c7-40e2-8aaf-820af65afcdd
f3c64228-ca3b-4174-98c6-fe18a9228ecf	2025-12-01 04:16:15.180431+00	2025-12-01 04:16:15.180431+00	password	7e8afdab-332a-4332-8f30-f6f8aa57eb0f
4276400e-90b7-4b2c-9178-7b4e99658949	2025-12-01 04:24:16.942426+00	2025-12-01 04:24:16.942426+00	password	75bcb66c-401d-4309-a5e7-5c0e26e49929
a339416f-86a6-4694-9294-7e5386fe399c	2025-11-25 06:57:19.701591+00	2025-11-25 06:57:19.701591+00	password	812732ee-550e-4372-9c8f-6ec0ead90391
76982c6c-d4d9-4e73-9b33-a2b86a67a511	2025-11-25 06:57:54.22972+00	2025-11-25 06:57:54.22972+00	password	97c50f4b-862d-42fa-8deb-42e87486eb72
652da8ad-db16-4488-a644-e1519c504313	2025-12-01 04:59:31.455517+00	2025-12-01 04:59:31.455517+00	password	af5a4b06-1c88-46f2-8496-0e87ddb7ce04
89a3a148-a172-48f0-8a57-bae62cc01fd2	2025-11-25 07:00:51.315849+00	2025-11-25 07:00:51.315849+00	password	1d9375e0-6077-40f0-9fc2-bbc8c401884c
45ae6b22-e1e7-4d3c-9465-907031557800	2025-12-01 04:59:46.802671+00	2025-12-01 04:59:46.802671+00	password	31ce9f97-c12a-401b-8067-e0589b02940b
aff3aaaf-c7f1-473d-a6ac-61146d5f8bc9	2025-12-01 05:00:31.210631+00	2025-12-01 05:00:31.210631+00	password	071aa4df-7203-4550-8821-8ea73e5181ba
16520364-8f12-4b2e-8430-eef41af9f1f4	2025-12-01 05:01:01.239445+00	2025-12-01 05:01:01.239445+00	password	333568bc-4a16-452e-a504-843b30fc9f23
0d64f05e-760d-420e-bce2-aa09ab86d803	2025-11-26 06:42:30.340655+00	2025-11-26 06:42:30.340655+00	password	4bf7d6e4-24ea-44ec-9574-0dc786f89e15
70d7959c-f32b-4efc-873c-2de98b45cc0f	2025-12-01 05:01:30.399191+00	2025-12-01 05:01:30.399191+00	password	40491716-04e1-4dc4-8774-6c00b8b1dcb2
1df5aa60-8d3d-4dd3-8507-b2aad7562910	2025-12-01 05:02:08.522932+00	2025-12-01 05:02:08.522932+00	password	0dc7541a-67d2-4127-93e4-9f5af495ac92
2bd5af8f-0d65-4b91-886b-3400148abe89	2025-12-01 05:03:17.549929+00	2025-12-01 05:03:17.549929+00	password	4568a309-0a9f-4fc1-b91d-4f2c2aecae6f
05c0389f-c05d-4dfb-94c6-84e2d84a0ffd	2025-12-01 05:06:38.043648+00	2025-12-01 05:06:38.043648+00	password	1ccd0664-501c-45af-94ad-e784c71eda3b
d36b4c66-852b-43fb-875e-5c719eeaa98f	2025-12-01 05:06:58.615163+00	2025-12-01 05:06:58.615163+00	password	681730ee-1855-4c79-b93a-0cbc07eb1c00
2bca4d67-3a84-4d77-992a-faa60f67099c	2025-12-01 05:07:24.172094+00	2025-12-01 05:07:24.172094+00	password	6496794a-0a77-4393-823c-9ab962f67ab8
564d8d1c-7d77-4ac1-a8cd-77dea7666340	2025-12-01 05:08:01.01899+00	2025-12-01 05:08:01.01899+00	password	907d7806-76a4-466f-ade7-11cfb125b1e1
489c2fc6-70d7-4c30-9491-7ddb58e82f2d	2025-11-26 16:03:50.563035+00	2025-11-26 16:03:50.563035+00	password	70deb313-0e05-4766-be44-0ef02fb5429e
\.


--
-- Data for Name: mfa_challenges; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_challenges (id, factor_id, created_at, verified_at, ip_address, otp_code, web_authn_session_data) FROM stdin;
\.


--
-- Data for Name: mfa_factors; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at, secret, phone, last_challenged_at, web_authn_credential, web_authn_aaguid, last_webauthn_challenge_data) FROM stdin;
\.


--
-- Data for Name: oauth_authorizations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_authorizations (id, authorization_id, client_id, user_id, redirect_uri, scope, state, resource, code_challenge, code_challenge_method, response_type, status, authorization_code, created_at, expires_at, approved_at, nonce) FROM stdin;
\.


--
-- Data for Name: oauth_clients; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_clients (id, client_secret_hash, registration_type, redirect_uris, grant_types, client_name, client_uri, logo_uri, created_at, updated_at, deleted_at, client_type) FROM stdin;
\.


--
-- Data for Name: oauth_consents; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.oauth_consents (id, user_id, client_id, scopes, granted_at, revoked_at) FROM stdin;
\.


--
-- Data for Name: one_time_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.one_time_tokens (id, user_id, token_type, token_hash, relates_to, created_at, updated_at) FROM stdin;
bb08b3bf-8a8e-42af-8d3e-0745ca0f8771	e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	recovery_token	pkce_e054dfca7b2680e55ced8f561e807ae8f74ddf9d19b8a0f363c5319a	khaerulpancasila@gmail.com	2025-12-01 05:27:35.695645	2025-12-01 05:27:35.695645
7a9a3497-4bad-4272-abbb-9db3e6fd8d5d	4f8f6708-17d2-4df7-a0fd-8046df660ca4	recovery_token	pkce_b0957062ff512280e9a5e1e2f0d170a51133e7ba2bd54ff26458a68f	rezkysukajaya@gmail.com	2025-12-01 05:27:58.262459	2025-12-01 05:27:58.262459
8c4a7b5c-7c79-42d7-944a-e4ab27c12240	df5a3994-22e3-4049-bd49-4a02a52828e6	recovery_token	pkce_7e4a5c25307c520b34c26000f504273923f4d9bdb8c68dab4762c743	aleykaryawangi@gmail.com	2025-12-01 05:28:10.158408	2025-12-01 05:28:10.158408
7d478b27-b2cd-4eda-8ddc-a05ae7ab1649	fbc43a0a-9cf3-47e3-be55-d8c4456582dd	recovery_token	pkce_3b2651f8ea7abbbcc658fce6492871b179594fe7e247d032084269b8	amandakayuambon@gmail.com	2025-12-01 11:33:41.039063	2025-12-01 11:33:41.039063
\.


--
-- Data for Name: refresh_tokens; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.refresh_tokens (instance_id, id, token, user_id, revoked, created_at, updated_at, parent, session_id) FROM stdin;
00000000-0000-0000-0000-000000000000	216	qbmjqo6jv442	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	f	2025-11-27 05:17:17.982579+00	2025-11-27 05:17:17.982579+00	\N	13c8c8dd-ab4a-4ca1-b4a9-330c17b61027
00000000-0000-0000-0000-000000000000	293	y4x42ou6maqk	4f8f6708-17d2-4df7-a0fd-8046df660ca4	f	2025-12-01 04:16:15.173289+00	2025-12-01 04:16:15.173289+00	\N	f3c64228-ca3b-4174-98c6-fe18a9228ecf
00000000-0000-0000-0000-000000000000	295	wsookx52mnk6	fbc43a0a-9cf3-47e3-be55-d8c4456582dd	f	2025-12-01 04:24:16.940609+00	2025-12-01 04:24:16.940609+00	\N	4276400e-90b7-4b2c-9178-7b4e99658949
00000000-0000-0000-0000-000000000000	220	plwwtzlvavft	87c2a543-1b4d-486f-b39c-16f213644e40	f	2025-11-27 05:23:42.419009+00	2025-11-27 05:23:42.419009+00	\N	70ead88a-4460-45ce-ba3d-9e38726fc8e8
00000000-0000-0000-0000-000000000000	223	uqwlnrgxnpdu	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-27 06:47:54.122341+00	2025-11-27 06:47:54.122341+00	fxppvwwns3xv	7f4bc089-e09c-42a1-bd7a-63b5060585bf
00000000-0000-0000-0000-000000000000	224	im2u7pefj24o	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	f	2025-11-27 06:47:55.625121+00	2025-11-27 06:47:55.625121+00	vzad4pv5wz52	89a3a148-a172-48f0-8a57-bae62cc01fd2
00000000-0000-0000-0000-000000000000	226	4huwhaom3kuf	575538d0-ec9f-4ade-ac19-8c17f1453900	t	2025-11-27 07:25:32.834494+00	2025-11-27 08:30:01.560286+00	\N	f8048689-2a7e-44e1-b635-d3bad4ccfe36
00000000-0000-0000-0000-000000000000	228	x2f3cxr5daqr	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-27 08:30:01.585798+00	2025-11-27 08:30:01.585798+00	4huwhaom3kuf	f8048689-2a7e-44e1-b635-d3bad4ccfe36
00000000-0000-0000-0000-000000000000	231	xztde4hjlch7	239cad3e-219d-428f-ac63-fb8b902f4857	f	2025-11-28 02:23:55.361373+00	2025-11-28 02:23:55.361373+00	7kwb5vzmgvg2	62b5344c-696b-46dd-a001-0ad90c292859
00000000-0000-0000-0000-000000000000	305	sdjhcrokqzba	e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	f	2025-12-01 05:03:17.539021+00	2025-12-01 05:03:17.539021+00	\N	2bd5af8f-0d65-4b91-886b-3400148abe89
00000000-0000-0000-0000-000000000000	308	eqa6tojltive	a1c4810c-8829-4f1d-a1c3-691c8c573c29	f	2025-12-01 05:06:38.041823+00	2025-12-01 05:06:38.041823+00	\N	05c0389f-c05d-4dfb-94c6-84e2d84a0ffd
00000000-0000-0000-0000-000000000000	238	e2pg7xqojayc	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 11:35:11.673347+00	2025-11-30 11:35:11.673347+00	\N	96938d54-bba1-4521-a580-6955e6a08bd6
00000000-0000-0000-0000-000000000000	309	gknjyvvitvba	3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf	f	2025-12-01 05:06:58.613225+00	2025-12-01 05:06:58.613225+00	\N	d36b4c66-852b-43fb-875e-5c719eeaa98f
00000000-0000-0000-0000-000000000000	310	zc5eyaadfnor	56624f75-13c4-4487-ae0f-87f4f9115a42	f	2025-12-01 05:07:24.170893+00	2025-12-01 05:07:24.170893+00	\N	2bca4d67-3a84-4d77-992a-faa60f67099c
00000000-0000-0000-0000-000000000000	241	ja6vxofc4afb	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 12:28:03.921318+00	2025-11-30 12:28:03.921318+00	\N	49b43e3f-c369-409c-8860-e979f6949f3f
00000000-0000-0000-0000-000000000000	243	5qrk2skq434w	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 13:07:47.911335+00	2025-11-30 13:07:47.911335+00	\N	e078405c-e3f0-4290-924a-5dca06358208
00000000-0000-0000-0000-000000000000	245	fnog7xqzc425	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 14:06:17.883851+00	2025-11-30 14:06:17.883851+00	\N	2c6860db-3ff5-47fb-b6e7-045be9d0f79e
00000000-0000-0000-0000-000000000000	311	4evqsja5cbuf	7d65be34-1117-4e69-a6c5-cc3866400df5	f	2025-12-01 05:08:01.017692+00	2025-12-01 05:08:01.017692+00	\N	564d8d1c-7d77-4ac1-a8cd-77dea7666340
00000000-0000-0000-0000-000000000000	248	ud57kc4vzsx4	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 14:37:48.968147+00	2025-11-30 14:37:48.968147+00	\N	3203841c-da76-4941-85c8-8dde8e0e810c
00000000-0000-0000-0000-000000000000	317	55flh2usakhu	df5a3994-22e3-4049-bd49-4a02a52828e6	f	2025-12-01 05:19:18.067135+00	2025-12-01 05:19:18.067135+00	\N	7bc55c61-5a14-4c6b-8745-4a6937ec5b05
00000000-0000-0000-0000-000000000000	236	z73aut6dlbrz	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	t	2025-11-28 02:37:32.53011+00	2025-11-30 15:36:43.375386+00	\N	7c9717b2-6cb5-41ba-9277-48b8b03f6ff8
00000000-0000-0000-0000-000000000000	252	knymzyhwm7zd	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	f	2025-11-30 15:36:43.382336+00	2025-11-30 15:36:43.382336+00	z73aut6dlbrz	7c9717b2-6cb5-41ba-9277-48b8b03f6ff8
00000000-0000-0000-0000-000000000000	318	qb65alap7hyq	df5a3994-22e3-4049-bd49-4a02a52828e6	f	2025-12-01 05:19:28.255419+00	2025-12-01 05:19:28.255419+00	\N	1a6835eb-ea88-4b5d-87a4-07367cd00081
00000000-0000-0000-0000-000000000000	269	nq27zu24c2gc	9603807d-79b5-45d6-8115-c66031ca5eaa	f	2025-11-30 16:52:22.007588+00	2025-11-30 16:52:22.007588+00	\N	2977e116-4c40-4f65-b487-b95ab8726f4c
00000000-0000-0000-0000-000000000000	277	z7crve7u4ehw	299ae383-acb7-40ea-a9c4-28c517d2e602	f	2025-11-30 17:04:50.02751+00	2025-11-30 17:04:50.02751+00	\N	bbf12034-df64-4c2e-a179-3252e8179e13
00000000-0000-0000-0000-000000000000	285	o5medchlcgpq	87c98256-6c40-4fe4-a83c-67f11730b937	t	2025-11-30 17:43:25.494731+00	2025-12-01 03:56:48.354429+00	\N	8a95a400-52ba-495d-bf88-fcb3aa994e68
00000000-0000-0000-0000-000000000000	289	cg7fkx7xfjcr	87c98256-6c40-4fe4-a83c-67f11730b937	f	2025-12-01 03:56:48.369085+00	2025-12-01 03:56:48.369085+00	o5medchlcgpq	8a95a400-52ba-495d-bf88-fcb3aa994e68
00000000-0000-0000-0000-000000000000	290	jcrqtsii7utf	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-12-01 03:57:01.683764+00	2025-12-01 03:57:01.683764+00	\N	1e0e562f-3b8b-4437-8c48-1eeb848bd829
00000000-0000-0000-0000-000000000000	80	3eui3e3n2r64	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	f	2025-11-23 12:59:48.882354+00	2025-11-23 12:59:48.882354+00	\N	4ac1e10f-c6b9-4d3e-8a75-30a3c0eac6f4
00000000-0000-0000-0000-000000000000	299	keipujw5z2hw	854b3bf3-77a5-46ae-8c00-d2ab86f78cbb	f	2025-12-01 04:59:31.441383+00	2025-12-01 04:59:31.441383+00	\N	652da8ad-db16-4488-a644-e1519c504313
00000000-0000-0000-0000-000000000000	222	fxppvwwns3xv	575538d0-ec9f-4ade-ac19-8c17f1453900	t	2025-11-27 05:26:22.399127+00	2025-11-27 06:47:54.096629+00	\N	7f4bc089-e09c-42a1-bd7a-63b5060585bf
00000000-0000-0000-0000-000000000000	157	vzad4pv5wz52	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	t	2025-11-25 07:00:51.313813+00	2025-11-27 06:47:55.624675+00	\N	89a3a148-a172-48f0-8a57-bae62cc01fd2
00000000-0000-0000-0000-000000000000	225	wiosntz7rfad	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-27 06:51:48.665018+00	2025-11-27 06:51:48.665018+00	\N	ef35b9b2-5826-4bc3-a2a1-d91591f0b813
00000000-0000-0000-0000-000000000000	227	5hupv23p54uc	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-27 07:33:45.668388+00	2025-11-27 07:33:45.668388+00	\N	3967c48a-2884-4bf8-8a56-67c4f2928431
00000000-0000-0000-0000-000000000000	300	2lz6s3yuwa7f	89c9ec4e-8319-4966-b292-ce7c256c7b31	f	2025-12-01 04:59:46.796935+00	2025-12-01 04:59:46.796935+00	\N	45ae6b22-e1e7-4d3c-9465-907031557800
00000000-0000-0000-0000-000000000000	230	7kwb5vzmgvg2	239cad3e-219d-428f-ac63-fb8b902f4857	t	2025-11-27 08:31:29.89392+00	2025-11-28 02:23:55.333212+00	\N	62b5344c-696b-46dd-a001-0ad90c292859
00000000-0000-0000-0000-000000000000	301	asgxalfzatkt	62e03fa9-7cbb-4090-b5c2-d59bfc268bda	f	2025-12-01 05:00:31.209389+00	2025-12-01 05:00:31.209389+00	\N	aff3aaaf-c7f1-473d-a6ac-61146d5f8bc9
00000000-0000-0000-0000-000000000000	302	hqbycz4fcot7	21ece05e-1290-49e2-8b53-ec02e97c673a	f	2025-12-01 05:01:01.218324+00	2025-12-01 05:01:01.218324+00	\N	16520364-8f12-4b2e-8430-eef41af9f1f4
00000000-0000-0000-0000-000000000000	303	nv7h2r5ruyxb	759f9b43-ea4d-44fb-a90c-54283028423c	f	2025-12-01 05:01:30.398003+00	2025-12-01 05:01:30.398003+00	\N	70d7959c-f32b-4efc-873c-2de98b45cc0f
00000000-0000-0000-0000-000000000000	304	sb44e4psu3xw	31c9657e-17b6-4f66-b3a3-d623c78dbdac	f	2025-12-01 05:02:08.518115+00	2025-12-01 05:02:08.518115+00	\N	1df5aa60-8d3d-4dd3-8507-b2aad7562910
00000000-0000-0000-0000-000000000000	242	ox6mgu52t3m5	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 12:43:48.355031+00	2025-11-30 12:43:48.355031+00	\N	9879ad54-515e-4f0f-a913-fa49ce72a002
00000000-0000-0000-0000-000000000000	251	fcgrwvjuhdie	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 15:29:55.609005+00	2025-11-30 15:29:55.609005+00	\N	d06eb9f8-951e-43f2-a3f3-5ec742787e70
00000000-0000-0000-0000-000000000000	263	uy2w6ifncws6	299ae383-acb7-40ea-a9c4-28c517d2e602	f	2025-11-30 16:23:20.908861+00	2025-11-30 16:23:20.908861+00	\N	ce9f6eec-b4b7-4c6b-b88e-fe14ade0288d
00000000-0000-0000-0000-000000000000	271	75mi6nrk4bd6	575538d0-ec9f-4ade-ac19-8c17f1453900	f	2025-11-30 17:00:49.658205+00	2025-11-30 17:00:49.658205+00	\N	7377664c-2637-4987-9764-2a658cb81df6
00000000-0000-0000-0000-000000000000	144	emtsvmpsqcvc	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	f	2025-11-25 05:49:54.430307+00	2025-11-25 05:49:54.430307+00	\N	459a35c2-20d8-465b-9d7a-886887f92d10
00000000-0000-0000-0000-000000000000	281	jaeeaj4kcu7d	299ae383-acb7-40ea-a9c4-28c517d2e602	f	2025-11-30 17:11:37.823165+00	2025-11-30 17:11:37.823165+00	\N	7b691036-d5f5-4703-af04-0d3ee7fa094c
00000000-0000-0000-0000-000000000000	288	l6fqdy6vjxb2	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	f	2025-11-30 18:08:09.625102+00	2025-11-30 18:08:09.625102+00	\N	f091237e-2fa2-466d-89ac-454bd9893867
00000000-0000-0000-0000-000000000000	154	6phl5d7fzkz5	239cad3e-219d-428f-ac63-fb8b902f4857	f	2025-11-25 06:57:19.695822+00	2025-11-25 06:57:19.695822+00	\N	a339416f-86a6-4694-9294-7e5386fe399c
00000000-0000-0000-0000-000000000000	155	3nxxhmrhn7oq	239cad3e-219d-428f-ac63-fb8b902f4857	f	2025-11-25 06:57:54.228309+00	2025-11-25 06:57:54.228309+00	\N	76982c6c-d4d9-4e73-9b33-a2b86a67a511
00000000-0000-0000-0000-000000000000	160	k3h74mnwrhen	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	f	2025-11-26 06:42:30.329538+00	2025-11-26 06:42:30.329538+00	\N	0d64f05e-760d-420e-bce2-aa09ab86d803
00000000-0000-0000-0000-000000000000	175	4eya74k2g3au	8b89ca5b-b221-49d3-a28d-484338103877	f	2025-11-26 16:03:50.56125+00	2025-11-26 16:03:50.56125+00	\N	489c2fc6-70d7-4c30-9491-7ddb58e82f2d
\.


--
-- Data for Name: saml_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_providers (id, sso_provider_id, entity_id, metadata_xml, metadata_url, attribute_mapping, created_at, updated_at, name_id_format) FROM stdin;
\.


--
-- Data for Name: saml_relay_states; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.saml_relay_states (id, sso_provider_id, request_id, for_email, redirect_to, created_at, updated_at, flow_state_id) FROM stdin;
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.schema_migrations (version) FROM stdin;
20171026211738
20171026211808
20171026211834
20180103212743
20180108183307
20180119214651
20180125194653
00
20210710035447
20210722035447
20210730183235
20210909172000
20210927181326
20211122151130
20211124214934
20211202183645
20220114185221
20220114185340
20220224000811
20220323170000
20220429102000
20220531120530
20220614074223
20220811173540
20221003041349
20221003041400
20221011041400
20221020193600
20221021073300
20221021082433
20221027105023
20221114143122
20221114143410
20221125140132
20221208132122
20221215195500
20221215195800
20221215195900
20230116124310
20230116124412
20230131181311
20230322519590
20230402418590
20230411005111
20230508135423
20230523124323
20230818113222
20230914180801
20231027141322
20231114161723
20231117164230
20240115144230
20240214120130
20240306115329
20240314092811
20240427152123
20240612123726
20240729123726
20240802193726
20240806073726
20241009103726
20250717082212
20250731150234
20250804100000
20250901200500
20250903112500
20250904133000
20250925093508
20251007112900
20251104100000
20251111201300
\.


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sessions (id, user_id, created_at, updated_at, factor_id, aal, not_after, refreshed_at, user_agent, ip, tag, oauth_client_id, refresh_token_hmac_key, refresh_token_counter, scopes) FROM stdin;
13c8c8dd-ab4a-4ca1-b4a9-330c17b61027	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	2025-11-27 05:17:17.979924+00	2025-11-27 05:17:17.979924+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.149.218	\N	\N	\N	\N	\N
f3c64228-ca3b-4174-98c6-fe18a9228ecf	4f8f6708-17d2-4df7-a0fd-8046df660ca4	2025-12-01 04:16:15.164532+00	2025-12-01 04:16:15.164532+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	182.253.228.74	\N	\N	\N	\N	\N
4276400e-90b7-4b2c-9178-7b4e99658949	fbc43a0a-9cf3-47e3-be55-d8c4456582dd	2025-12-01 04:24:16.939308+00	2025-12-01 04:24:16.939308+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
70ead88a-4460-45ce-ba3d-9e38726fc8e8	87c2a543-1b4d-486f-b39c-16f213644e40	2025-11-27 05:23:42.418214+00	2025-11-27 05:23:42.418214+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.144.218	\N	\N	\N	\N	\N
89a3a148-a172-48f0-8a57-bae62cc01fd2	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	2025-11-25 07:00:51.312225+00	2025-11-27 06:47:55.627231+00	\N	aal1	\N	2025-11-27 06:47:55.627119	Dart/3.10 (dart:io)	114.10.145.65	\N	\N	\N	\N	\N
ef35b9b2-5826-4bc3-a2a1-d91591f0b813	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-27 06:51:48.626235+00	2025-11-27 06:51:48.626235+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.145.65	\N	\N	\N	\N	\N
3967c48a-2884-4bf8-8a56-67c4f2928431	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-27 07:33:45.645295+00	2025-11-27 07:33:45.645295+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.145.65	\N	\N	\N	\N	\N
62b5344c-696b-46dd-a001-0ad90c292859	239cad3e-219d-428f-ac63-fb8b902f4857	2025-11-27 08:31:29.875979+00	2025-11-28 02:23:55.385999+00	\N	aal1	\N	2025-11-28 02:23:55.385899	Dart/3.10 (dart:io)	114.10.144.218	\N	\N	\N	\N	\N
2bd5af8f-0d65-4b91-886b-3400148abe89	e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	2025-12-01 05:03:17.531375+00	2025-12-01 05:03:17.531375+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
05c0389f-c05d-4dfb-94c6-84e2d84a0ffd	a1c4810c-8829-4f1d-a1c3-691c8c573c29	2025-12-01 05:06:38.039897+00	2025-12-01 05:06:38.039897+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.24.11	\N	\N	\N	\N	\N
d36b4c66-852b-43fb-875e-5c719eeaa98f	3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf	2025-12-01 05:06:58.611783+00	2025-12-01 05:06:58.611783+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.24.11	\N	\N	\N	\N	\N
9879ad54-515e-4f0f-a913-fa49ce72a002	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 12:43:48.323319+00	2025-11-30 12:43:48.323319+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
2bca4d67-3a84-4d77-992a-faa60f67099c	56624f75-13c4-4487-ae0f-87f4f9115a42	2025-12-01 05:07:24.170141+00	2025-12-01 05:07:24.170141+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
564d8d1c-7d77-4ac1-a8cd-77dea7666340	7d65be34-1117-4e69-a6c5-cc3866400df5	2025-12-01 05:08:01.016927+00	2025-12-01 05:08:01.016927+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.24.11	\N	\N	\N	\N	\N
7bc55c61-5a14-4c6b-8745-4a6937ec5b05	df5a3994-22e3-4049-bd49-4a02a52828e6	2025-12-01 05:19:18.065235+00	2025-12-01 05:19:18.065235+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.24.11	\N	\N	\N	\N	\N
d06eb9f8-951e-43f2-a3f3-5ec742787e70	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 15:29:55.607301+00	2025-11-30 15:29:55.607301+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
1a6835eb-ea88-4b5d-87a4-07367cd00081	df5a3994-22e3-4049-bd49-4a02a52828e6	2025-12-01 05:19:28.254233+00	2025-12-01 05:19:28.254233+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
ce9f6eec-b4b7-4c6b-b88e-fe14ade0288d	299ae383-acb7-40ea-a9c4-28c517d2e602	2025-11-30 16:23:20.907269+00	2025-11-30 16:23:20.907269+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
2977e116-4c40-4f65-b487-b95ab8726f4c	9603807d-79b5-45d6-8115-c66031ca5eaa	2025-11-30 16:52:22.005677+00	2025-11-30 16:52:22.005677+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.22.66	\N	\N	\N	\N	\N
bbf12034-df64-4c2e-a179-3252e8179e13	299ae383-acb7-40ea-a9c4-28c517d2e602	2025-11-30 17:04:50.026248+00	2025-11-30 17:04:50.026248+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.22.66	\N	\N	\N	\N	\N
8a95a400-52ba-495d-bf88-fcb3aa994e68	87c98256-6c40-4fe4-a83c-67f11730b937	2025-11-30 17:43:25.480537+00	2025-12-01 03:56:48.389815+00	\N	aal1	\N	2025-12-01 03:56:48.389101	Dart/3.10 (dart:io)	182.253.228.74	\N	\N	\N	\N	\N
1e0e562f-3b8b-4437-8c48-1eeb848bd829	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-12-01 03:57:01.67101+00	2025-12-01 03:57:01.67101+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	182.253.228.74	\N	\N	\N	\N	\N
4ac1e10f-c6b9-4d3e-8a75-30a3c0eac6f4	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	2025-11-23 12:59:48.88121+00	2025-11-23 12:59:48.88121+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.99.241	\N	\N	\N	\N	\N
459a35c2-20d8-465b-9d7a-886887f92d10	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	2025-11-25 05:49:54.418957+00	2025-11-25 05:49:54.418957+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.149.152	\N	\N	\N	\N	\N
a339416f-86a6-4694-9294-7e5386fe399c	239cad3e-219d-428f-ac63-fb8b902f4857	2025-11-25 06:57:19.6947+00	2025-11-25 06:57:19.6947+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.146.1	\N	\N	\N	\N	\N
76982c6c-d4d9-4e73-9b33-a2b86a67a511	239cad3e-219d-428f-ac63-fb8b902f4857	2025-11-25 06:57:54.227268+00	2025-11-25 06:57:54.227268+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.147.1	\N	\N	\N	\N	\N
0d64f05e-760d-420e-bce2-aa09ab86d803	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	2025-11-26 06:42:30.317033+00	2025-11-26 06:42:30.317033+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	114.10.146.160	\N	\N	\N	\N	\N
7f4bc089-e09c-42a1-bd7a-63b5060585bf	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-27 05:26:22.398146+00	2025-11-27 06:47:54.154744+00	\N	aal1	\N	2025-11-27 06:47:54.152857	Dart/3.10 (dart:io)	114.10.144.218	\N	\N	\N	\N	\N
f8048689-2a7e-44e1-b635-d3bad4ccfe36	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-27 07:25:32.785168+00	2025-11-27 08:30:01.617305+00	\N	aal1	\N	2025-11-27 08:30:01.615477	Dart/3.10 (dart:io)	114.10.149.218	\N	\N	\N	\N	\N
652da8ad-db16-4488-a644-e1519c504313	854b3bf3-77a5-46ae-8c00-d2ab86f78cbb	2025-12-01 04:59:31.429693+00	2025-12-01 04:59:31.429693+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
45ae6b22-e1e7-4d3c-9465-907031557800	89c9ec4e-8319-4966-b292-ce7c256c7b31	2025-12-01 04:59:46.794282+00	2025-12-01 04:59:46.794282+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
96938d54-bba1-4521-a580-6955e6a08bd6	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 11:35:11.659184+00	2025-11-30 11:35:11.659184+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
aff3aaaf-c7f1-473d-a6ac-61146d5f8bc9	62e03fa9-7cbb-4090-b5c2-d59bfc268bda	2025-12-01 05:00:31.208577+00	2025-12-01 05:00:31.208577+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.24.11	\N	\N	\N	\N	\N
49b43e3f-c369-409c-8860-e979f6949f3f	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 12:28:03.92026+00	2025-11-30 12:28:03.92026+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
489c2fc6-70d7-4c30-9491-7ddb58e82f2d	8b89ca5b-b221-49d3-a28d-484338103877	2025-11-26 16:03:50.559841+00	2025-11-26 16:03:50.559841+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
e078405c-e3f0-4290-924a-5dca06358208	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 13:07:47.868717+00	2025-11-30 13:07:47.868717+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
2c6860db-3ff5-47fb-b6e7-045be9d0f79e	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 14:06:17.878907+00	2025-11-30 14:06:17.878907+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
16520364-8f12-4b2e-8430-eef41af9f1f4	21ece05e-1290-49e2-8b53-ec02e97c673a	2025-12-01 05:01:01.203687+00	2025-12-01 05:01:01.203687+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.24.11	\N	\N	\N	\N	\N
70d7959c-f32b-4efc-873c-2de98b45cc0f	759f9b43-ea4d-44fb-a90c-54283028423c	2025-12-01 05:01:30.396569+00	2025-12-01 05:01:30.396569+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
3203841c-da76-4941-85c8-8dde8e0e810c	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 14:37:48.966277+00	2025-11-30 14:37:48.966277+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
1df5aa60-8d3d-4dd3-8507-b2aad7562910	31c9657e-17b6-4f66-b3a3-d623c78dbdac	2025-12-01 05:02:08.517247+00	2025-12-01 05:02:08.517247+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	112.215.209.95	\N	\N	\N	\N	\N
7c9717b2-6cb5-41ba-9277-48b8b03f6ff8	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	2025-11-28 02:37:32.526179+00	2025-11-30 15:36:43.394507+00	\N	aal1	\N	2025-11-30 15:36:43.394395	Dart/3.10 (dart:io)	140.213.24.151	\N	\N	\N	\N	\N
7377664c-2637-4987-9764-2a658cb81df6	575538d0-ec9f-4ade-ac19-8c17f1453900	2025-11-30 17:00:49.643648+00	2025-11-30 17:00:49.643648+00	\N	aal1	\N	\N	Dart/3.10 (dart:io)	140.213.22.66	\N	\N	\N	\N	\N
7b691036-d5f5-4703-af04-0d3ee7fa094c	299ae383-acb7-40ea-a9c4-28c517d2e602	2025-11-30 17:11:37.817812+00	2025-11-30 17:11:37.817812+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
f091237e-2fa2-466d-89ac-454bd9893867	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	2025-11-30 18:08:09.622795+00	2025-11-30 18:08:09.622795+00	\N	aal1	\N	\N	Dart/3.9 (dart:io)	182.10.97.8	\N	\N	\N	\N	\N
\.


--
-- Data for Name: sso_domains; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_domains (id, sso_provider_id, domain, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: sso_providers; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.sso_providers (id, resource_id, created_at, updated_at, disabled) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) FROM stdin;
00000000-0000-0000-0000-000000000000	239cad3e-219d-428f-ac63-fb8b902f4857	authenticated	authenticated	budikurir@gmail.com	$2a$10$ukn9TQGzlowSYsHPf1bYnub85eaCArmnNp7jLzhjpFQMgC2p4.xSO	2025-11-25 06:57:19.689552+00	\N		\N		\N			\N	2025-11-30 15:39:42.850077+00	{"provider": "email", "providers": ["email"]}	{"sub": "239cad3e-219d-428f-ac63-fb8b902f4857", "email": "budikurir@gmail.com", "full_name": "budi", "email_verified": true, "phone_verified": false}	\N	2025-11-25 06:57:19.666508+00	2025-11-30 15:39:42.853024+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	8b89ca5b-b221-49d3-a28d-484338103877	authenticated	authenticated	perahbowoh12@gmail.com	$2a$10$bkNGa6IYEQIhqlRAGsHK8OHzw7hcJ8q.hnlAmJKran4P6QRwzP6uC	2025-11-26 16:03:50.554573+00	\N		\N		\N			\N	2025-11-26 16:03:50.559743+00	{"provider": "email", "providers": ["email"]}	{"sub": "8b89ca5b-b221-49d3-a28d-484338103877", "email": "perahbowoh12@gmail.com", "full_name": "perabowo", "email_verified": true, "phone_verified": false}	\N	2025-11-26 16:03:50.541727+00	2025-11-26 16:03:50.562742+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	299ae383-acb7-40ea-a9c4-28c517d2e602	authenticated	authenticated	xgv1807@gmail.com	$2a$10$HyFFVU7HHAt0lLkHpbWj0eCMxjn7GwQKjs.1a5bQFSPETRw/rDGT6	2025-11-28 02:32:13.671581+00	\N		\N		\N			\N	2025-11-30 18:07:06.800164+00	{"provider": "email", "providers": ["email"]}	{"sub": "299ae383-acb7-40ea-a9c4-28c517d2e602", "email": "bahlil@gmail.com", "full_name": "bahlil", "email_verified": true, "phone_verified": false}	\N	2025-11-23 11:12:02.028431+00	2025-11-30 18:07:06.825907+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	authenticated	authenticated	udin12@gmail.com	$2a$10$ugBSQqHqI724znvfN7Z0Vel2MLoz.0vIb6ikjltppZ09JAthECQ0S	2025-11-19 12:04:25.674028+00	\N		\N		\N			\N	2025-11-30 18:08:09.622668+00	{"provider": "email", "providers": ["email"]}	{"sub": "99edd030-5b13-4596-bf3a-d8a94b4cb4c0", "email": "udin12@gmail.com", "full_name": "Udin Jamaludin", "email_verified": true, "phone_verified": false}	\N	2025-11-19 12:04:25.649541+00	2025-11-30 18:08:09.626727+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	4f8f6708-17d2-4df7-a0fd-8046df660ca4	authenticated	authenticated	rezkysukajaya@gmail.com	$2a$10$HZXVA8IEqfN3J9/8Nv3W9uK./IXFgXzKUsLCGUT2CtknBWxMLKvTe	2025-12-01 04:16:15.150268+00	\N		\N	pkce_b0957062ff512280e9a5e1e2f0d170a51133e7ba2bd54ff26458a68f	2025-12-01 05:27:56.536733+00			\N	2025-12-01 11:35:29.373112+00	{"provider": "email", "providers": ["email"]}	{"sub": "4f8f6708-17d2-4df7-a0fd-8046df660ca4", "email": "rezkysukajaya@gmail.com", "full_name": "Rezky Asmir", "email_verified": true, "phone_verified": false}	\N	2025-12-01 04:16:15.103232+00	2025-12-01 11:35:29.379143+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	52df0c3d-084d-4e3d-a9fe-8ae9ce923b95	authenticated	authenticated	fufufafa@gmail.com	$2a$10$y08O2xqLuhSpMyNheOn3f.FSmduqV6.z3yG0//G6cQIv4tpCtrByO	2025-11-23 12:59:48.869069+00	\N		\N		\N			\N	2025-11-28 02:37:32.526055+00	{"provider": "email", "providers": ["email"]}	{"sub": "52df0c3d-084d-4e3d-a9fe-8ae9ce923b95", "email": "fufufafa@gmail.com", "full_name": "Gibran", "email_verified": true, "phone_verified": false}	\N	2025-11-23 12:59:48.828381+00	2025-11-30 15:36:43.390113+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	87c2a543-1b4d-486f-b39c-16f213644e40	authenticated	authenticated	jorayapbesi@gmail.com	$2a$10$iT9Mes3u3803CMo9HGEPmuzRnCT3EjFOiixwpmiqQbRjJRtpHUQ4q	2025-11-27 05:23:42.415369+00	\N		\N		\N			\N	2025-11-27 05:26:12.148393+00	{"provider": "email", "providers": ["email"]}	{"sub": "87c2a543-1b4d-486f-b39c-16f213644e40", "email": "jorayapbesi@gmail.com", "full_name": "Jonathan", "email_verified": true, "phone_verified": false}	\N	2025-11-27 05:23:42.408581+00	2025-11-27 05:26:12.15968+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	854b3bf3-77a5-46ae-8c00-d2ab86f78cbb	authenticated	authenticated	lewis@gmail.com	$2a$10$QHBFH9McZWGoPjHZ/UYCoOXPbm71FNUoGHnZJadjxyk/ihBuDmKGa	2025-12-01 04:59:31.418604+00	\N		\N		\N			\N	2025-12-01 04:59:31.428943+00	{"provider": "email", "providers": ["email"]}	{"sub": "854b3bf3-77a5-46ae-8c00-d2ab86f78cbb", "email": "lewis@gmail.com", "full_name": "Lewis Hamilton", "email_verified": true, "phone_verified": false}	\N	2025-12-01 04:59:31.380305+00	2025-12-01 04:59:31.454996+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	fbc43a0a-9cf3-47e3-be55-d8c4456582dd	authenticated	authenticated	amandakayuambon@gmail.com	$2a$10$AAcmW2wKk6rDjON2O.4xHOVR1viD1Z83cUl7Zby9Hu0L7NAw74MDq	2025-12-01 04:24:16.935849+00	\N		\N	pkce_3b2651f8ea7abbbcc658fce6492871b179594fe7e247d032084269b8	2025-12-01 11:33:39.145997+00			\N	2025-12-01 05:16:43.622265+00	{"provider": "email", "providers": ["email"]}	{"sub": "fbc43a0a-9cf3-47e3-be55-d8c4456582dd", "email": "amandakayuambon@gmail.com", "full_name": "Amanda Juliet", "email_verified": true, "phone_verified": false}	\N	2025-12-01 04:24:16.923798+00	2025-12-01 11:33:41.014953+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	575538d0-ec9f-4ade-ac19-8c17f1453900	authenticated	authenticated	sukajaya@gmail.com	$2a$10$zodvL90BhnflY6x400AmzutV2w00L6AVMcPQxY4YNl4RQ2Jeck7lW	2025-11-19 10:53:10.930541+00	\N		\N		\N			\N	2025-12-01 03:59:32.430857+00	{"provider": "email", "providers": ["email"]}	{"sub": "575538d0-ec9f-4ade-ac19-8c17f1453900", "email": "sukajaya@gmail.com", "full_name": "Admin SPPG Sukajaya Lembang 1", "email_verified": true, "phone_verified": false}	\N	2025-11-19 10:53:10.924196+00	2025-12-01 03:59:32.436058+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	9603807d-79b5-45d6-8115-c66031ca5eaa	authenticated	authenticated	adam@gmail.com	$2a$10$VUJttsY4Onwlyticbt709eHelWy7u4jB3vmRC0YpGtMDt8rQhauEG	2025-11-30 16:52:22.000005+00	\N		\N		\N			\N	2025-11-30 16:52:32.715545+00	{"provider": "email", "providers": ["email"]}	{"sub": "9603807d-79b5-45d6-8115-c66031ca5eaa", "email": "adam@gmail.com", "full_name": "Pak Adam", "email_verified": true, "phone_verified": false}	\N	2025-11-30 16:52:21.987112+00	2025-11-30 16:52:32.718492+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	87c98256-6c40-4fe4-a83c-67f11730b937	authenticated	authenticated	lukasjoo17@gmail.com	$2a$10$6lGNuZn62pxWNFLBu4Nox.Pm7xcGdplCAiyjQhQIqRxLWG5sU684u	2025-11-26 16:38:47.585876+00	\N		\N		\N			\N	2025-12-01 11:35:05.649923+00	{"provider": "email", "providers": ["email"]}	{"email_verified": true}	\N	2025-11-19 06:22:50.723939+00	2025-12-01 11:35:05.691863+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	89c9ec4e-8319-4966-b292-ce7c256c7b31	authenticated	authenticated	max@gmail.com	$2a$10$ZrtCM/sjV59WrcWKNkUEIes3rPTtGiIVU62NO1ByNtyGotQAA0CNi	2025-12-01 04:59:46.782343+00	\N		\N		\N			\N	2025-12-01 04:59:46.792904+00	{"provider": "email", "providers": ["email"]}	{"sub": "89c9ec4e-8319-4966-b292-ce7c256c7b31", "email": "max@gmail.com", "full_name": "Max Verstappen", "email_verified": true, "phone_verified": false}	\N	2025-12-01 04:59:46.763335+00	2025-12-01 04:59:46.802269+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf	authenticated	authenticated	smpn6_7b@gmail.com	$2a$10$AGQe4J.i2O/viSzLysPsXeXYG90hg4wcjmMf/czvZeAGSskh0CYvC	2025-12-01 05:06:58.608578+00	\N		\N		\N			\N	2025-12-01 05:06:58.611694+00	{"provider": "email", "providers": ["email"]}	{"sub": "3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf", "email": "smpn6_7b@gmail.com", "full_name": "Eiza Sahputra", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:06:58.601347+00	2025-12-01 05:06:58.614853+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	759f9b43-ea4d-44fb-a90c-54283028423c	authenticated	authenticated	aryabhayangkari19@gmail.com	$2a$10$GVSg9zXjc3CaL4oh8gJESOe1xIFcQJfb.LLOWrtFfghTeSfgG1Iru	2025-12-01 05:01:30.392855+00	\N		\N		\N			\N	2025-12-01 05:01:30.396472+00	{"provider": "email", "providers": ["email"]}	{"sub": "759f9b43-ea4d-44fb-a90c-54283028423c", "email": "aryabhayangkari19@gmail.com", "full_name": "Arya Well", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:01:30.382701+00	2025-12-01 05:01:30.39888+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	df5a3994-22e3-4049-bd49-4a02a52828e6	authenticated	authenticated	aleykaryawangi@gmail.com	$2a$10$4ejA9zp40ObDSAyfRm999.WS33m8TdZRKq7Ztm876CIC0AWaNHUQS	2025-12-01 05:19:18.060645+00	\N		\N	pkce_7e4a5c25307c520b34c26000f504273923f4d9bdb8c68dab4762c743	2025-12-01 05:28:08.201776+00			\N	2025-12-01 05:19:28.254115+00	{"provider": "email", "providers": ["email"]}	{"sub": "df5a3994-22e3-4049-bd49-4a02a52828e6", "email": "aleykaryawangi@gmail.com", "full_name": "Aley Tirta", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:19:18.049991+00	2025-12-01 05:28:10.157526+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	a1c4810c-8829-4f1d-a1c3-691c8c573c29	authenticated	authenticated	smpn6_7a@gmail.com	$2a$10$qdjLdgj3ivlfxKBw20Cng.p54Evdsklrrx9mZx371T9vkMh9cH7sG	2025-12-01 05:06:38.035916+00	\N		\N		\N			\N	2025-12-01 05:06:38.039811+00	{"provider": "email", "providers": ["email"]}	{"sub": "a1c4810c-8829-4f1d-a1c3-691c8c573c29", "email": "smpn6_7a@gmail.com", "full_name": "Siti Nurhaliza", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:06:38.025098+00	2025-12-01 05:06:38.043198+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	21ece05e-1290-49e2-8b53-ec02e97c673a	authenticated	authenticated	andikabinawisata@gmail.com	$2a$10$QjFVVYw0mpZcagwJ81vye.SKFJFyG7U0IjLTmzvKd05PXm1wO5NeC	2025-12-01 05:01:01.192633+00	\N		\N		\N			\N	2025-12-01 05:20:12.596277+00	{"provider": "email", "providers": ["email"]}	{"sub": "21ece05e-1290-49e2-8b53-ec02e97c673a", "email": "andikabinawisata@gmail.com", "full_name": "Andika Rill", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:01:01.098248+00	2025-12-01 05:20:12.599376+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	56624f75-13c4-4487-ae0f-87f4f9115a42	authenticated	authenticated	smpn6_8a@gmail.com	$2a$10$s8nwjdhXNW/h7ymXifRW/e8DAzvR5mKKvZz6tAB34cR7IxuFUdDya	2025-12-01 05:07:24.16681+00	\N		\N		\N			\N	2025-12-01 05:07:24.170043+00	{"provider": "email", "providers": ["email"]}	{"sub": "56624f75-13c4-4487-ae0f-87f4f9115a42", "email": "smpn6_8a@gmail.com", "full_name": "William Nicole", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:07:24.162316+00	2025-12-01 05:07:24.171803+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	31c9657e-17b6-4f66-b3a3-d623c78dbdac	authenticated	authenticated	deffapgri@gmail.com	$2a$10$6RzJ.g1cXPPwbEqPRzKFL.jJvLFaAdfLc8ZimJArCBcHJB.GRjfzu	2025-12-01 05:02:08.51293+00	\N		\N		\N			\N	2025-12-01 05:02:08.517139+00	{"provider": "email", "providers": ["email"]}	{"sub": "31c9657e-17b6-4f66-b3a3-d623c78dbdac", "email": "deffapgri@gmail.com", "full_name": "Deffa Momo", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:02:08.495788+00	2025-12-01 05:02:08.522558+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	62e03fa9-7cbb-4090-b5c2-d59bfc268bda	authenticated	authenticated	vincentsmpn6@gmail.com	$2a$10$C3wqhJHOtkxiEm0wzz6i/etcDOJm/k4W0HqQvRTjaZMCk0/ojkJGS	2025-12-01 05:00:31.204894+00	\N		\N		\N			\N	2025-12-01 05:21:57.941281+00	{"provider": "email", "providers": ["email"]}	{"sub": "62e03fa9-7cbb-4090-b5c2-d59bfc268bda", "email": "vincentsmpn6@gmail.com", "full_name": "Vincent Hernandes", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:00:31.197654+00	2025-12-01 05:21:57.970878+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	7d65be34-1117-4e69-a6c5-cc3866400df5	authenticated	authenticated	smpn6_8b@gmail.com	$2a$10$I.x69DwFa0FR1PIIPWqOVe.ASloLXx3SjnkPuwMV6Gww.eWqRoa/.	2025-12-01 05:08:01.013572+00	\N		\N		\N			\N	2025-12-01 05:22:23.501824+00	{"provider": "email", "providers": ["email"]}	{"sub": "7d65be34-1117-4e69-a6c5-cc3866400df5", "email": "smpn6_8b@gmail.com", "full_name": "Kevin Just", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:08:01.0092+00	2025-12-01 05:22:23.541705+00	\N	\N			\N		0	\N		\N	f	\N	f
00000000-0000-0000-0000-000000000000	e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	authenticated	authenticated	khaerulpancasila@gmail.com	$2a$10$fqZaWgLD2ViyTLkVywJQ2etwDzw1dpTSVcchWAmEmsB7Rv5C4tXXi	2025-12-01 05:03:17.524072+00	\N		\N	pkce_e054dfca7b2680e55ced8f561e807ae8f74ddf9d19b8a0f363c5319a	2025-12-01 05:27:33.870997+00			\N	2025-12-01 05:14:05.303846+00	{"provider": "email", "providers": ["email"]}	{"sub": "e590dca8-4e0b-4aeb-9021-fe5ac9157f3f", "email": "khaerulpancasila@gmail.com", "full_name": "Khaerul Gacor", "email_verified": true, "phone_verified": false}	\N	2025-12-01 05:03:17.514425+00	2025-12-01 05:27:35.676988+00	\N	\N			\N		0	\N		\N	f	\N	f
\.


--
-- Data for Name: change_request_details; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.change_request_details (id, request_id, menu_id, new_quantity, new_schedule_time, new_schedule_date, old_quantity) FROM stdin;
\.


--
-- Data for Name: change_requests; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.change_requests (id, sppg_id, school_id, requester_id, request_type, old_notes, status, admin_response, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: class_receptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.class_receptions (id, stop_id, teacher_id, class_name, qty_received, notes, created_at, issue_type, proof_photo_url, admin_response, resolved_at) FROM stdin;
\.


--
-- Data for Name: delivery_routes; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.delivery_routes (id, date, sppg_id, vehicle_id, courier_id, status, start_time, end_time, load_proof_photo_url, menu_id, departure_time) FROM stdin;
\.


--
-- Data for Name: delivery_stops; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.delivery_stops (id, route_id, school_id, sequence_order, status, arrival_time, completion_time, received_qty, reception_notes, proof_photo_url, recipient_name, admin_response, resolved_at, courier_proof_photo_url, estimated_arrival_time) FROM stdin;
\.


--
-- Data for Name: menus; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.menus (id, sppg_id, name, category, cooking_duration_minutes, created_at) FROM stdin;
1bad49ed-5e27-4393-a8c4-050656e1337c	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Chicken Katsu	Lauk Protein	25	2025-12-01 11:40:00.441879+00
5bfab294-61cc-4c07-a1cd-771c690361cb	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Stik Tempe	Lauk Nabati	20	2025-12-01 11:40:00.441879+00
15ea9562-78fa-42b6-8159-1e15f6867d20	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Spaghetti	Karbo	10	2025-12-01 11:40:00.441879+00
d3eb0076-da01-4388-83b0-17fe0ae76bcd	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Mix Vegetable	Sayur	8	2025-12-01 11:40:00.441879+00
79d81db7-9f8d-4f73-851b-2598455bf065	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Chicken Bolognese	Saus/Lauk	15	2025-12-01 11:40:00.441879+00
0d7f4bbd-ff4b-4270-8bf4-e74497bcbf3e	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Melon Potong	Buah	5	2025-12-01 11:40:00.441879+00
016e86a8-21b3-4437-89b4-b4f7ce8ff5e9	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	French Fries	Karbo	15	2025-12-01 11:40:00.441879+00
182ef2a8-71f3-4603-aabc-5778282b2624	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Wortel Jagung Steam	Sayur	10	2025-12-01 11:40:00.441879+00
e1a77cca-eb41-43da-a44b-6174551b5a02	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Chicken Dimsum	Lauk Protein	12	2025-12-01 11:40:00.441879+00
c3be067a-4e2d-4afb-8dcd-242e21b9a2f8	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Semangka Potong	Buah	5	2025-12-01 11:40:00.441879+00
1b74a05b-9328-400a-9543-cb71d0cc8fdb	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Saus Tomat Sachet	Pelengkap	0	2025-12-01 11:40:00.441879+00
52a55ddd-8720-428a-a77a-28d8b992eab7	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Nasi Putih	Karbo	30	2025-12-01 11:40:00.441879+00
1786c2ed-f7c2-4e1f-86d5-4dd274116d28	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Ayam Geprek Katsu	Lauk Protein	25	2025-12-01 11:40:00.441879+00
fd0809e9-82ba-4768-bd75-f2e683d20fa3	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Tumis Tahu Wortel	Sayur	10	2025-12-01 11:40:00.441879+00
d5c6b2bd-3f73-442e-8a3a-09065a1f4911	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Timun & Tomat Iris	Sayur	5	2025-12-01 11:40:00.441879+00
a4880620-8106-44bb-9b10-0b72643ff0b1	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Melon Slice	Buah	5	2025-12-01 11:40:00.441879+00
1e0e3ea5-9da6-4ce9-8c3c-2d077cb06306	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Ayam Karage	Lauk Protein	20	2025-12-01 11:40:00.441879+00
5d9cad75-c209-4522-9834-27fa8e6a40c0	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Tahu Bejek Kemangi	Lauk Nabati	15	2025-12-01 11:40:00.441879+00
6068d724-b68e-4692-acb2-0d712cf3bd87	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Salad Coleslaw Mayo	Sayur	10	2025-12-01 11:40:00.441879+00
ac53899e-d8b8-45fd-b0f9-0a0ffd88e186	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Jeruk Manis	Buah	0	2025-12-01 11:40:00.441879+00
9570fb43-b94d-41df-abba-7b413b4b7756	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Roti Bun (Burger)	Karbo	5	2025-12-01 11:40:00.441879+00
44576188-a913-4662-aa16-fc1981392748	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Lettuce & Tomat	Sayur	5	2025-12-01 11:40:00.441879+00
88cd5658-f7fd-41e1-be80-29ac549bc2b1	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Saus Mayonnaise	Pelengkap	0	2025-12-01 11:40:00.441879+00
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.notifications (id, user_id, title, body, type, is_read, related_id, created_at) FROM stdin;
\.


--
-- Data for Name: production_schedules; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.production_schedules (id, sppg_id, date, menu_id, total_portions, start_cooking_time, target_finish_time, notes, created_at) FROM stdin;
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.profiles (id, full_name, role, sppg_id, school_id, created_at, email, class_name, dob, address, "position") FROM stdin;
87c98256-6c40-4fe4-a83c-67f11730b937	Admin BGN	bgn	\N	\N	2025-11-19 06:24:35.685412+00	lukasjoo17@gmail.com	\N	\N	\N	\N
4f8f6708-17d2-4df7-a0fd-8046df660ca4	Rezky Asmir	admin_sppg	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	\N	2025-12-01 04:16:15.350594+00	rezkysukajaya@gmail.com	\N	\N	\N	\N
fbc43a0a-9cf3-47e3-be55-d8c4456582dd	Amanda Juliet	admin_sppg	851f3b68-3c34-4cdf-9d36-c576aae60578	\N	2025-12-01 04:24:17.063766+00	amandakayuambon@gmail.com	\N	\N	\N	\N
854b3bf3-77a5-46ae-8c00-d2ab86f78cbb	Lewis Hamilton	kurir	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	\N	2025-12-01 04:59:31.606806+00	lewis@gmail.com	\N	\N	\N	\N
89c9ec4e-8319-4966-b292-ce7c256c7b31	Max Verstappen	kurir	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	\N	2025-12-01 04:59:46.921527+00	max@gmail.com	\N	\N	\N	\N
62e03fa9-7cbb-4090-b5c2-d59bfc268bda	Vincent Hernandes	koordinator	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	5d61cb08-02a2-4886-baaf-13a794afe9de	2025-12-01 05:00:31.368336+00	vincentsmpn6@gmail.com	\N	\N	\N	\N
21ece05e-1290-49e2-8b53-ec02e97c673a	Andika Rill	koordinator	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	4c8f9325-8d93-4151-b535-69d7d7d0263c	2025-12-01 05:01:01.610848+00	andikabinawisata@gmail.com	\N	\N	\N	\N
759f9b43-ea4d-44fb-a90c-54283028423c	Arya Well	koordinator	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	42b865b0-09ff-43d2-ad73-61d6784f9fb0	2025-12-01 05:01:30.936189+00	aryabhayangkari19@gmail.com	\N	\N	\N	\N
31c9657e-17b6-4f66-b3a3-d623c78dbdac	Deffa Momo	koordinator	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	eb691e6a-4655-4d7b-a1bd-954851b48313	2025-12-01 05:02:08.676976+00	deffapgri@gmail.com	\N	\N	\N	\N
e590dca8-4e0b-4aeb-9021-fe5ac9157f3f	Khaerul Gacor	koordinator	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	99688918-7097-43ad-a293-526159101e6d	2025-12-01 05:03:17.695993+00	khaerulpancasila@gmail.com	\N	\N	\N	\N
a1c4810c-8829-4f1d-a1c3-691c8c573c29	Siti Nurhaliza	walikelas	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	5d61cb08-02a2-4886-baaf-13a794afe9de	2025-12-01 05:06:38.156713+00	smpn6_7a@gmail.com	7A	\N	\N	\N
3b66df4f-307b-4d90-ba1b-0b08ab1c7ebf	Eiza Sahputra	walikelas	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	5d61cb08-02a2-4886-baaf-13a794afe9de	2025-12-01 05:06:58.761113+00	smpn6_7b@gmail.com	7B	\N	\N	\N
56624f75-13c4-4487-ae0f-87f4f9115a42	William Nicole	walikelas	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	5d61cb08-02a2-4886-baaf-13a794afe9de	2025-12-01 05:07:24.256865+00	smpn6_8a@gmail.com	8A	\N	\N	\N
7d65be34-1117-4e69-a6c5-cc3866400df5	Kevin Just	walikelas	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	5d61cb08-02a2-4886-baaf-13a794afe9de	2025-12-01 05:08:01.161202+00	smpn6_8b@gmail.com	8B	\N	\N	\N
df5a3994-22e3-4049-bd49-4a02a52828e6	Aley Tirta	admin_sppg	5f43c4e4-ca11-4e57-aa76-9ce3d60b208f	\N	2025-12-01 05:19:18.210007+00	aleykaryawangi@gmail.com	\N	\N	\N	\N
\.


--
-- Data for Name: qc_reports; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.qc_reports (id, school_id, reporter_id, report_type, description, photo_url, is_resolved, created_at) FROM stdin;
\.


--
-- Data for Name: schools; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.schools (id, sppg_id, name, address, gps_lat, gps_long, student_count, deadline_time, service_time_minutes, is_high_risk, tolerance_minutes, menu_default) FROM stdin;
eb691e6a-4655-4d7b-a1bd-954851b48313	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	TK PGRI	Jl. Masjid Panorama No. 21	-6.813957977695887	107.62382483645504	105	09:10:00	15	t	40	Stik Tempe, Spaghetti, Mix Vegetable, Chicken Bolognese, Melon
42b865b0-09ff-43d2-ad73-61d6784f9fb0	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	TK Bhayangkari 19	Jl. Bhayangkara II	-6.815080555108704	107.6164258682148	120	09:10:00	15	f	40	French Fries, Dimsum, Wortel Jagung, Semangka, Saus Tomat
05a1c300-c286-4c99-815b-f1d09668a12d	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	SDN Lembang		-6.815648184767863	107.62227197585047	300	09:40:00	10	f	45	
9d78ef2f-23dc-4196-983a-8bcf379c84b1	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	SDN Merdeka		-6.822905042284374	107.61258351832426	250	09:40:00	10	t	45	
99688918-7097-43ad-a293-526159101e6d	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	SDN Pancasila 		-6.822699163459716	107.61268183959203	220	09:30:00	15	t	45	
5d61cb08-02a2-4886-baaf-13a794afe9de	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	SMPN 6 Lembang		-6.8229237050304405	107.61266236506818	350	10:00:00	20	f	45	
536e1c09-bdad-485c-af26-5048c5a8ce86	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	MTs Islam Al Musyawarah		-6.820005694612192	107.61592046721867	180	09:00:00	15	f	30	
94b270c8-272b-4cf3-b444-a2180fdc380c	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	SMAS Islam Al Musyawarah		-6.819910730879592	107.61585561157945	150	09:40:00	15	f	25	
4c8f9325-8d93-4151-b535-69d7d7d0263c	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	SMKS Bina Wisata Lembang		-6.820793564818919	107.62049167604711	210	09:30:00	25	f	50	
00cf1bdc-da40-4eab-ad25-35141ac1e613	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	Posyandu Tulip RW 03 Lembang		-6.867472659665116	107.5470550403888	120	10:30:00	20	t	20	
\.


--
-- Data for Name: sppgs; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sppgs (id, name, address, gps_lat, gps_long, created_at, email, phone, established_date) FROM stdin;
1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	SPPG Sukajaya Lembang	Jl. Kolonel	-6.805139843364466	107.59356237696166	2025-12-01 04:16:14.677568+00	sukajaya@gmail.com	542896433	\N
851f3b68-3c34-4cdf-9d36-c576aae60578	SPPG Kayuambon Lembang	Jl. Maribaya No. 50	-6.8183762877421605	107.63120657491918	2025-12-01 04:24:16.589744+00	kayuambon@gmail.com	54266863	\N
5f43c4e4-ca11-4e57-aa76-9ce3d60b208f	SPPG Karyawangi	Cihanjuang Rahayu	-6.803381788032287	107.58098016308692	2025-12-01 05:19:17.534476+00	karyawangi@gmail.com	54236655	\N
\.


--
-- Data for Name: vehicles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.vehicles (id, sppg_id, plate_number, driver_name, capacity_limit, is_active) FROM stdin;
0df5af82-9115-48b8-aff3-35a8cf265f00	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	D 3301 MAX	Max Verstappen 	500	t
7154e730-d0be-429e-85db-b726619cf3c1	1ec001e5-08d6-4f44-b59d-ef6d0baa27e8	D 6767 YES	Lewis Hamilton 	500	t
\.


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.schema_migrations (version, inserted_at) FROM stdin;
20211116024918	2025-11-18 08:05:42
20211116045059	2025-11-18 08:05:42
20211116050929	2025-11-18 08:05:42
20211116051442	2025-11-18 08:05:42
20211116212300	2025-11-18 08:05:42
20211116213355	2025-11-18 08:05:42
20211116213934	2025-11-18 08:05:42
20211116214523	2025-11-18 08:05:42
20211122062447	2025-11-18 08:05:42
20211124070109	2025-11-18 08:05:42
20211202204204	2025-11-18 08:05:42
20211202204605	2025-11-18 08:05:42
20211210212804	2025-11-18 08:05:42
20211228014915	2025-11-18 08:05:42
20220107221237	2025-11-18 08:05:42
20220228202821	2025-11-18 08:05:42
20220312004840	2025-11-18 08:05:42
20220603231003	2025-11-18 08:05:42
20220603232444	2025-11-18 08:05:42
20220615214548	2025-11-18 08:05:42
20220712093339	2025-11-18 08:05:42
20220908172859	2025-11-18 08:05:42
20220916233421	2025-11-18 08:05:42
20230119133233	2025-11-18 08:05:42
20230128025114	2025-11-18 08:05:42
20230128025212	2025-11-18 08:05:42
20230227211149	2025-11-18 08:05:42
20230228184745	2025-11-18 08:05:42
20230308225145	2025-11-18 08:05:42
20230328144023	2025-11-18 08:05:42
20231018144023	2025-11-18 08:05:42
20231204144023	2025-11-18 08:05:42
20231204144024	2025-11-18 08:05:42
20231204144025	2025-11-18 08:05:42
20240108234812	2025-11-18 08:05:42
20240109165339	2025-11-18 08:05:42
20240227174441	2025-11-18 08:05:42
20240311171622	2025-11-18 08:05:42
20240321100241	2025-11-18 08:05:43
20240401105812	2025-11-18 08:05:43
20240418121054	2025-11-18 08:05:43
20240523004032	2025-11-18 08:05:43
20240618124746	2025-11-18 08:05:43
20240801235015	2025-11-18 08:05:43
20240805133720	2025-11-18 08:05:43
20240827160934	2025-11-18 08:05:43
20240919163303	2025-11-18 08:05:43
20240919163305	2025-11-18 08:05:43
20241019105805	2025-11-18 08:05:43
20241030150047	2025-11-18 08:05:43
20241108114728	2025-11-18 08:05:43
20241121104152	2025-11-18 08:05:43
20241130184212	2025-11-18 08:05:43
20241220035512	2025-11-18 08:05:43
20241220123912	2025-11-18 08:05:43
20241224161212	2025-11-18 08:05:43
20250107150512	2025-11-18 08:05:43
20250110162412	2025-11-18 08:05:43
20250123174212	2025-11-18 08:05:43
20250128220012	2025-11-18 08:05:43
20250506224012	2025-11-18 08:05:43
20250523164012	2025-11-18 08:05:43
20250714121412	2025-11-18 08:05:43
20250905041441	2025-11-18 08:05:43
20251103001201	2025-11-18 08:05:43
\.


--
-- Data for Name: subscription; Type: TABLE DATA; Schema: realtime; Owner: -
--

COPY realtime.subscription (id, subscription_id, entity, filters, claims, created_at) FROM stdin;
\.


--
-- Data for Name: buckets; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets (id, name, owner, created_at, updated_at, public, avif_autodetection, file_size_limit, allowed_mime_types, owner_id, type) FROM stdin;
evidence	evidence	\N	2025-11-23 18:02:16.691673+00	2025-11-23 18:02:16.691673+00	t	f	\N	\N	\N	STANDARD
\.


--
-- Data for Name: buckets_analytics; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_analytics (name, type, format, created_at, updated_at, id, deleted_at) FROM stdin;
\.


--
-- Data for Name: buckets_vectors; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.buckets_vectors (id, type, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: migrations; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.migrations (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	e18db593bcde2aca2a408c4d1100f6abba2195df	2025-11-18 08:05:42.29159
1	initialmigration	6ab16121fbaa08bbd11b712d05f358f9b555d777	2025-11-18 08:05:42.298498
2	storage-schema	5c7968fd083fcea04050c1b7f6253c9771b99011	2025-11-18 08:05:42.303618
3	pathtoken-column	2cb1b0004b817b29d5b0a971af16bafeede4b70d	2025-11-18 08:05:42.322223
4	add-migrations-rls	427c5b63fe1c5937495d9c635c263ee7a5905058	2025-11-18 08:05:42.376397
5	add-size-functions	79e081a1455b63666c1294a440f8ad4b1e6a7f84	2025-11-18 08:05:42.38303
6	change-column-name-in-get-size	f93f62afdf6613ee5e7e815b30d02dc990201044	2025-11-18 08:05:42.390462
7	add-rls-to-buckets	e7e7f86adbc51049f341dfe8d30256c1abca17aa	2025-11-18 08:05:42.396414
8	add-public-to-buckets	fd670db39ed65f9d08b01db09d6202503ca2bab3	2025-11-18 08:05:42.402281
9	fix-search-function	3a0af29f42e35a4d101c259ed955b67e1bee6825	2025-11-18 08:05:42.408114
10	search-files-search-function	68dc14822daad0ffac3746a502234f486182ef6e	2025-11-18 08:05:42.414927
11	add-trigger-to-auto-update-updated_at-column	7425bdb14366d1739fa8a18c83100636d74dcaa2	2025-11-18 08:05:42.421241
12	add-automatic-avif-detection-flag	8e92e1266eb29518b6a4c5313ab8f29dd0d08df9	2025-11-18 08:05:42.428019
13	add-bucket-custom-limits	cce962054138135cd9a8c4bcd531598684b25e7d	2025-11-18 08:05:42.433623
14	use-bytes-for-max-size	941c41b346f9802b411f06f30e972ad4744dad27	2025-11-18 08:05:42.441131
15	add-can-insert-object-function	934146bc38ead475f4ef4b555c524ee5d66799e5	2025-11-18 08:05:42.466511
16	add-version	76debf38d3fd07dcfc747ca49096457d95b1221b	2025-11-18 08:05:42.476774
17	drop-owner-foreign-key	f1cbb288f1b7a4c1eb8c38504b80ae2a0153d101	2025-11-18 08:05:42.488116
18	add_owner_id_column_deprecate_owner	e7a511b379110b08e2f214be852c35414749fe66	2025-11-18 08:05:42.494943
19	alter-default-value-objects-id	02e5e22a78626187e00d173dc45f58fa66a4f043	2025-11-18 08:05:42.504584
20	list-objects-with-delimiter	cd694ae708e51ba82bf012bba00caf4f3b6393b7	2025-11-18 08:05:42.511688
21	s3-multipart-uploads	8c804d4a566c40cd1e4cc5b3725a664a9303657f	2025-11-18 08:05:42.523409
22	s3-multipart-uploads-big-ints	9737dc258d2397953c9953d9b86920b8be0cdb73	2025-11-18 08:05:42.544605
23	optimize-search-function	9d7e604cddc4b56a5422dc68c9313f4a1b6f132c	2025-11-18 08:05:42.559962
24	operation-function	8312e37c2bf9e76bbe841aa5fda889206d2bf8aa	2025-11-18 08:05:42.56779
25	custom-metadata	d974c6057c3db1c1f847afa0e291e6165693b990	2025-11-18 08:05:42.574541
26	objects-prefixes	ef3f7871121cdc47a65308e6702519e853422ae2	2025-11-18 08:05:42.580618
27	search-v2	33b8f2a7ae53105f028e13e9fcda9dc4f356b4a2	2025-11-18 08:05:42.600101
28	object-bucket-name-sorting	ba85ec41b62c6a30a3f136788227ee47f311c436	2025-11-18 08:05:43.41163
29	create-prefixes	a7b1a22c0dc3ab630e3055bfec7ce7d2045c5b7b	2025-11-18 08:05:43.421306
30	update-object-levels	6c6f6cc9430d570f26284a24cf7b210599032db7	2025-11-18 08:05:43.427449
31	objects-level-index	33f1fef7ec7fea08bb892222f4f0f5d79bab5eb8	2025-11-18 08:05:43.434936
32	backward-compatible-index-on-objects	2d51eeb437a96868b36fcdfb1ddefdf13bef1647	2025-11-18 08:05:43.443481
33	backward-compatible-index-on-prefixes	fe473390e1b8c407434c0e470655945b110507bf	2025-11-18 08:05:43.452425
34	optimize-search-function-v1	82b0e469a00e8ebce495e29bfa70a0797f7ebd2c	2025-11-18 08:05:43.454598
35	add-insert-trigger-prefixes	63bb9fd05deb3dc5e9fa66c83e82b152f0caf589	2025-11-18 08:05:43.461589
36	optimise-existing-functions	81cf92eb0c36612865a18016a38496c530443899	2025-11-18 08:05:43.467172
37	add-bucket-name-length-trigger	3944135b4e3e8b22d6d4cbb568fe3b0b51df15c1	2025-11-18 08:05:43.474991
38	iceberg-catalog-flag-on-buckets	19a8bd89d5dfa69af7f222a46c726b7c41e462c5	2025-11-18 08:05:43.481999
39	add-search-v2-sort-support	39cf7d1e6bf515f4b02e41237aba845a7b492853	2025-11-18 08:05:43.493775
40	fix-prefix-race-conditions-optimized	fd02297e1c67df25a9fc110bf8c8a9af7fb06d1f	2025-11-18 08:05:43.502385
41	add-object-level-update-trigger	44c22478bf01744b2129efc480cd2edc9a7d60e9	2025-11-18 08:05:43.510825
42	rollback-prefix-triggers	f2ab4f526ab7f979541082992593938c05ee4b47	2025-11-18 08:05:43.517755
43	fix-object-level	ab837ad8f1c7d00cc0b7310e989a23388ff29fc6	2025-11-18 08:05:43.524342
44	vector-bucket-type	99c20c0ffd52bb1ff1f32fb992f3b351e3ef8fb3	2025-11-18 08:05:43.536307
45	vector-buckets	049e27196d77a7cb76497a85afae669d8b230953	2025-11-18 08:05:43.542236
46	buckets-objects-grants	fedeb96d60fefd8e02ab3ded9fbde05632f84aed	2025-11-18 08:05:43.554547
47	iceberg-table-metadata	649df56855c24d8b36dd4cc1aeb8251aa9ad42c2	2025-11-18 08:05:43.560922
48	iceberg-catalog-ids	2666dff93346e5d04e0a878416be1d5fec345d6f	2025-11-18 08:05:43.569601
\.


--
-- Data for Name: objects; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata, level) FROM stdin;
248096bb-0f4e-42f1-a139-350be94e716e	evidence	stops/1764215124363.jpg	299ae383-acb7-40ea-a9c4-28c517d2e602	2025-11-27 03:45:25.389118+00	2025-11-27 03:45:25.389118+00	2025-11-27 03:45:25.389118+00	{"eTag": "\\"26b788e53d2b89c3e14e1e23c7bb3d94\\"", "size": 93113, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-27T03:45:26.000Z", "contentLength": 93113, "httpStatusCode": 200}	2ce6ec69-86ab-4f9d-9715-adbaa61aa022	299ae383-acb7-40ea-a9c4-28c517d2e602	{}	2
32bc0d12-e734-4f21-9444-1ce76a914869	evidence	loading_proof/1764215775546.jpg	239cad3e-219d-428f-ac63-fb8b902f4857	2025-11-27 03:56:16.99893+00	2025-11-27 03:56:16.99893+00	2025-11-27 03:56:16.99893+00	{"eTag": "\\"7f745794840109835c6f561cb76124b3\\"", "size": 62731, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-27T03:56:17.000Z", "contentLength": 62731, "httpStatusCode": 200}	7811191c-e9ba-467e-923b-a33fde84ab37	239cad3e-219d-428f-ac63-fb8b902f4857	{}	2
6acbd613-13a1-4d36-bb18-de56e40a34ae	evidence	arrival_proof/1764215786927.jpg	239cad3e-219d-428f-ac63-fb8b902f4857	2025-11-27 03:56:27.935917+00	2025-11-27 03:56:27.935917+00	2025-11-27 03:56:27.935917+00	{"eTag": "\\"fc503391d6820756a9b893c9e94cf0d1\\"", "size": 71069, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-27T03:56:28.000Z", "contentLength": 71069, "httpStatusCode": 200}	6315c934-9f83-4b8a-b3d0-f02c081ce678	239cad3e-219d-428f-ac63-fb8b902f4857	{}	2
2382b353-46d8-4cde-9d57-25a7a6d1ab16	evidence	loading_proof/1764522196111.jpg	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	2025-11-30 17:03:17.871288+00	2025-11-30 17:03:17.871288+00	2025-11-30 17:03:17.871288+00	{"eTag": "\\"4a17936776da804286657056326d7543\\"", "size": 122568, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-30T17:03:18.000Z", "contentLength": 122568, "httpStatusCode": 200}	706816ff-6dae-48aa-a53b-a03580b12054	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	{}	2
bf3907bc-fb01-4d3e-86fc-5c1b58c72b6a	evidence	arrival_proof/1764522204366.jpg	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	2025-11-30 17:03:25.854718+00	2025-11-30 17:03:25.854718+00	2025-11-30 17:03:25.854718+00	{"eTag": "\\"8431ac2a43ac9487797047a767632709\\"", "size": 113659, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-30T17:03:26.000Z", "contentLength": 113659, "httpStatusCode": 200}	767a3dec-4db3-4f12-b237-de0dae00c33d	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	{}	2
1adebb2c-9e27-4f34-a87b-0fd1cd15950a	evidence	arrival_proof/1764522267904.jpg	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	2025-11-30 17:04:29.227827+00	2025-11-30 17:04:29.227827+00	2025-11-30 17:04:29.227827+00	{"eTag": "\\"d0e36eb0498a4e2bc83ee74203939742\\"", "size": 115699, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-30T17:04:30.000Z", "contentLength": 115699, "httpStatusCode": 200}	7e09f251-0094-4a55-a79e-187c49f91767	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	{}	2
0ac4e31d-5420-4831-b0b5-f1a5c03201dd	evidence	arrival_proof/1764522331235.jpg	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	2025-11-30 17:05:32.85528+00	2025-11-30 17:05:32.85528+00	2025-11-30 17:05:32.85528+00	{"eTag": "\\"06e8ecf52aec48b78c4a70875940c541\\"", "size": 130029, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-30T17:05:33.000Z", "contentLength": 130029, "httpStatusCode": 200}	859a641e-4e73-45e9-abeb-f072aa7652f5	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	{}	2
e148d286-517f-4c8d-ba55-70101d059e37	evidence	arrival_proof/1764524458370.jpg	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	2025-11-30 17:40:59.592414+00	2025-11-30 17:40:59.592414+00	2025-11-30 17:40:59.592414+00	{"eTag": "\\"c6a70709ea8c6a32849929b5dbe2a86e\\"", "size": 10359, "mimetype": "image/jpeg", "cacheControl": "max-age=3600", "lastModified": "2025-11-30T17:41:00.000Z", "contentLength": 10359, "httpStatusCode": 200}	07d70971-29d2-48f9-9425-876a0d20d9d4	99edd030-5b13-4596-bf3a-d8a94b4cb4c0	{}	2
\.


--
-- Data for Name: prefixes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.prefixes (bucket_id, name, created_at, updated_at) FROM stdin;
evidence	stops	2025-11-27 03:45:25.389118+00	2025-11-27 03:45:25.389118+00
evidence	loading_proof	2025-11-27 03:56:16.99893+00	2025-11-27 03:56:16.99893+00
evidence	arrival_proof	2025-11-27 03:56:27.935917+00	2025-11-27 03:56:27.935917+00
\.


--
-- Data for Name: s3_multipart_uploads; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads (id, in_progress_size, upload_signature, bucket_id, key, version, owner_id, created_at, user_metadata) FROM stdin;
\.


--
-- Data for Name: s3_multipart_uploads_parts; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.s3_multipart_uploads_parts (id, upload_id, size, part_number, bucket_id, key, etag, owner_id, version, created_at) FROM stdin;
\.


--
-- Data for Name: vector_indexes; Type: TABLE DATA; Schema: storage; Owner: -
--

COPY storage.vector_indexes (id, name, bucket_id, data_type, dimension, distance_metric, metadata_configuration, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: secrets; Type: TABLE DATA; Schema: vault; Owner: -
--

COPY vault.secrets (id, name, description, secret, key_id, nonce, created_at, updated_at) FROM stdin;
\.


--
-- Name: refresh_tokens_id_seq; Type: SEQUENCE SET; Schema: auth; Owner: -
--

SELECT pg_catalog.setval('auth.refresh_tokens_id_seq', 323, true);


--
-- Name: subscription_id_seq; Type: SEQUENCE SET; Schema: realtime; Owner: -
--

SELECT pg_catalog.setval('realtime.subscription_id_seq', 1, false);


--
-- Name: mfa_amr_claims amr_id_pk; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT amr_id_pk PRIMARY KEY (id);


--
-- Name: audit_log_entries audit_log_entries_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.audit_log_entries
    ADD CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id);


--
-- Name: flow_state flow_state_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.flow_state
    ADD CONSTRAINT flow_state_pkey PRIMARY KEY (id);


--
-- Name: identities identities_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_pkey PRIMARY KEY (id);


--
-- Name: identities identities_provider_id_provider_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_provider_id_provider_unique UNIQUE (provider_id, provider);


--
-- Name: instances instances_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.instances
    ADD CONSTRAINT instances_pkey PRIMARY KEY (id);


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_authentication_method_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_authentication_method_pkey UNIQUE (session_id, authentication_method);


--
-- Name: mfa_challenges mfa_challenges_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id);


--
-- Name: mfa_factors mfa_factors_last_challenged_at_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_last_challenged_at_key UNIQUE (last_challenged_at);


--
-- Name: mfa_factors mfa_factors_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_pkey PRIMARY KEY (id);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_code_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_code_key UNIQUE (authorization_code);


--
-- Name: oauth_authorizations oauth_authorizations_authorization_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_authorization_id_key UNIQUE (authorization_id);


--
-- Name: oauth_authorizations oauth_authorizations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id);


--
-- Name: oauth_clients oauth_clients_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_clients
    ADD CONSTRAINT oauth_clients_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_pkey PRIMARY KEY (id);


--
-- Name: oauth_consents oauth_consents_user_client_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_client_unique UNIQUE (user_id, client_id);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_unique; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_unique UNIQUE (token);


--
-- Name: saml_providers saml_providers_entity_id_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_entity_id_key UNIQUE (entity_id);


--
-- Name: saml_providers saml_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_pkey PRIMARY KEY (id);


--
-- Name: saml_relay_states saml_relay_states_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: sso_domains sso_domains_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_pkey PRIMARY KEY (id);


--
-- Name: sso_providers sso_providers_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_providers
    ADD CONSTRAINT sso_providers_pkey PRIMARY KEY (id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: change_request_details change_request_details_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_request_details
    ADD CONSTRAINT change_request_details_pkey PRIMARY KEY (id);


--
-- Name: change_requests change_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_requests
    ADD CONSTRAINT change_requests_pkey PRIMARY KEY (id);


--
-- Name: class_receptions class_receptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.class_receptions
    ADD CONSTRAINT class_receptions_pkey PRIMARY KEY (id);


--
-- Name: delivery_routes delivery_routes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_routes
    ADD CONSTRAINT delivery_routes_pkey PRIMARY KEY (id);


--
-- Name: delivery_stops delivery_stops_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_stops
    ADD CONSTRAINT delivery_stops_pkey PRIMARY KEY (id);


--
-- Name: menus menus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menus
    ADD CONSTRAINT menus_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: production_schedules production_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_schedules
    ADD CONSTRAINT production_schedules_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: qc_reports qc_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_reports
    ADD CONSTRAINT qc_reports_pkey PRIMARY KEY (id);


--
-- Name: schools schools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_pkey PRIMARY KEY (id);


--
-- Name: sppgs sppgs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sppgs
    ADD CONSTRAINT sppgs_pkey PRIMARY KEY (id);


--
-- Name: vehicles vehicles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at);


--
-- Name: subscription pk_subscription; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.subscription
    ADD CONSTRAINT pk_subscription PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: realtime; Owner: -
--

ALTER TABLE ONLY realtime.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: buckets_analytics buckets_analytics_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_analytics
    ADD CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id);


--
-- Name: buckets buckets_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets
    ADD CONSTRAINT buckets_pkey PRIMARY KEY (id);


--
-- Name: buckets_vectors buckets_vectors_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.buckets_vectors
    ADD CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id);


--
-- Name: migrations migrations_name_key; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_name_key UNIQUE (name);


--
-- Name: migrations migrations_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.migrations
    ADD CONSTRAINT migrations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: prefixes prefixes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT prefixes_pkey PRIMARY KEY (bucket_id, level, name);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id);


--
-- Name: vector_indexes vector_indexes_pkey; Type: CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_pkey PRIMARY KEY (id);


--
-- Name: audit_logs_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX audit_logs_instance_id_idx ON auth.audit_log_entries USING btree (instance_id);


--
-- Name: confirmation_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX confirmation_token_idx ON auth.users USING btree (confirmation_token) WHERE ((confirmation_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_current_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_current_idx ON auth.users USING btree (email_change_token_current) WHERE ((email_change_token_current)::text !~ '^[0-9 ]*$'::text);


--
-- Name: email_change_token_new_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX email_change_token_new_idx ON auth.users USING btree (email_change_token_new) WHERE ((email_change_token_new)::text !~ '^[0-9 ]*$'::text);


--
-- Name: factor_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX factor_id_created_at_idx ON auth.mfa_factors USING btree (user_id, created_at);


--
-- Name: flow_state_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX flow_state_created_at_idx ON auth.flow_state USING btree (created_at DESC);


--
-- Name: identities_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_email_idx ON auth.identities USING btree (email text_pattern_ops);


--
-- Name: INDEX identities_email_idx; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.identities_email_idx IS 'Auth: Ensures indexed queries on the email column';


--
-- Name: identities_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX identities_user_id_idx ON auth.identities USING btree (user_id);


--
-- Name: idx_auth_code; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_auth_code ON auth.flow_state USING btree (auth_code);


--
-- Name: idx_user_id_auth_method; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_id_auth_method ON auth.flow_state USING btree (user_id, authentication_method);


--
-- Name: mfa_challenge_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_challenge_created_at_idx ON auth.mfa_challenges USING btree (created_at DESC);


--
-- Name: mfa_factors_user_friendly_name_unique; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX mfa_factors_user_friendly_name_unique ON auth.mfa_factors USING btree (friendly_name, user_id) WHERE (TRIM(BOTH FROM friendly_name) <> ''::text);


--
-- Name: mfa_factors_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX mfa_factors_user_id_idx ON auth.mfa_factors USING btree (user_id);


--
-- Name: oauth_auth_pending_exp_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_auth_pending_exp_idx ON auth.oauth_authorizations USING btree (expires_at) WHERE (status = 'pending'::auth.oauth_authorization_status);


--
-- Name: oauth_clients_deleted_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_clients_deleted_at_idx ON auth.oauth_clients USING btree (deleted_at);


--
-- Name: oauth_consents_active_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_client_idx ON auth.oauth_consents USING btree (client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_active_user_client_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_active_user_client_idx ON auth.oauth_consents USING btree (user_id, client_id) WHERE (revoked_at IS NULL);


--
-- Name: oauth_consents_user_order_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX oauth_consents_user_order_idx ON auth.oauth_consents USING btree (user_id, granted_at DESC);


--
-- Name: one_time_tokens_relates_to_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_relates_to_hash_idx ON auth.one_time_tokens USING hash (relates_to);


--
-- Name: one_time_tokens_token_hash_hash_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX one_time_tokens_token_hash_hash_idx ON auth.one_time_tokens USING hash (token_hash);


--
-- Name: one_time_tokens_user_id_token_type_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX one_time_tokens_user_id_token_type_key ON auth.one_time_tokens USING btree (user_id, token_type);


--
-- Name: reauthentication_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX reauthentication_token_idx ON auth.users USING btree (reauthentication_token) WHERE ((reauthentication_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: recovery_token_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX recovery_token_idx ON auth.users USING btree (recovery_token) WHERE ((recovery_token)::text !~ '^[0-9 ]*$'::text);


--
-- Name: refresh_tokens_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_idx ON auth.refresh_tokens USING btree (instance_id);


--
-- Name: refresh_tokens_instance_id_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_instance_id_user_id_idx ON auth.refresh_tokens USING btree (instance_id, user_id);


--
-- Name: refresh_tokens_parent_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_parent_idx ON auth.refresh_tokens USING btree (parent);


--
-- Name: refresh_tokens_session_id_revoked_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_session_id_revoked_idx ON auth.refresh_tokens USING btree (session_id, revoked);


--
-- Name: refresh_tokens_updated_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX refresh_tokens_updated_at_idx ON auth.refresh_tokens USING btree (updated_at DESC);


--
-- Name: saml_providers_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_providers_sso_provider_id_idx ON auth.saml_providers USING btree (sso_provider_id);


--
-- Name: saml_relay_states_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_created_at_idx ON auth.saml_relay_states USING btree (created_at DESC);


--
-- Name: saml_relay_states_for_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_for_email_idx ON auth.saml_relay_states USING btree (for_email);


--
-- Name: saml_relay_states_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX saml_relay_states_sso_provider_id_idx ON auth.saml_relay_states USING btree (sso_provider_id);


--
-- Name: sessions_not_after_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_not_after_idx ON auth.sessions USING btree (not_after DESC);


--
-- Name: sessions_oauth_client_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_oauth_client_id_idx ON auth.sessions USING btree (oauth_client_id);


--
-- Name: sessions_user_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sessions_user_id_idx ON auth.sessions USING btree (user_id);


--
-- Name: sso_domains_domain_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_domains_domain_idx ON auth.sso_domains USING btree (lower(domain));


--
-- Name: sso_domains_sso_provider_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_domains_sso_provider_id_idx ON auth.sso_domains USING btree (sso_provider_id);


--
-- Name: sso_providers_resource_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX sso_providers_resource_id_idx ON auth.sso_providers USING btree (lower(resource_id));


--
-- Name: sso_providers_resource_id_pattern_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX sso_providers_resource_id_pattern_idx ON auth.sso_providers USING btree (resource_id text_pattern_ops);


--
-- Name: unique_phone_factor_per_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX unique_phone_factor_per_user ON auth.mfa_factors USING btree (user_id, phone);


--
-- Name: user_id_created_at_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX user_id_created_at_idx ON auth.sessions USING btree (user_id, created_at);


--
-- Name: users_email_partial_key; Type: INDEX; Schema: auth; Owner: -
--

CREATE UNIQUE INDEX users_email_partial_key ON auth.users USING btree (email) WHERE (is_sso_user = false);


--
-- Name: INDEX users_email_partial_key; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON INDEX auth.users_email_partial_key IS 'Auth: A partial unique index that applies only when is_sso_user is false';


--
-- Name: users_instance_id_email_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_email_idx ON auth.users USING btree (instance_id, lower((email)::text));


--
-- Name: users_instance_id_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_instance_id_idx ON auth.users USING btree (instance_id);


--
-- Name: users_is_anonymous_idx; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX users_is_anonymous_idx ON auth.users USING btree (is_anonymous);


--
-- Name: ix_realtime_subscription_entity; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX ix_realtime_subscription_entity ON realtime.subscription USING btree (entity);


--
-- Name: messages_inserted_at_topic_index; Type: INDEX; Schema: realtime; Owner: -
--

CREATE INDEX messages_inserted_at_topic_index ON ONLY realtime.messages USING btree (inserted_at DESC, topic) WHERE ((extension = 'broadcast'::text) AND (private IS TRUE));


--
-- Name: subscription_subscription_id_entity_filters_key; Type: INDEX; Schema: realtime; Owner: -
--

CREATE UNIQUE INDEX subscription_subscription_id_entity_filters_key ON realtime.subscription USING btree (subscription_id, entity, filters);


--
-- Name: bname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bname ON storage.buckets USING btree (name);


--
-- Name: bucketid_objname; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX bucketid_objname ON storage.objects USING btree (bucket_id, name);


--
-- Name: buckets_analytics_unique_name_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX buckets_analytics_unique_name_idx ON storage.buckets_analytics USING btree (name) WHERE (deleted_at IS NULL);


--
-- Name: idx_multipart_uploads_list; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_multipart_uploads_list ON storage.s3_multipart_uploads USING btree (bucket_id, key, created_at);


--
-- Name: idx_name_bucket_level_unique; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX idx_name_bucket_level_unique ON storage.objects USING btree (name COLLATE "C", bucket_id, level);


--
-- Name: idx_objects_bucket_id_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_bucket_id_name ON storage.objects USING btree (bucket_id, name COLLATE "C");


--
-- Name: idx_objects_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_objects_lower_name ON storage.objects USING btree ((path_tokens[level]), lower(name) text_pattern_ops, bucket_id, level);


--
-- Name: idx_prefixes_lower_name; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX idx_prefixes_lower_name ON storage.prefixes USING btree (bucket_id, level, ((string_to_array(name, '/'::text))[level]), lower(name) text_pattern_ops);


--
-- Name: name_prefix_search; Type: INDEX; Schema: storage; Owner: -
--

CREATE INDEX name_prefix_search ON storage.objects USING btree (name text_pattern_ops);


--
-- Name: objects_bucket_id_level_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX objects_bucket_id_level_idx ON storage.objects USING btree (bucket_id, level, name COLLATE "C");


--
-- Name: vector_indexes_name_bucket_id_idx; Type: INDEX; Schema: storage; Owner: -
--

CREATE UNIQUE INDEX vector_indexes_name_bucket_id_idx ON storage.vector_indexes USING btree (name, bucket_id);


--
-- Name: subscription tr_check_filters; Type: TRIGGER; Schema: realtime; Owner: -
--

CREATE TRIGGER tr_check_filters BEFORE INSERT OR UPDATE ON realtime.subscription FOR EACH ROW EXECUTE FUNCTION realtime.subscription_check_filters();


--
-- Name: buckets enforce_bucket_name_length_trigger; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER enforce_bucket_name_length_trigger BEFORE INSERT OR UPDATE OF name ON storage.buckets FOR EACH ROW EXECUTE FUNCTION storage.enforce_bucket_name_length();


--
-- Name: objects objects_delete_delete_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_delete_delete_prefix AFTER DELETE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects objects_insert_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_insert_create_prefix BEFORE INSERT ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.objects_insert_prefix_trigger();


--
-- Name: objects objects_update_create_prefix; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER objects_update_create_prefix BEFORE UPDATE ON storage.objects FOR EACH ROW WHEN (((new.name <> old.name) OR (new.bucket_id <> old.bucket_id))) EXECUTE FUNCTION storage.objects_update_prefix_trigger();


--
-- Name: prefixes prefixes_create_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_create_hierarchy BEFORE INSERT ON storage.prefixes FOR EACH ROW WHEN ((pg_trigger_depth() < 1)) EXECUTE FUNCTION storage.prefixes_insert_trigger();


--
-- Name: prefixes prefixes_delete_hierarchy; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER prefixes_delete_hierarchy AFTER DELETE ON storage.prefixes FOR EACH ROW EXECUTE FUNCTION storage.delete_prefix_hierarchy_trigger();


--
-- Name: objects update_objects_updated_at; Type: TRIGGER; Schema: storage; Owner: -
--

CREATE TRIGGER update_objects_updated_at BEFORE UPDATE ON storage.objects FOR EACH ROW EXECUTE FUNCTION storage.update_updated_at_column();


--
-- Name: identities identities_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.identities
    ADD CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: mfa_amr_claims mfa_amr_claims_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_amr_claims
    ADD CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: mfa_challenges mfa_challenges_auth_factor_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_challenges
    ADD CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id) ON DELETE CASCADE;


--
-- Name: mfa_factors mfa_factors_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa_factors
    ADD CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_authorizations oauth_authorizations_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_authorizations
    ADD CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: oauth_consents oauth_consents_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.oauth_consents
    ADD CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_session_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.refresh_tokens
    ADD CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id) ON DELETE CASCADE;


--
-- Name: saml_providers saml_providers_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_providers
    ADD CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_flow_state_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id) ON DELETE CASCADE;


--
-- Name: saml_relay_states saml_relay_states_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.saml_relay_states
    ADD CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_oauth_client_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id) ON DELETE CASCADE;


--
-- Name: sessions sessions_user_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sessions
    ADD CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: sso_domains sso_domains_sso_provider_id_fkey; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.sso_domains
    ADD CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id) ON DELETE CASCADE;


--
-- Name: change_request_details change_request_details_menu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_request_details
    ADD CONSTRAINT change_request_details_menu_id_fkey FOREIGN KEY (menu_id) REFERENCES public.menus(id);


--
-- Name: change_request_details change_request_details_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_request_details
    ADD CONSTRAINT change_request_details_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.change_requests(id) ON DELETE CASCADE;


--
-- Name: change_requests change_requests_requester_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_requests
    ADD CONSTRAINT change_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES auth.users(id);


--
-- Name: change_requests change_requests_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_requests
    ADD CONSTRAINT change_requests_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE SET NULL;


--
-- Name: change_requests change_requests_sppg_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.change_requests
    ADD CONSTRAINT change_requests_sppg_id_fkey FOREIGN KEY (sppg_id) REFERENCES public.sppgs(id);


--
-- Name: class_receptions class_receptions_stop_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.class_receptions
    ADD CONSTRAINT class_receptions_stop_id_fkey FOREIGN KEY (stop_id) REFERENCES public.delivery_stops(id);


--
-- Name: class_receptions class_receptions_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.class_receptions
    ADD CONSTRAINT class_receptions_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES auth.users(id);


--
-- Name: delivery_routes delivery_routes_courier_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_routes
    ADD CONSTRAINT delivery_routes_courier_id_fkey FOREIGN KEY (courier_id) REFERENCES public.profiles(id);


--
-- Name: delivery_routes delivery_routes_menu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_routes
    ADD CONSTRAINT delivery_routes_menu_id_fkey FOREIGN KEY (menu_id) REFERENCES public.menus(id);


--
-- Name: delivery_routes delivery_routes_sppg_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_routes
    ADD CONSTRAINT delivery_routes_sppg_id_fkey FOREIGN KEY (sppg_id) REFERENCES public.sppgs(id);


--
-- Name: delivery_routes delivery_routes_vehicle_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_routes
    ADD CONSTRAINT delivery_routes_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicles(id);


--
-- Name: delivery_stops delivery_stops_route_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_stops
    ADD CONSTRAINT delivery_stops_route_id_fkey FOREIGN KEY (route_id) REFERENCES public.delivery_routes(id) ON DELETE CASCADE;


--
-- Name: delivery_stops delivery_stops_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.delivery_stops
    ADD CONSTRAINT delivery_stops_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE CASCADE;


--
-- Name: menus menus_sppg_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menus
    ADD CONSTRAINT menus_sppg_id_fkey FOREIGN KEY (sppg_id) REFERENCES public.sppgs(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id);


--
-- Name: production_schedules production_schedules_menu_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_schedules
    ADD CONSTRAINT production_schedules_menu_id_fkey FOREIGN KEY (menu_id) REFERENCES public.menus(id);


--
-- Name: production_schedules production_schedules_sppg_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.production_schedules
    ADD CONSTRAINT production_schedules_sppg_id_fkey FOREIGN KEY (sppg_id) REFERENCES public.sppgs(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE SET NULL;


--
-- Name: qc_reports qc_reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_reports
    ADD CONSTRAINT qc_reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES auth.users(id);


--
-- Name: qc_reports qc_reports_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.qc_reports
    ADD CONSTRAINT qc_reports_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: schools schools_sppg_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_sppg_id_fkey FOREIGN KEY (sppg_id) REFERENCES public.sppgs(id);


--
-- Name: vehicles vehicles_sppg_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicles
    ADD CONSTRAINT vehicles_sppg_id_fkey FOREIGN KEY (sppg_id) REFERENCES public.sppgs(id);


--
-- Name: objects objects_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.objects
    ADD CONSTRAINT "objects_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: prefixes prefixes_bucketId_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.prefixes
    ADD CONSTRAINT "prefixes_bucketId_fkey" FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads s3_multipart_uploads_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads
    ADD CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id);


--
-- Name: s3_multipart_uploads_parts s3_multipart_uploads_parts_upload_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.s3_multipart_uploads_parts
    ADD CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id) ON DELETE CASCADE;


--
-- Name: vector_indexes vector_indexes_bucket_id_fkey; Type: FK CONSTRAINT; Schema: storage; Owner: -
--

ALTER TABLE ONLY storage.vector_indexes
    ADD CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id);


--
-- Name: audit_log_entries; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.audit_log_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: flow_state; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.flow_state ENABLE ROW LEVEL SECURITY;

--
-- Name: identities; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.identities ENABLE ROW LEVEL SECURITY;

--
-- Name: instances; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.instances ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_amr_claims; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_amr_claims ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_challenges; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: mfa_factors; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.mfa_factors ENABLE ROW LEVEL SECURITY;

--
-- Name: one_time_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.one_time_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: refresh_tokens; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.refresh_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: saml_relay_states; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.saml_relay_states ENABLE ROW LEVEL SECURITY;

--
-- Name: schema_migrations; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.schema_migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: sessions; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sessions ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_domains; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_domains ENABLE ROW LEVEL SECURITY;

--
-- Name: sso_providers; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.sso_providers ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: auth; Owner: -
--

ALTER TABLE auth.users ENABLE ROW LEVEL SECURITY;

--
-- Name: menus Allow All Auth Menus; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Menus" ON public.menus TO authenticated USING (true) WITH CHECK (true);


--
-- Name: profiles Allow All Auth Profiles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Profiles" ON public.profiles TO authenticated USING (true) WITH CHECK (true);


--
-- Name: class_receptions Allow All Auth Receptions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Receptions" ON public.class_receptions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: change_requests Allow All Auth Requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Requests" ON public.change_requests TO authenticated USING (true) WITH CHECK (true);


--
-- Name: delivery_routes Allow All Auth Routes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Routes" ON public.delivery_routes TO authenticated USING (true) WITH CHECK (true);


--
-- Name: production_schedules Allow All Auth Schedules; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Schedules" ON public.production_schedules TO authenticated USING (true) WITH CHECK (true);


--
-- Name: schools Allow All Auth Schools; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Schools" ON public.schools TO authenticated USING (true) WITH CHECK (true);


--
-- Name: delivery_stops Allow All Auth Stops; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Stops" ON public.delivery_stops TO authenticated USING (true) WITH CHECK (true);


--
-- Name: vehicles Allow All Auth Vehicles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow All Auth Vehicles" ON public.vehicles TO authenticated USING (true) WITH CHECK (true);


--
-- Name: change_requests Enable all access for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access for authenticated users" ON public.change_requests TO authenticated USING (true) WITH CHECK (true);


--
-- Name: menus Enable all access for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access for authenticated users" ON public.menus TO authenticated USING (true) WITH CHECK (true);


--
-- Name: vehicles Enable all access for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access for authenticated users" ON public.vehicles TO authenticated USING (true) WITH CHECK (true);


--
-- Name: delivery_routes Enable all access for routes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access for routes" ON public.delivery_routes TO authenticated USING (true) WITH CHECK (true);


--
-- Name: delivery_stops Enable all access for stops; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all access for stops" ON public.delivery_stops TO authenticated USING (true) WITH CHECK (true);


--
-- Name: class_receptions Enable all for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all for authenticated users" ON public.class_receptions TO authenticated USING (true) WITH CHECK (true);


--
-- Name: production_schedules Enable all for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all for authenticated users" ON public.production_schedules TO authenticated USING (true) WITH CHECK (true);


--
-- Name: delivery_routes Enable all for authenticated users on routes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all for authenticated users on routes" ON public.delivery_routes TO authenticated USING (true) WITH CHECK (true);


--
-- Name: schools Enable all for authenticated users on schools; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all for authenticated users on schools" ON public.schools TO authenticated USING (true) WITH CHECK (true);


--
-- Name: delivery_stops Enable all for authenticated users on stops; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all for authenticated users on stops" ON public.delivery_stops TO authenticated USING (true) WITH CHECK (true);


--
-- Name: vehicles Enable all for authenticated users on vehicles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable all for authenticated users on vehicles" ON public.vehicles TO authenticated USING (true) WITH CHECK (true);


--
-- Name: schools Enable delete for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable delete for authenticated users" ON public.schools FOR DELETE TO authenticated USING (true);


--
-- Name: profiles Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable insert for authenticated users" ON public.profiles FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: schools Enable insert for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable insert for authenticated users" ON public.schools FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: sppgs Enable read access for all authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable read access for all authenticated users" ON public.sppgs FOR SELECT TO authenticated USING (true);


--
-- Name: schools Enable select for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable select for authenticated users" ON public.schools FOR SELECT TO authenticated USING (true);


--
-- Name: profiles Enable update for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable update for authenticated users" ON public.profiles FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: schools Enable update for authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable update for authenticated users" ON public.schools FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: sppgs Enable write access for all authenticated users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Enable write access for all authenticated users" ON public.sppgs TO authenticated USING (true) WITH CHECK (true);


--
-- Name: profiles Public profiles are viewable by everyone.; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);


--
-- Name: profiles Public profiles view; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public profiles view" ON public.profiles FOR SELECT USING (true);


--
-- Name: notifications Send notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Send notifications" ON public.notifications FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: notifications Update own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Update own notifications" ON public.notifications FOR UPDATE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: notifications View own notifications; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "View own notifications" ON public.notifications FOR SELECT TO authenticated USING ((auth.uid() = user_id));


--
-- Name: change_request_details; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.change_request_details ENABLE ROW LEVEL SECURITY;

--
-- Name: change_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.change_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: class_receptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.class_receptions ENABLE ROW LEVEL SECURITY;

--
-- Name: delivery_routes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.delivery_routes ENABLE ROW LEVEL SECURITY;

--
-- Name: delivery_stops; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.delivery_stops ENABLE ROW LEVEL SECURITY;

--
-- Name: menus; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.menus ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: production_schedules; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.production_schedules ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: qc_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.qc_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: schools; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

--
-- Name: sppgs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sppgs ENABLE ROW LEVEL SECURITY;

--
-- Name: vehicles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;

--
-- Name: messages; Type: ROW SECURITY; Schema: realtime; Owner: -
--

ALTER TABLE realtime.messages ENABLE ROW LEVEL SECURITY;

--
-- Name: objects Allow Upload Evidence; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Allow Upload Evidence" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'evidence'::text));


--
-- Name: objects Allow View Evidence; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Allow View Evidence" ON storage.objects FOR SELECT USING ((bucket_id = 'evidence'::text));


--
-- Name: objects Allow authenticated uploads; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Allow authenticated uploads" ON storage.objects FOR INSERT TO authenticated WITH CHECK ((bucket_id = 'evidence'::text));


--
-- Name: objects Allow public viewing; Type: POLICY; Schema: storage; Owner: -
--

CREATE POLICY "Allow public viewing" ON storage.objects FOR SELECT USING ((bucket_id = 'evidence'::text));


--
-- Name: buckets; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_analytics; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_analytics ENABLE ROW LEVEL SECURITY;

--
-- Name: buckets_vectors; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.buckets_vectors ENABLE ROW LEVEL SECURITY;

--
-- Name: migrations; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.migrations ENABLE ROW LEVEL SECURITY;

--
-- Name: objects; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: prefixes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.prefixes ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads ENABLE ROW LEVEL SECURITY;

--
-- Name: s3_multipart_uploads_parts; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.s3_multipart_uploads_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: vector_indexes; Type: ROW SECURITY; Schema: storage; Owner: -
--

ALTER TABLE storage.vector_indexes ENABLE ROW LEVEL SECURITY;

--
-- Name: supabase_realtime; Type: PUBLICATION; Schema: -; Owner: -
--

CREATE PUBLICATION supabase_realtime WITH (publish = 'insert, update, delete, truncate');


--
-- Name: issue_graphql_placeholder; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_graphql_placeholder ON sql_drop
         WHEN TAG IN ('DROP EXTENSION')
   EXECUTE FUNCTION extensions.set_graphql_placeholder();


--
-- Name: issue_pg_cron_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_cron_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_cron_access();


--
-- Name: issue_pg_graphql_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_graphql_access ON ddl_command_end
         WHEN TAG IN ('CREATE FUNCTION')
   EXECUTE FUNCTION extensions.grant_pg_graphql_access();


--
-- Name: issue_pg_net_access; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER issue_pg_net_access ON ddl_command_end
         WHEN TAG IN ('CREATE EXTENSION')
   EXECUTE FUNCTION extensions.grant_pg_net_access();


--
-- Name: pgrst_ddl_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_ddl_watch ON ddl_command_end
   EXECUTE FUNCTION extensions.pgrst_ddl_watch();


--
-- Name: pgrst_drop_watch; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER pgrst_drop_watch ON sql_drop
   EXECUTE FUNCTION extensions.pgrst_drop_watch();


--
-- PostgreSQL database dump complete
--

\unrestrict rTvgH2GGhohk2mjPnlhXahepc7DflZtUWV6b2Sv4lXd7rkmegicR9HYqNqHk7qo

