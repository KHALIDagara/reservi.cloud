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
    CONSTRAINT account_invitations_delivery_status_check CHECK (((delivery_status)::text = ANY (ARRAY[('pending'::character varying)::text, ('delivered'::character varying)::text, ('failed'::character varying)::text, ('unknown'::character varying)::text]))),
    CONSTRAINT account_invitations_role_check CHECK (((role)::text = ANY (ARRAY[('admin'::character varying)::text, ('manager'::character varying)::text, ('operator'::character varying)::text]))),
    CONSTRAINT account_invitations_status_check CHECK (((status)::text = ANY (ARRAY[('pending'::character varying)::text, ('accepted'::character varying)::text, ('revoked'::character varying)::text])))
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
    updated_at timestamp(6) without time zone NOT NULL
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
    CONSTRAINT agents_kind_check CHECK (((kind)::text = ANY (ARRAY[('human'::character varying)::text, ('ai'::character varying)::text]))),
    CONSTRAINT agents_kind_membership_check CHECK (((((kind)::text = 'human'::text) AND (membership_id IS NOT NULL)) OR (((kind)::text = 'ai'::text) AND (membership_id IS NULL))))
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
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


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
    updated_at timestamp(6) without time zone NOT NULL
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
    CONSTRAINT memberships_role_check CHECK (((role)::text = ANY (ARRAY[('admin'::character varying)::text, ('manager'::character varying)::text, ('operator'::character varying)::text])))
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
-- Name: agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents ALTER COLUMN id SET DEFAULT nextval('public.agents_id_seq'::regclass);


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
-- Name: flow_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flow_versions ALTER COLUMN id SET DEFAULT nextval('public.flow_versions_id_seq'::regclass);


--
-- Name: flows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flows ALTER COLUMN id SET DEFAULT nextval('public.flows_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships ALTER COLUMN id SET DEFAULT nextval('public.memberships_id_seq'::regclass);


--
-- Name: messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages ALTER COLUMN id SET DEFAULT nextval('public.messages_id_seq'::regclass);


--
-- Name: notes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes ALTER COLUMN id SET DEFAULT nextval('public.notes_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


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
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


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
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: notes notes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT notes_pkey PRIMARY KEY (id);


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
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


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
-- Name: conversations fk_rails_0b87b55aff; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversations
    ADD CONSTRAINT fk_rails_0b87b55aff FOREIGN KEY (account_id, team_id) REFERENCES public.teams(account_id, id);


--
-- Name: messages fk_rails_3209a7ff53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_3209a7ff53 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: conversation_reads fk_rails_446634b7c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT fk_rails_446634b7c3 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: stages fk_rails_56d6d87803; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stages
    ADD CONSTRAINT fk_rails_56d6d87803 FOREIGN KEY (flow_version_id) REFERENCES public.flow_versions(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: account_invitations fk_rails_7a9e106543; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.account_invitations
    ADD CONSTRAINT fk_rails_7a9e106543 FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: messages fk_rails_7f927086d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT fk_rails_7f927086d2 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


--
-- Name: notes fk_rails_9259470eb1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notes
    ADD CONSTRAINT fk_rails_9259470eb1 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


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
-- Name: conversation_reads fk_rails_bc926ff432; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation_reads
    ADD CONSTRAINT fk_rails_bc926ff432 FOREIGN KEY (conversation_id) REFERENCES public.conversations(id);


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

