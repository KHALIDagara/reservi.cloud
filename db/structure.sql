SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.account_invitations (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    email character varying NOT NULL,
    role character varying DEFAULT 'operator'::character varying NOT NULL,
    team_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    inviter_membership_id bigint NOT NULL,
    token_digest character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    delivery_status character varying DEFAULT 'pending'::character varying NOT NULL,
    delivery_attempts integer DEFAULT 0 NOT NULL,
    delivery_token character varying,
    accepted_by_membership_id bigint,
    accepted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT account_invitations_delivery_status_check CHECK (((delivery_status)::text = ANY ((ARRAY['pending'::character varying, 'delivered'::character varying, 'failed'::character varying, 'unknown'::character varying])::text[]))),
    CONSTRAINT account_invitations_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'manager'::character varying, 'operator'::character varying])::text[]))),
    CONSTRAINT account_invitations_status_check CHECK (((status)::text = ANY ((ARRAY['pending'::character varying, 'accepted'::character varying, 'revoked'::character varying])::text[])))
);


--
-- Name: account_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.account_invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: account_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.account_invitations_id_seq OWNED BY public.account_invitations.id;


--
-- Name: accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.accounts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    locale character varying DEFAULT 'en'::character varying NOT NULL,
    timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    active boolean DEFAULT true NOT NULL,
    creation_operation_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    guidance_generation integer DEFAULT 0 NOT NULL,
    knowledge_generation integer DEFAULT 0 NOT NULL,
    access_generation integer DEFAULT 0 NOT NULL,
    admission_counter integer DEFAULT 0 NOT NULL
);


--
-- Name: accounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.accounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: accounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.accounts_id_seq OWNED BY public.accounts.id;


--
-- Name: agent_configurations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_configurations (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    version_number integer NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    role text,
    guidance_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    capability_config jsonb DEFAULT '{}'::jsonb NOT NULL,
    provider_type character varying,
    model_identifier character varying,
    budget_limit_cents integer,
    max_concurrent_runs integer DEFAULT 1 NOT NULL,
    published_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT agent_configurations_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying])::text[])))
);


--
-- Name: agent_configurations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_configurations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_configurations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_configurations_id_seq OWNED BY public.agent_configurations.id;


--
-- Name: agent_knowledge_grants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_knowledge_grants (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    knowledge_source_id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: agent_knowledge_grants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_knowledge_grants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_knowledge_grants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_knowledge_grants_id_seq OWNED BY public.agent_knowledge_grants.id;


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    kind character varying DEFAULT 'human'::character varying NOT NULL,
    membership_id bigint,
    name character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    capabilities jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    operational_status character varying DEFAULT 'draft'::character varying NOT NULL,
    agent_configuration_id bigint,
    CONSTRAINT agents_kind_check CHECK (((kind)::text = ANY ((ARRAY['human'::character varying, 'ai'::character varying])::text[]))),
    CONSTRAINT agents_kind_membership_check CHECK (((((kind)::text = 'human'::text) AND (membership_id IS NOT NULL)) OR (((kind)::text = 'ai'::text) AND (membership_id IS NULL)))),
    CONSTRAINT agents_operational_status_check CHECK (((operational_status)::text = ANY ((ARRAY['draft'::character varying, 'active'::character varying, 'paused'::character varying, 'archived'::character varying])::text[])))
);


--
-- Name: agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agents_id_seq OWNED BY public.agents.id;


--
-- Name: ai_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_runs (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    agent_configuration_id bigint NOT NULL,
    status character varying DEFAULT 'admitted'::character varying NOT NULL,
    trigger character varying NOT NULL,
    admission_token character varying NOT NULL,
    budget_reservation_cents integer,
    conversation_revision integer DEFAULT 0 NOT NULL,
    usage_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    started_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    failed_at timestamp(6) without time zone,
    failure_reason text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT ai_runs_status_check CHECK (((status)::text = ANY ((ARRAY['admitted'::character varying, 'evaluating'::character varying, 'completed'::character varying, 'failed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: ai_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ai_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ai_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ai_runs_id_seq OWNED BY public.ai_runs.id;


--
-- Name: appointments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.appointments (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    role_key character varying NOT NULL,
    scheduled_agent_id bigint,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    duration_minutes integer,
    timezone character varying DEFAULT 'UTC'::character varying NOT NULL,
    purpose text,
    cancellation_reason character varying,
    cancelled_at timestamp(6) without time zone,
    completed_at timestamp(6) without time zone,
    superseded_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: appointments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.appointments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: appointments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.appointments_id_seq OWNED BY public.appointments.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: catalogs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalogs (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    title character varying NOT NULL,
    item_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: catalogs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.catalogs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: catalogs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.catalogs_id_seq OWNED BY public.catalogs.id;


--
-- Name: channel_threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channel_threads (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    external_thread_id character varying NOT NULL,
    external_contact_id character varying,
    external_contact_name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: channel_threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channel_threads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channel_threads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channel_threads_id_seq OWNED BY public.channel_threads.id;


--
-- Name: channels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.channels (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    name character varying NOT NULL,
    provider_type character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    inbound_token character varying NOT NULL,
    default_team_name character varying,
    rate_limit_per_minute integer DEFAULT 10,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: channels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.channels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: channels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.channels_id_seq OWNED BY public.channels.id;


--
-- Name: conversation_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation_reads (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    last_read_message_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: conversation_reads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversation_reads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversation_reads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversation_reads_id_seq OWNED BY public.conversation_reads.id;


--
-- Name: conversations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversations (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    customer_id bigint NOT NULL,
    flow_version_id bigint NOT NULL,
    current_stage_id bigint NOT NULL,
    process_status character varying DEFAULT 'active'::character varying NOT NULL,
    owner_id bigint,
    team_id bigint,
    attention boolean DEFAULT false NOT NULL,
    first_attention_at timestamp(6) without time zone,
    last_activity_at timestamp(6) without time zone,
    custom_values jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    revision integer DEFAULT 0 NOT NULL
);


--
-- Name: conversations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.conversations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: conversations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.conversations_id_seq OWNED BY public.conversations.id;


--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    phone character varying,
    email_address character varying,
    locale character varying DEFAULT 'en'::character varying,
    custom_values jsonb DEFAULT '{}'::jsonb NOT NULL,
    profile_revision integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: customers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customers_id_seq OWNED BY public.customers.id;


--
-- Name: field_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.field_definitions (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    scope character varying NOT NULL,
    key character varying NOT NULL,
    label character varying DEFAULT ''::character varying NOT NULL,
    field_type character varying NOT NULL,
    options jsonb DEFAULT '[]'::jsonb NOT NULL,
    constraints jsonb DEFAULT '{}'::jsonb NOT NULL,
    built_in_binding character varying,
    "position" integer DEFAULT 0 NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT field_definitions_scope_check CHECK (((scope)::text = ANY ((ARRAY['customer'::character varying, 'conversation'::character varying])::text[]))),
    CONSTRAINT field_definitions_type_check CHECK (((field_type)::text = ANY ((ARRAY['text'::character varying, 'number'::character varying, 'boolean'::character varying, 'single_choice'::character varying, 'multi_choice'::character varying, 'date'::character varying])::text[])))
);


--
-- Name: field_definitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.field_definitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: field_definitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.field_definitions_id_seq OWNED BY public.field_definitions.id;


--
-- Name: flow_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flow_versions (
    id bigint NOT NULL,
    flow_id bigint NOT NULL,
    version_number integer NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    published_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: flow_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flow_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flow_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flow_versions_id_seq OWNED BY public.flow_versions.id;


--
-- Name: flows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flows (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    name character varying NOT NULL,
    current_version_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: flows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flows_id_seq OWNED BY public.flows.id;


--
-- Name: item_selections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.item_selections (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    account_id bigint NOT NULL,
    catalog_id bigint NOT NULL,
    item_id bigint NOT NULL,
    role_key character varying NOT NULL,
    ordinal integer,
    snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: item_selections_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.item_selections_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: item_selections_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.item_selections_id_seq OWNED BY public.item_selections.id;


--
-- Name: items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.items (
    id bigint NOT NULL,
    catalog_id bigint NOT NULL,
    account_id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    price numeric(12,2),
    currency character varying DEFAULT 'USD'::character varying NOT NULL,
    unit character varying,
    attributes_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.items_id_seq OWNED BY public.items.id;


--
-- Name: knowledge_revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.knowledge_revisions (
    id bigint NOT NULL,
    knowledge_source_id bigint NOT NULL,
    version_number integer NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    content_json jsonb DEFAULT '{}'::jsonb NOT NULL,
    raw_text text,
    published_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT knowledge_revisions_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'published'::character varying])::text[])))
);


--
-- Name: knowledge_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.knowledge_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: knowledge_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.knowledge_revisions_id_seq OWNED BY public.knowledge_revisions.id;


--
-- Name: knowledge_sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.knowledge_sources (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    title character varying NOT NULL,
    kind character varying NOT NULL,
    shared boolean DEFAULT true NOT NULL,
    current_revision_id bigint,
    archived boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT knowledge_sources_kind_check CHECK (((kind)::text = ANY ((ARRAY['qa'::character varying, 'document'::character varying, 'scenario'::character varying])::text[])))
);


--
-- Name: knowledge_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.knowledge_sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: knowledge_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.knowledge_sources_id_seq OWNED BY public.knowledge_sources.id;


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role character varying DEFAULT 'operator'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT memberships_role_check CHECK (((role)::text = ANY ((ARRAY['admin'::character varying, 'manager'::character varying, 'operator'::character varying])::text[])))
);


--
-- Name: memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.memberships_id_seq OWNED BY public.memberships.id;


--
-- Name: message_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_deliveries (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    channel_id bigint NOT NULL,
    message_id bigint NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    operation_key character varying NOT NULL,
    provider_message_id character varying,
    error_message text,
    retry_count integer DEFAULT 0 NOT NULL,
    last_attempt_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: message_deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.message_deliveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: message_deliveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.message_deliveries_id_seq OWNED BY public.message_deliveries.id;


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    agent_id bigint,
    author_name character varying DEFAULT ''::character varying NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    direction character varying DEFAULT 'inbound'::character varying NOT NULL,
    delivery_status character varying DEFAULT 'local'::character varying NOT NULL,
    operation_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.messages_id_seq OWNED BY public.messages.id;


--
-- Name: notes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notes (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    content text DEFAULT ''::text NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notes_id_seq OWNED BY public.notes.id;


--
-- Name: rule_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rule_executions (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    stage_id bigint NOT NULL,
    rule_key character varying NOT NULL,
    execution_key character varying NOT NULL,
    predicate_result boolean NOT NULL,
    status character varying DEFAULT 'evaluated'::character varying NOT NULL,
    actions_executed jsonb DEFAULT '[]'::jsonb NOT NULL,
    error_message text,
    explanation text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: rule_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.rule_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: rule_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.rule_executions_id_seq OWNED BY public.rule_executions.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: stage_transitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stage_transitions (
    id bigint NOT NULL,
    conversation_id bigint NOT NULL,
    from_stage_id bigint NOT NULL,
    to_stage_id bigint,
    entry_identity character varying NOT NULL,
    reason character varying,
    input_revisions jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stage_transitions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stage_transitions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stage_transitions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stage_transitions_id_seq OWNED BY public.stage_transitions.id;


--
-- Name: stages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stages (
    id bigint NOT NULL,
    flow_version_id bigint NOT NULL,
    key character varying NOT NULL,
    label character varying NOT NULL,
    "position" integer NOT NULL,
    blocks jsonb DEFAULT '[]'::jsonb NOT NULL,
    rules jsonb DEFAULT '[]'::jsonb NOT NULL,
    completion jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stages_id_seq OWNED BY public.stages.id;


--
-- Name: team_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_memberships (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    team_id bigint NOT NULL,
    agent_id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: team_memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.team_memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: team_memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.team_memberships_id_seq OWNED BY public.team_memberships.id;


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id bigint NOT NULL,
    account_id bigint NOT NULL,
    name character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying DEFAULT ''::character varying NOT NULL,
    verified_at timestamp(6) without time zone,
    verification_token_digest character varying,
    verification_delivery_token character varying
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: account_invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_invitations ALTER COLUMN id SET DEFAULT nextval('public.account_invitations_id_seq'::regclass);


--
-- Name: accounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts ALTER COLUMN id SET DEFAULT nextval('public.accounts_id_seq'::regclass);


--
-- Name: agent_configurations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_configurations ALTER COLUMN id SET DEFAULT nextval('public.agent_configurations_id_seq'::regclass);


--
-- Name: agent_knowledge_grants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_knowledge_grants ALTER COLUMN id SET DEFAULT nextval('public.agent_knowledge_grants_id_seq'::regclass);


--
-- Name: agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents ALTER COLUMN id SET DEFAULT nextval('public.agents_id_seq'::regclass);


--
-- Name: ai_runs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_runs ALTER COLUMN id SET DEFAULT nextval('public.ai_runs_id_seq'::regclass);


--
-- Name: appointments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments ALTER COLUMN id SET DEFAULT nextval('public.appointments_id_seq'::regclass);


--
-- Name: catalogs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogs ALTER COLUMN id SET DEFAULT nextval('public.catalogs_id_seq'::regclass);


--
-- Name: channel_threads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_threads ALTER COLUMN id SET DEFAULT nextval('public.channel_threads_id_seq'::regclass);


--
-- Name: channels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels ALTER COLUMN id SET DEFAULT nextval('public.channels_id_seq'::regclass);


--
-- Name: conversation_reads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads ALTER COLUMN id SET DEFAULT nextval('public.conversation_reads_id_seq'::regclass);


--
-- Name: conversations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations ALTER COLUMN id SET DEFAULT nextval('public.conversations_id_seq'::regclass);


--
-- Name: customers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers ALTER COLUMN id SET DEFAULT nextval('public.customers_id_seq'::regclass);


--
-- Name: field_definitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_definitions ALTER COLUMN id SET DEFAULT nextval('public.field_definitions_id_seq'::regclass);


--
-- Name: flow_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_versions ALTER COLUMN id SET DEFAULT nextval('public.flow_versions_id_seq'::regclass);


--
-- Name: flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flows ALTER COLUMN id SET DEFAULT nextval('public.flows_id_seq'::regclass);


--
-- Name: item_selections id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_selections ALTER COLUMN id SET DEFAULT nextval('public.item_selections_id_seq'::regclass);


--
-- Name: items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items ALTER COLUMN id SET DEFAULT nextval('public.items_id_seq'::regclass);


--
-- Name: knowledge_revisions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_revisions ALTER COLUMN id SET DEFAULT nextval('public.knowledge_revisions_id_seq'::regclass);


--
-- Name: knowledge_sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_sources ALTER COLUMN id SET DEFAULT nextval('public.knowledge_sources_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships ALTER COLUMN id SET DEFAULT nextval('public.memberships_id_seq'::regclass);


--
-- Name: message_deliveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_deliveries ALTER COLUMN id SET DEFAULT nextval('public.message_deliveries_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: rule_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions ALTER COLUMN id SET DEFAULT nextval('public.rule_executions_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: stage_transitions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_transitions ALTER COLUMN id SET DEFAULT nextval('public.stage_transitions_id_seq'::regclass);


--
-- Name: stages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stages ALTER COLUMN id SET DEFAULT nextval('public.stages_id_seq'::regclass);


--
-- Name: team_memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships ALTER COLUMN id SET DEFAULT nextval('public.team_memberships_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: account_invitations account_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_invitations
    ADD CONSTRAINT account_invitations_pkey PRIMARY KEY (id);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: agent_configurations agent_configurations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_configurations
    ADD CONSTRAINT agent_configurations_pkey PRIMARY KEY (id);


--
-- Name: agent_knowledge_grants agent_knowledge_grants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_knowledge_grants
    ADD CONSTRAINT agent_knowledge_grants_pkey PRIMARY KEY (id);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: ai_runs ai_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_runs
    ADD CONSTRAINT ai_runs_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: catalogs catalogs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogs
    ADD CONSTRAINT catalogs_pkey PRIMARY KEY (id);


--
-- Name: channel_threads channel_threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_threads
    ADD CONSTRAINT channel_threads_pkey PRIMARY KEY (id);


--
-- Name: channels channels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT channels_pkey PRIMARY KEY (id);


--
-- Name: conversation_reads conversation_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT conversation_reads_pkey PRIMARY KEY (id);


--
-- Name: conversations conversations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT conversations_pkey PRIMARY KEY (id);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (id);


--
-- Name: field_definitions field_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_definitions
    ADD CONSTRAINT field_definitions_pkey PRIMARY KEY (id);


--
-- Name: flow_versions flow_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_versions
    ADD CONSTRAINT flow_versions_pkey PRIMARY KEY (id);


--
-- Name: flows flows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flows
    ADD CONSTRAINT flows_pkey PRIMARY KEY (id);


--
-- Name: item_selections item_selections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_selections
    ADD CONSTRAINT item_selections_pkey PRIMARY KEY (id);


--
-- Name: items items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT items_pkey PRIMARY KEY (id);


--
-- Name: knowledge_revisions knowledge_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_revisions
    ADD CONSTRAINT knowledge_revisions_pkey PRIMARY KEY (id);


--
-- Name: knowledge_sources knowledge_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_sources
    ADD CONSTRAINT knowledge_sources_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: message_deliveries message_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_deliveries
    ADD CONSTRAINT message_deliveries_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: appointments no_overlapping_confirmed_appointments; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT no_overlapping_confirmed_appointments EXCLUDE USING gist (account_id WITH =, scheduled_agent_id WITH =, tsrange(starts_at, ends_at, '[)'::text) WITH &&) WHERE (((scheduled_agent_id IS NOT NULL) AND ((status)::text = 'confirmed'::text)));


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


--
-- Name: rule_executions rule_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT rule_executions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: stage_transitions stage_transitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_transitions
    ADD CONSTRAINT stage_transitions_pkey PRIMARY KEY (id);


--
-- Name: stages stages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT stages_pkey PRIMARY KEY (id);


--
-- Name: team_memberships team_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT team_memberships_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_agent_configurations_agent_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agent_configurations_agent_status ON public.agent_configurations USING btree (agent_id, status);


--
-- Name: idx_agent_configurations_agent_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_configurations_agent_version ON public.agent_configurations USING btree (agent_id, version_number);


--
-- Name: idx_agent_knowledge_grants_agent_source; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_agent_knowledge_grants_agent_source ON public.agent_knowledge_grants USING btree (agent_id, knowledge_source_id);


--
-- Name: idx_agents_on_account_and_agent_config; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_agents_on_account_and_agent_config ON public.agents USING btree (account_id, agent_configuration_id);


--
-- Name: idx_ai_runs_admission_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ai_runs_admission_token ON public.ai_runs USING btree (admission_token);


--
-- Name: idx_ai_runs_agent_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_runs_agent_status ON public.ai_runs USING btree (agent_id, status);


--
-- Name: idx_ai_runs_conversation_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_runs_conversation_status ON public.ai_runs USING btree (conversation_id, status);


--
-- Name: idx_appointments_account_scheduled_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_appointments_account_scheduled_agent ON public.appointments USING btree (account_id, scheduled_agent_id);


--
-- Name: idx_channel_threads_on_account_conversation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_channel_threads_on_account_conversation ON public.channel_threads USING btree (account_id, conversation_id);


--
-- Name: idx_channel_threads_on_channel_and_thread; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_channel_threads_on_channel_and_thread ON public.channel_threads USING btree (channel_id, external_thread_id);


--
-- Name: idx_current_appointment_per_role; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_current_appointment_per_role ON public.appointments USING btree (conversation_id, role_key) WHERE (superseded_by_id IS NULL);


--
-- Name: idx_deliveries_on_account_message; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_deliveries_on_account_message ON public.message_deliveries USING btree (account_id, message_id);


--
-- Name: idx_deliveries_on_channel_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_deliveries_on_channel_status ON public.message_deliveries USING btree (channel_id, status);


--
-- Name: idx_item_selections_on_conversation_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_item_selections_on_conversation_role ON public.item_selections USING btree (conversation_id, role_key);


--
-- Name: idx_item_selections_on_conversation_role_item; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_item_selections_on_conversation_role_item ON public.item_selections USING btree (conversation_id, role_key, item_id);


--
-- Name: idx_knowledge_revisions_source_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_knowledge_revisions_source_version ON public.knowledge_revisions USING btree (knowledge_source_id, version_number);


--
-- Name: idx_knowledge_sources_account_title_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_knowledge_sources_account_title_active ON public.knowledge_sources USING btree (account_id, title) WHERE (archived = false);


--
-- Name: idx_knowledge_sources_current_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_knowledge_sources_current_revision ON public.knowledge_sources USING btree (current_revision_id);


--
-- Name: idx_rule_execs_on_conversation_stage_rule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rule_execs_on_conversation_stage_rule ON public.rule_executions USING btree (conversation_id, stage_id, rule_key);


--
-- Name: index_account_invitations_delivery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_invitations_delivery ON public.account_invitations USING btree (status, delivery_status);


--
-- Name: index_account_invitations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_invitations_on_account_id ON public.account_invitations USING btree (account_id);


--
-- Name: index_account_invitations_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_invitations_on_account_id_and_id ON public.account_invitations USING btree (account_id, id);


--
-- Name: index_account_invitations_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_account_invitations_on_email ON public.account_invitations USING btree (email);


--
-- Name: index_account_invitations_one_pending_per_account_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_account_invitations_one_pending_per_account_email ON public.account_invitations USING btree (account_id, email) WHERE ((status)::text = 'pending'::text);


--
-- Name: index_accounts_on_creation_operation_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_accounts_on_creation_operation_key ON public.accounts USING btree (creation_operation_key);


--
-- Name: index_agent_configurations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_configurations_on_account_id ON public.agent_configurations USING btree (account_id);


--
-- Name: index_agent_configurations_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_configurations_on_agent_id ON public.agent_configurations USING btree (agent_id);


--
-- Name: index_agent_knowledge_grants_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_knowledge_grants_on_account_id ON public.agent_knowledge_grants USING btree (account_id);


--
-- Name: index_agent_knowledge_grants_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_knowledge_grants_on_agent_id ON public.agent_knowledge_grants USING btree (agent_id);


--
-- Name: index_agent_knowledge_grants_on_knowledge_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_knowledge_grants_on_knowledge_source_id ON public.agent_knowledge_grants USING btree (knowledge_source_id);


--
-- Name: index_agents_on_account_and_membership_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agents_on_account_and_membership_unique ON public.agents USING btree (account_id, membership_id) WHERE (membership_id IS NOT NULL);


--
-- Name: index_agents_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agents_on_account_id ON public.agents USING btree (account_id);


--
-- Name: index_agents_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agents_on_account_id_and_id ON public.agents USING btree (account_id, id);


--
-- Name: index_agents_on_membership_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agents_on_membership_id ON public.agents USING btree (membership_id);


--
-- Name: index_ai_runs_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_runs_on_account_id ON public.ai_runs USING btree (account_id);


--
-- Name: index_ai_runs_on_agent_configuration_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_runs_on_agent_configuration_id ON public.ai_runs USING btree (agent_configuration_id);


--
-- Name: index_ai_runs_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_runs_on_agent_id ON public.ai_runs USING btree (agent_id);


--
-- Name: index_ai_runs_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ai_runs_on_conversation_id ON public.ai_runs USING btree (conversation_id);


--
-- Name: index_appointments_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_account_id ON public.appointments USING btree (account_id);


--
-- Name: index_appointments_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_conversation_id ON public.appointments USING btree (conversation_id);


--
-- Name: index_appointments_on_scheduled_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_appointments_on_scheduled_agent_id ON public.appointments USING btree (scheduled_agent_id);


--
-- Name: index_catalogs_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_catalogs_on_account_id ON public.catalogs USING btree (account_id);


--
-- Name: index_catalogs_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_catalogs_on_account_id_and_id ON public.catalogs USING btree (account_id, id);


--
-- Name: index_catalogs_on_account_id_and_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_catalogs_on_account_id_and_title ON public.catalogs USING btree (account_id, title);


--
-- Name: index_channel_threads_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channel_threads_on_account_id ON public.channel_threads USING btree (account_id);


--
-- Name: index_channel_threads_on_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channel_threads_on_channel_id ON public.channel_threads USING btree (channel_id);


--
-- Name: index_channel_threads_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channel_threads_on_conversation_id ON public.channel_threads USING btree (conversation_id);


--
-- Name: index_channels_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_channels_on_account_id ON public.channels USING btree (account_id);


--
-- Name: index_channels_on_account_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_channels_on_account_id_and_name ON public.channels USING btree (account_id, name);


--
-- Name: index_channels_on_inbound_token; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_channels_on_inbound_token ON public.channels USING btree (inbound_token);


--
-- Name: index_conversation_reads_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversation_reads_on_agent_id ON public.conversation_reads USING btree (agent_id);


--
-- Name: index_conversation_reads_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversation_reads_on_conversation_id ON public.conversation_reads USING btree (conversation_id);


--
-- Name: index_conversation_reads_on_conversation_id_and_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_conversation_reads_on_conversation_id_and_agent_id ON public.conversation_reads USING btree (conversation_id, agent_id);


--
-- Name: index_conversations_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_account_id ON public.conversations USING btree (account_id);


--
-- Name: index_conversations_on_account_id_and_attention; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_account_id_and_attention ON public.conversations USING btree (account_id, attention);


--
-- Name: index_conversations_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_conversations_on_account_id_and_id ON public.conversations USING btree (account_id, id);


--
-- Name: index_conversations_on_account_id_and_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_account_id_and_owner_id ON public.conversations USING btree (account_id, owner_id);


--
-- Name: index_conversations_on_account_id_and_process_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_account_id_and_process_status ON public.conversations USING btree (account_id, process_status);


--
-- Name: index_conversations_on_account_id_and_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_account_id_and_team_id ON public.conversations USING btree (account_id, team_id);


--
-- Name: index_conversations_on_customer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_customer_id ON public.conversations USING btree (customer_id);


--
-- Name: index_conversations_on_flow_version_id_and_current_stage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_conversations_on_flow_version_id_and_current_stage_id ON public.conversations USING btree (flow_version_id, current_stage_id);


--
-- Name: index_customers_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_customers_on_account_id ON public.customers USING btree (account_id);


--
-- Name: index_customers_on_account_id_and_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customers_on_account_id_and_email_address ON public.customers USING btree (account_id, email_address) WHERE (email_address IS NOT NULL);


--
-- Name: index_customers_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_customers_on_account_id_and_id ON public.customers USING btree (account_id, id);


--
-- Name: index_field_definitions_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_field_definitions_on_account_id ON public.field_definitions USING btree (account_id);


--
-- Name: index_field_definitions_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_field_definitions_on_account_id_and_id ON public.field_definitions USING btree (account_id, id);


--
-- Name: index_field_definitions_on_account_id_and_scope_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_field_definitions_on_account_id_and_scope_and_key ON public.field_definitions USING btree (account_id, scope, key);


--
-- Name: index_field_definitions_on_account_id_and_scope_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_field_definitions_on_account_id_and_scope_and_position ON public.field_definitions USING btree (account_id, scope, "position");


--
-- Name: index_flow_versions_on_flow_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flow_versions_on_flow_id ON public.flow_versions USING btree (flow_id);


--
-- Name: index_flow_versions_on_flow_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flow_versions_on_flow_id_and_id ON public.flow_versions USING btree (flow_id, id);


--
-- Name: index_flow_versions_on_flow_id_and_version_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flow_versions_on_flow_id_and_version_number ON public.flow_versions USING btree (flow_id, version_number);


--
-- Name: index_flows_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flows_on_account_id ON public.flows USING btree (account_id);


--
-- Name: index_flows_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flows_on_account_id_and_id ON public.flows USING btree (account_id, id);


--
-- Name: index_flows_on_account_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flows_on_account_id_and_name ON public.flows USING btree (account_id, name);


--
-- Name: index_flows_on_current_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flows_on_current_version_id ON public.flows USING btree (current_version_id) WHERE (current_version_id IS NOT NULL);


--
-- Name: index_item_selections_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_selections_on_account_id ON public.item_selections USING btree (account_id);


--
-- Name: index_item_selections_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_item_selections_on_account_id_and_id ON public.item_selections USING btree (account_id, id);


--
-- Name: index_item_selections_on_catalog_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_selections_on_catalog_id ON public.item_selections USING btree (catalog_id);


--
-- Name: index_item_selections_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_selections_on_conversation_id ON public.item_selections USING btree (conversation_id);


--
-- Name: index_item_selections_on_item_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_item_selections_on_item_id ON public.item_selections USING btree (item_id);


--
-- Name: index_items_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_account_id ON public.items USING btree (account_id);


--
-- Name: index_items_on_account_id_and_catalog_id_and_title; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_items_on_account_id_and_catalog_id_and_title ON public.items USING btree (account_id, catalog_id, title);


--
-- Name: index_items_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_items_on_account_id_and_id ON public.items USING btree (account_id, id);


--
-- Name: index_items_on_catalog_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_items_on_catalog_id ON public.items USING btree (catalog_id);


--
-- Name: index_items_on_catalog_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_items_on_catalog_id_and_id ON public.items USING btree (catalog_id, id);


--
-- Name: index_knowledge_revisions_on_knowledge_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_knowledge_revisions_on_knowledge_source_id ON public.knowledge_revisions USING btree (knowledge_source_id);


--
-- Name: index_knowledge_sources_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_knowledge_sources_on_account_id ON public.knowledge_sources USING btree (account_id);


--
-- Name: index_memberships_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_account_id ON public.memberships USING btree (account_id);


--
-- Name: index_memberships_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_account_id_and_id ON public.memberships USING btree (account_id, id);


--
-- Name: index_memberships_on_account_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_account_id_and_user_id ON public.memberships USING btree (account_id, user_id);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_message_deliveries_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_message_deliveries_on_account_id ON public.message_deliveries USING btree (account_id);


--
-- Name: index_message_deliveries_on_channel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_message_deliveries_on_channel_id ON public.message_deliveries USING btree (channel_id);


--
-- Name: index_message_deliveries_on_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_message_deliveries_on_message_id ON public.message_deliveries USING btree (message_id);


--
-- Name: index_message_deliveries_on_operation_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_message_deliveries_on_operation_key ON public.message_deliveries USING btree (operation_key);


--
-- Name: index_messages_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_agent_id ON public.messages USING btree (agent_id);


--
-- Name: index_messages_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_conversation_id ON public.messages USING btree (conversation_id);


--
-- Name: index_messages_on_conversation_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_conversation_id_and_created_at ON public.messages USING btree (conversation_id, created_at);


--
-- Name: index_messages_on_conversation_id_and_direction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_messages_on_conversation_id_and_direction ON public.messages USING btree (conversation_id, direction);


--
-- Name: index_messages_on_conversation_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_messages_on_conversation_id_and_id ON public.messages USING btree (conversation_id, id);


--
-- Name: index_notes_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_agent_id ON public.notes USING btree (agent_id);


--
-- Name: index_notes_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notes_on_conversation_id ON public.notes USING btree (conversation_id);


--
-- Name: index_notes_on_conversation_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notes_on_conversation_id_and_id ON public.notes USING btree (conversation_id, id);


--
-- Name: index_rule_executions_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rule_executions_on_conversation_id ON public.rule_executions USING btree (conversation_id);


--
-- Name: index_rule_executions_on_execution_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_rule_executions_on_execution_key ON public.rule_executions USING btree (execution_key);


--
-- Name: index_rule_executions_on_stage_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_rule_executions_on_stage_id ON public.rule_executions USING btree (stage_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_stage_transitions_on_conversation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stage_transitions_on_conversation_id ON public.stage_transitions USING btree (conversation_id);


--
-- Name: index_stage_transitions_on_conversation_id_and_entry_identity; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stage_transitions_on_conversation_id_and_entry_identity ON public.stage_transitions USING btree (conversation_id, entry_identity);


--
-- Name: index_stage_transitions_on_conversation_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stage_transitions_on_conversation_id_and_id ON public.stage_transitions USING btree (conversation_id, id);


--
-- Name: index_stages_on_flow_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stages_on_flow_version_id ON public.stages USING btree (flow_version_id);


--
-- Name: index_stages_on_flow_version_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stages_on_flow_version_id_and_id ON public.stages USING btree (flow_version_id, id);


--
-- Name: index_stages_on_flow_version_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stages_on_flow_version_id_and_key ON public.stages USING btree (flow_version_id, key);


--
-- Name: index_stages_on_flow_version_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_stages_on_flow_version_id_and_position ON public.stages USING btree (flow_version_id, "position");


--
-- Name: index_team_memberships_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_team_memberships_on_account_id ON public.team_memberships USING btree (account_id);


--
-- Name: index_team_memberships_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_team_memberships_on_agent_id ON public.team_memberships USING btree (agent_id);


--
-- Name: index_team_memberships_on_team_and_agent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_team_memberships_on_team_and_agent ON public.team_memberships USING btree (team_id, agent_id);


--
-- Name: index_teams_on_account_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teams_on_account_id ON public.teams USING btree (account_id);


--
-- Name: index_teams_on_account_id_and_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teams_on_account_id_and_id ON public.teams USING btree (account_id, id);


--
-- Name: index_teams_on_account_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_teams_on_account_id_and_name ON public.teams USING btree (account_id, name);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: account_invitations fk_account_invitations_accepted_by_account_scoped; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_invitations
    ADD CONSTRAINT fk_account_invitations_accepted_by_account_scoped FOREIGN KEY (account_id, accepted_by_membership_id) REFERENCES public.memberships(account_id, id);


--
-- Name: account_invitations fk_account_invitations_inviter_account_scoped; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_invitations
    ADD CONSTRAINT fk_account_invitations_inviter_account_scoped FOREIGN KEY (account_id, inviter_membership_id) REFERENCES public.memberships(account_id, id);


--
-- Name: agents fk_agents_membership_account_scoped; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT fk_agents_membership_account_scoped FOREIGN KEY (account_id, membership_id) REFERENCES public.memberships(account_id, id);


--
-- Name: item_selections fk_item_selections_conversation_account_scoped; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_selections
    ADD CONSTRAINT fk_item_selections_conversation_account_scoped FOREIGN KEY (account_id, conversation_id) REFERENCES public.conversations(account_id, id);


--
-- Name: conversations fk_rails_00afd02cba; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_00afd02cba FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: flows fk_rails_042c9dac53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flows
    ADD CONSTRAINT fk_rails_042c9dac53 FOREIGN KEY (current_version_id) REFERENCES public.flow_versions(id);


--
-- Name: knowledge_sources fk_rails_0510c01079; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_sources
    ADD CONSTRAINT fk_rails_0510c01079 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: item_selections fk_rails_0aabf16132; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_selections
    ADD CONSTRAINT fk_rails_0aabf16132 FOREIGN KEY (item_id) REFERENCES public.items(id);


--
-- Name: conversations fk_rails_0b87b55aff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_0b87b55aff FOREIGN KEY (account_id, team_id) REFERENCES public.teams(account_id, id);


--
-- Name: knowledge_sources fk_rails_0ca2454149; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_sources
    ADD CONSTRAINT fk_rails_0ca2454149 FOREIGN KEY (current_revision_id) REFERENCES public.knowledge_revisions(id);


--
-- Name: items fk_rails_13270fc162; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT fk_rails_13270fc162 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: ai_runs fk_rails_1368d01df0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_runs
    ADD CONSTRAINT fk_rails_1368d01df0 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: message_deliveries fk_rails_2e5e6e1d74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_deliveries
    ADD CONSTRAINT fk_rails_2e5e6e1d74 FOREIGN KEY (channel_id) REFERENCES public.channels(id);


--
-- Name: stage_transitions fk_rails_31d1222ff4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_transitions
    ADD CONSTRAINT fk_rails_31d1222ff4 FOREIGN KEY (to_stage_id) REFERENCES public.stages(id);


--
-- Name: messages fk_rails_3209a7ff53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_3209a7ff53 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: ai_runs fk_rails_3580866131; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_runs
    ADD CONSTRAINT fk_rails_3580866131 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: stage_transitions fk_rails_3c3ceeec32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_transitions
    ADD CONSTRAINT fk_rails_3c3ceeec32 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: catalogs fk_rails_42305b367e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogs
    ADD CONSTRAINT fk_rails_42305b367e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: ai_runs fk_rails_4435c92755; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_runs
    ADD CONSTRAINT fk_rails_4435c92755 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: conversation_reads fk_rails_446634b7c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT fk_rails_446634b7c3 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: agent_configurations fk_rails_4a3085eb6c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_configurations
    ADD CONSTRAINT fk_rails_4a3085eb6c FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: stage_transitions fk_rails_5080c03c85; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stage_transitions
    ADD CONSTRAINT fk_rails_5080c03c85 FOREIGN KEY (from_stage_id) REFERENCES public.stages(id);


--
-- Name: stages fk_rails_56d6d87803; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT fk_rails_56d6d87803 FOREIGN KEY (flow_version_id) REFERENCES public.flow_versions(id);


--
-- Name: knowledge_revisions fk_rails_5999627a81; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.knowledge_revisions
    ADD CONSTRAINT fk_rails_5999627a81 FOREIGN KEY (knowledge_source_id) REFERENCES public.knowledge_sources(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: rule_executions fk_rails_7644e74964; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT fk_rails_7644e74964 FOREIGN KEY (stage_id) REFERENCES public.stages(id);


--
-- Name: account_invitations fk_rails_7a9e106543; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_invitations
    ADD CONSTRAINT fk_rails_7a9e106543 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: rule_executions fk_rails_7be42fd232; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rule_executions
    ADD CONSTRAINT fk_rails_7be42fd232 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: agent_knowledge_grants fk_rails_7c3d991474; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_knowledge_grants
    ADD CONSTRAINT fk_rails_7c3d991474 FOREIGN KEY (knowledge_source_id) REFERENCES public.knowledge_sources(id);


--
-- Name: messages fk_rails_7f927086d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_7f927086d2 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: channel_threads fk_rails_87f7c72206; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_threads
    ADD CONSTRAINT fk_rails_87f7c72206 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: item_selections fk_rails_8b89aa738d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_selections
    ADD CONSTRAINT fk_rails_8b89aa738d FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: agent_configurations fk_rails_9033d6f4ee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_configurations
    ADD CONSTRAINT fk_rails_9033d6f4ee FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: appointments fk_rails_920ecef82c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT fk_rails_920ecef82c FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: notes fk_rails_9259470eb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_rails_9259470eb1 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: ai_runs fk_rails_9605939217; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_runs
    ADD CONSTRAINT fk_rails_9605939217 FOREIGN KEY (agent_configuration_id) REFERENCES public.agent_configurations(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: flow_versions fk_rails_a69f0bb117; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_versions
    ADD CONSTRAINT fk_rails_a69f0bb117 FOREIGN KEY (flow_id) REFERENCES public.flows(id);


--
-- Name: conversations fk_rails_a72440fed6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_a72440fed6 FOREIGN KEY (customer_id) REFERENCES public.customers(id);


--
-- Name: appointments fk_rails_aa14456f23; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT fk_rails_aa14456f23 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: items fk_rails_ac675f13b9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.items
    ADD CONSTRAINT fk_rails_ac675f13b9 FOREIGN KEY (catalog_id) REFERENCES public.catalogs(id);


--
-- Name: notes fk_rails_b47a62c385; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_rails_b47a62c385 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: teams fk_rails_b4ac0a83f9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT fk_rails_b4ac0a83f9 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: message_deliveries fk_rails_b53ffa9000; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_deliveries
    ADD CONSTRAINT fk_rails_b53ffa9000 FOREIGN KEY (message_id) REFERENCES public.messages(id);


--
-- Name: conversation_reads fk_rails_bc926ff432; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT fk_rails_bc926ff432 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: item_selections fk_rails_bd05ae966c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_selections
    ADD CONSTRAINT fk_rails_bd05ae966c FOREIGN KEY (catalog_id) REFERENCES public.catalogs(id);


--
-- Name: agents fk_rails_be203b109b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT fk_rails_be203b109b FOREIGN KEY (agent_configuration_id) REFERENCES public.agent_configurations(id);


--
-- Name: channel_threads fk_rails_bfe9ed6493; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_threads
    ADD CONSTRAINT fk_rails_bfe9ed6493 FOREIGN KEY (channel_id) REFERENCES public.channels(id);


--
-- Name: field_definitions fk_rails_c5aa27cbc1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.field_definitions
    ADD CONSTRAINT fk_rails_c5aa27cbc1 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: item_selections fk_rails_c9756ae455; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.item_selections
    ADD CONSTRAINT fk_rails_c9756ae455 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: agent_knowledge_grants fk_rails_cc06be44c1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_knowledge_grants
    ADD CONSTRAINT fk_rails_cc06be44c1 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: conversations fk_rails_d057651dc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_d057651dc2 FOREIGN KEY (account_id, owner_id) REFERENCES public.agents(account_id, id);


--
-- Name: conversations fk_rails_d1a1a5b494; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_d1a1a5b494 FOREIGN KEY (flow_version_id, current_stage_id) REFERENCES public.stages(flow_version_id, id);


--
-- Name: flows fk_rails_d46bc6b575; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flows
    ADD CONSTRAINT fk_rails_d46bc6b575 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: channels fk_rails_db928aa85e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channels
    ADD CONSTRAINT fk_rails_db928aa85e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: agent_knowledge_grants fk_rails_dcd80b2d1d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_knowledge_grants
    ADD CONSTRAINT fk_rails_dcd80b2d1d FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: customers fk_rails_ed7ccfecee; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT fk_rails_ed7ccfecee FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: memberships fk_rails_edbc202c67; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_edbc202c67 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: message_deliveries fk_rails_f07bfd3176; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_deliveries
    ADD CONSTRAINT fk_rails_f07bfd3176 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: channel_threads fk_rails_f68eee7b9d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.channel_threads
    ADD CONSTRAINT fk_rails_f68eee7b9d FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: agents fk_rails_f6a7a5a81e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT fk_rails_f6a7a5a81e FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: team_memberships fk_rails_f6ef2db329; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT fk_rails_f6ef2db329 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: appointments fk_rails_fa77b27f94; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT fk_rails_fa77b27f94 FOREIGN KEY (scheduled_agent_id) REFERENCES public.agents(id);


--
-- Name: team_memberships fk_team_memberships_agent_account_scoped; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT fk_team_memberships_agent_account_scoped FOREIGN KEY (account_id, agent_id) REFERENCES public.agents(account_id, id);


--
-- Name: team_memberships fk_team_memberships_team_account_scoped; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_memberships
    ADD CONSTRAINT fk_team_memberships_team_account_scoped FOREIGN KEY (account_id, team_id) REFERENCES public.teams(account_id, id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260915235000'),
('20260915200000'),
('20260913223429'),
('20260913222919'),
('20260913211038'),
('20260913210939'),
('20260913203056'),
('20260913184243'),
('20260913184242'),
('20260913184241'),
('20260913182455'),
('20260913175317'),
('20260913160630'),
('20260913160621'),
('20260913160620'),
('20260913160619'),
('20260913160441'),
('20260913160409'),
('20260913160346'),
('20260913160345'),
('20260913160316'),
('20260912160002'),
('20260912160001'),
('20260912160000'),
('20260912153006'),
('20260912153005'),
('20260912153004'),
('20260912153003'),
('20260912153002'),
('20260912153001'),
('20260912153000'),
('20260912151121'),
('20260912151120');

