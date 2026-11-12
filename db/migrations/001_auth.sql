-- ============================================================
-- BASE DE DATOS: MÓDULO DE AUTENTICACIÓN / AUTORIZACIÓN / AUDITORÍA
-- PostgreSQL 15+ (verificado en PostgreSQL 18)
-- ============================================================

SET client_encoding = 'UTF8';

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE user_statuses (
    code            varchar(32) PRIMARY KEY,
    description     varchar(255) NOT NULL
);

INSERT INTO user_statuses (code, description) VALUES
    ('pending', 'Usuario pendiente de completar la autenticación'),
    ('active', 'Usuario activo'),
    ('suspended', 'Usuario temporalmente suspendido'),
    ('disabled', 'Usuario deshabilitado');

CREATE TABLE users (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email               citext NOT NULL UNIQUE,
    display_name        varchar(160),
    status_code         varchar(32) NOT NULL DEFAULT 'pending'
                            REFERENCES user_statuses(code),
    email_verified_at   timestamptz,
    last_login_at       timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    deleted_at          timestamptz,
    CONSTRAINT users_email_not_blank CHECK (btrim(email::text) <> ''),
    CONSTRAINT users_verified_email_consistency CHECK (
        email_verified_at IS NULL OR status_code <> 'pending'
    ),
    CONSTRAINT users_email_domain CHECK (
        email::text ~* '@utt\.edu\.mx$'
    ),
    CONSTRAINT users_active_requires_verified_email CHECK (
        status_code <> 'active' OR email_verified_at IS NOT NULL
    )
);

CREATE INDEX idx_users_status_active
    ON users (status_code, created_at DESC)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_users_last_login
    ON users (last_login_at DESC)
    WHERE deleted_at IS NULL;

CREATE TABLE identity_providers (
    id              smallint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            varchar(32) NOT NULL UNIQUE,
    description     varchar(255) NOT NULL
);

INSERT INTO identity_providers (code, description)
VALUES ('firebase', 'Firebase Authentication');

CREATE TABLE user_identities (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid NOT NULL
                            REFERENCES users(id) ON DELETE CASCADE,
    provider_id         smallint NOT NULL
                            REFERENCES identity_providers(id),
    provider_subject    varchar(255) NOT NULL,
    provider_email      citext,
    claims_snapshot     jsonb NOT NULL DEFAULT '{}'::jsonb,
    linked_at           timestamptz NOT NULL DEFAULT now(),
    last_verified_at    timestamptz,
    CONSTRAINT uq_user_identity_subject
        UNIQUE (provider_id, provider_subject),
    CONSTRAINT uq_user_identity_provider
        UNIQUE (user_id, provider_id),
    CONSTRAINT user_identity_subject_not_blank
        CHECK (btrim(provider_subject) <> ''),
    CONSTRAINT user_identity_claims_object
        CHECK (jsonb_typeof(claims_snapshot) = 'object')
);

CREATE INDEX idx_user_identities_user
    ON user_identities (user_id);

CREATE TABLE roles (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code            varchar(64) NOT NULL UNIQUE,
    name            varchar(120) NOT NULL,
    description     varchar(500),
    is_system       boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT role_code_format
        CHECK (code ~ '^[a-z][a-z0-9_.-]{1,63}$')
);

INSERT INTO roles (code, name, description, is_system) VALUES
    ('lector', 'Lector', 'Usuario de consulta de avisos e información institucional', false),
    ('departamento', 'Departamento', 'Gestor de contenido y atención departamental', false),
    ('administrador', 'Administrador', 'Administrador global del sistema', true);

CREATE TABLE permissions (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code            varchar(128) NOT NULL UNIQUE,
    description     varchar(500) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT permission_code_format
        CHECK (code ~ '^[a-z][a-z0-9_.:-]{2,127}$')
);

CREATE TABLE role_permissions (
    role_id         uuid NOT NULL
                        REFERENCES roles(id) ON DELETE CASCADE,
    permission_id   uuid NOT NULL
                        REFERENCES permissions(id) ON DELETE CASCADE,
    granted_at      timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (role_id, permission_id)
);

CREATE INDEX idx_role_permissions_permission
    ON role_permissions (permission_id, role_id);

CREATE TABLE user_roles (
    user_id         uuid NOT NULL
                        REFERENCES users(id) ON DELETE CASCADE,
    role_id         uuid NOT NULL
                        REFERENCES roles(id) ON DELETE RESTRICT,
    granted_by      uuid
                        REFERENCES users(id) ON DELETE SET NULL,
    granted_at      timestamptz NOT NULL DEFAULT now(),
    expires_at      timestamptz,
    PRIMARY KEY (user_id, role_id),
    CONSTRAINT user_role_expiration
        CHECK (expires_at IS NULL OR expires_at > granted_at)
);

CREATE INDEX idx_user_roles_role
    ON user_roles (role_id, user_id);

CREATE INDEX idx_user_roles_expiration
    ON user_roles (expires_at)
    WHERE expires_at IS NOT NULL;

CREATE TABLE magic_link_statuses (
    code            varchar(32) PRIMARY KEY,
    description     varchar(255) NOT NULL,
    is_terminal     boolean NOT NULL DEFAULT false
);

INSERT INTO magic_link_statuses (code, description, is_terminal) VALUES
    ('requested', 'Solicitud recibida', false),
    ('sent', 'Enlace enviado por Firebase', false),
    ('consumed', 'Enlace utilizado correctamente', true),
    ('expired', 'Enlace expirado', true),
    ('invalid', 'Enlace inválido', true),
    ('failed', 'Fallo durante el envío o validación', true),
    ('revoked', 'Solicitud revocada', true);

CREATE TABLE magic_link_requests (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             uuid
                            REFERENCES users(id) ON DELETE SET NULL,
    email               citext NOT NULL,
    status_code         varchar(32) NOT NULL DEFAULT 'requested'
                            REFERENCES magic_link_statuses(code),
    correlation_id      uuid NOT NULL DEFAULT gen_random_uuid() UNIQUE,
    continue_url        text NOT NULL,
    client_nonce_hash   bytea,
    requested_ip        inet,
    user_agent          text,
    firebase_event_id   varchar(255),
    requested_at        timestamptz NOT NULL DEFAULT now(),
    sent_at             timestamptz,
    expires_at          timestamptz NOT NULL,
    consumed_at         timestamptz,
    failure_code        varchar(100),
    failure_detail      varchar(500),
    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT magic_link_email_not_blank
        CHECK (btrim(email::text) <> ''),
    CONSTRAINT magic_link_expiration
        CHECK (expires_at > requested_at),
    CONSTRAINT magic_link_sent_time
        CHECK (sent_at IS NULL OR sent_at >= requested_at),
    CONSTRAINT magic_link_consumed_time
        CHECK (consumed_at IS NULL OR consumed_at >= requested_at),
    CONSTRAINT magic_link_consumed_status
        CHECK (
            (status_code = 'consumed' AND consumed_at IS NOT NULL)
            OR
            (status_code <> 'consumed' AND consumed_at IS NULL)
        ),
    CONSTRAINT magic_link_metadata_object
        CHECK (jsonb_typeof(metadata) = 'object')
);

CREATE INDEX idx_magic_link_email_requested
    ON magic_link_requests (email, requested_at DESC);

CREATE INDEX idx_magic_link_user_requested
    ON magic_link_requests (user_id, requested_at DESC)
    WHERE user_id IS NOT NULL;

CREATE INDEX idx_magic_link_pending_expiration
    ON magic_link_requests (expires_at)
    WHERE status_code IN ('requested', 'sent');

CREATE INDEX idx_magic_link_firebase_event
    ON magic_link_requests (firebase_event_id)
    WHERE firebase_event_id IS NOT NULL;

CREATE TABLE audit_event_types (
    code            varchar(80) PRIMARY KEY,
    description     varchar(255) NOT NULL
);

INSERT INTO audit_event_types (code, description) VALUES
    ('auth.magic_link_requested', 'Solicitud de enlace mágico'),
    ('auth.magic_link_sent', 'Enlace mágico enviado'),
    ('auth.login_succeeded', 'Autenticación completada'),
    ('auth.login_failed', 'Autenticación fallida'),
    ('auth.link_expired', 'Enlace mágico expirado'),
    ('auth.link_invalid', 'Enlace mágico inválido'),
    ('user.created', 'Usuario creado'),
    ('user.updated', 'Usuario actualizado'),
    ('role.granted', 'Rol concedido'),
    ('role.revoked', 'Rol revocado');

CREATE TABLE audit_events (
    occurred_at         timestamptz NOT NULL DEFAULT now(),
    id                  uuid NOT NULL DEFAULT gen_random_uuid(),
    event_type_code     varchar(80) NOT NULL
                            REFERENCES audit_event_types(code),
    actor_user_id       uuid
                            REFERENCES users(id) ON DELETE SET NULL,
    subject_user_id     uuid
                            REFERENCES users(id) ON DELETE SET NULL,
    magic_link_request_id uuid
                            REFERENCES magic_link_requests(id) ON DELETE SET NULL,
    correlation_id      uuid,
    resource_type       varchar(80),
    resource_id         varchar(255),
    source_ip           inet,
    user_agent          text,
    succeeded           boolean NOT NULL,
    payload             jsonb NOT NULL DEFAULT '{}'::jsonb,
    PRIMARY KEY (occurred_at, id),
    CONSTRAINT audit_payload_object
        CHECK (jsonb_typeof(payload) = 'object')
) PARTITION BY RANGE (occurred_at);

CREATE TABLE audit_events_default
    PARTITION OF audit_events DEFAULT;

CREATE INDEX idx_audit_events_actor
    ON audit_events (actor_user_id, occurred_at DESC);

CREATE INDEX idx_audit_events_subject
    ON audit_events (subject_user_id, occurred_at DESC);

CREATE INDEX idx_audit_events_type
    ON audit_events (event_type_code, occurred_at DESC);

CREATE INDEX idx_audit_events_correlation
    ON audit_events (correlation_id, occurred_at DESC)
    WHERE correlation_id IS NOT NULL;

CREATE INDEX idx_audit_events_resource
    ON audit_events (resource_type, resource_id, occurred_at DESC)
    WHERE resource_type IS NOT NULL AND resource_id IS NOT NULL;

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_roles_set_updated_at
BEFORE UPDATE ON roles
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

-- Inmutabilidad del correo institucional (RF-09, R12 del README)
CREATE OR REPLACE FUNCTION prevent_user_email_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.email_verified_at IS NOT NULL
       AND NEW.email IS DISTINCT FROM OLD.email THEN
        RAISE EXCEPTION 'El correo institucional es inmutable una vez verificado (RF-09, R12)';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_prevent_email_change
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION prevent_user_email_change();

COMMIT;
