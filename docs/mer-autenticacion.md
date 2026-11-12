# MER — Módulo de Autenticación, Autorización y Auditoría

Diagrama entidad-relación del módulo (UTT Connect) generado a partir del script SQL de autenticación.
Motor: **PostgreSQL 18** (compatible con 15+).

> **Vista renderizada:** abre `docs/mer-autenticacion.html` en el navegador para ver el diagrama con zoom y descarga en SVG/PNG.

---

## 1. Diagrama general

```mermaid
erDiagram
    USER_STATUSES {
        varchar code PK "pending | active | suspended | disabled"
        varchar description
    }

    USERS {
        uuid id PK "gen_random_uuid()"
        citext email UK "inmutable si está verificado"
        varchar display_name
        varchar status_code FK "-> user_statuses.code"
        timestamptz email_verified_at
        timestamptz last_login_at
        timestamptz created_at
        timestamptz updated_at
        timestamptz deleted_at "borrado lógico"
    }

    IDENTITY_PROVIDERS {
        smallint id PK "GENERATED ALWAYS AS IDENTITY"
        varchar code UK "firebase"
        varchar description
    }

    USER_IDENTITIES {
        uuid id PK
        uuid user_id FK "-> users.id (CASCADE)"
        smallint provider_id FK "-> identity_providers.id"
        varchar provider_subject "UNIQUE con provider_id"
        citext provider_email
        jsonb claims_snapshot
        timestamptz linked_at
        timestamptz last_verified_at
    }

    ROLES {
        uuid id PK
        varchar code UK "lector | departamento | administrador"
        varchar name
        varchar description
        boolean is_system
        timestamptz created_at
        timestamptz updated_at
    }

    PERMISSIONS {
        uuid id PK
        varchar code UK
        varchar description
        timestamptz created_at
    }

    ROLE_PERMISSIONS {
        uuid role_id PK,FK "-> roles.id (CASCADE)"
        uuid permission_id PK,FK "-> permissions.id (CASCADE)"
        timestamptz granted_at
    }

    USER_ROLES {
        uuid user_id PK,FK "-> users.id (CASCADE)"
        uuid role_id PK,FK "-> roles.id (RESTRICT)"
        uuid granted_by FK "-> users.id (SET NULL)"
        timestamptz granted_at
        timestamptz expires_at
    }

    MAGIC_LINK_STATUSES {
        varchar code PK "requested | sent | consumed | expired | invalid | failed | revoked"
        varchar description
        boolean is_terminal
    }

    MAGIC_LINK_REQUESTS {
        uuid id PK
        uuid user_id FK "-> users.id (SET NULL)"
        citext email
        varchar status_code FK "-> magic_link_statuses.code"
        uuid correlation_id UK "trazabilidad end-to-end"
        text continue_url
        bytea client_nonce_hash
        inet requested_ip
        text user_agent
        varchar firebase_event_id
        timestamptz requested_at
        timestamptz sent_at
        timestamptz expires_at
        timestamptz consumed_at
        varchar failure_code
        varchar failure_detail
        jsonb metadata
    }

    AUDIT_EVENT_TYPES {
        varchar code PK "auth.* | user.* | role.*"
        varchar description
    }

    AUDIT_EVENTS {
        timestamptz occurred_at PK "clave de particionamiento"
        uuid id PK
        varchar event_type_code FK "-> audit_event_types.code"
        uuid actor_user_id FK "-> users.id (SET NULL)"
        uuid subject_user_id FK "-> users.id (SET NULL)"
        uuid magic_link_request_id FK "-> magic_link_requests.id (SET NULL)"
        uuid correlation_id
        varchar resource_type
        varchar resource_id
        inet source_ip
        text user_agent
        boolean succeeded
        jsonb payload
    }

    %% ---------- Identidad ----------
    USER_STATUSES ||--o{ USERS : "clasifica"
    USERS ||--o{ USER_IDENTITIES : "vincula"
    IDENTITY_PROVIDERS ||--o{ USER_IDENTITIES : "provee"

    %% ---------- Solicitudes de acceso ----------
    USERS ||--o{ MAGIC_LINK_REQUESTS : "solicita"
    MAGIC_LINK_STATUSES ||--o{ MAGIC_LINK_REQUESTS : "estado"

    %% ---------- Autorización (RBAC) ----------
    USERS ||--o{ USER_ROLES : "tiene"
    ROLES ||--o{ USER_ROLES : "asignado"
    USERS o|--o{ USER_ROLES : "otorga (granted_by)"
    ROLES ||--o{ ROLE_PERMISSIONS : "agrupa"
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : "incluida"

    %% ---------- Auditoría ----------
    AUDIT_EVENT_TYPES ||--o{ AUDIT_EVENTS : "tipifica"
    USERS o|--o{ AUDIT_EVENTS : "actor"
    USERS o|--o{ AUDIT_EVENTS : "sujeto"
    MAGIC_LINK_REQUESTS o|--o{ AUDIT_EVENTS : "origina"
```

---

## 2. Vista por bloques

### 2.1 Identidad del usuario

```mermaid
erDiagram
    USER_STATUSES ||--o{ USERS : clasifica
    USERS ||--o{ USER_IDENTITIES : vincula
    IDENTITY_PROVIDERS ||--o{ USER_IDENTITIES : provee
    USERS ||--o{ MAGIC_LINK_REQUESTS : solicita
    MAGIC_LINK_STATUSES ||--o{ MAGIC_LINK_REQUESTS : estado

    USERS {
        uuid id PK
        citext email UK
        varchar status_code FK
        timestamptz email_verified_at
        timestamptz deleted_at
    }
    USER_IDENTITIES {
        uuid id PK
        uuid user_id FK
        smallint provider_id FK
        varchar provider_subject
        jsonb claims_snapshot
    }
    MAGIC_LINK_REQUESTS {
        uuid id PK
        uuid user_id FK
        citext email
        varchar status_code FK
        uuid correlation_id UK
        timestamptz expires_at
        timestamptz consumed_at
    }
```

### 2.2 Autorización (RBAC)

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : tiene
    ROLES ||--o{ USER_ROLES : asignado
    ROLES ||--o{ ROLE_PERMISSIONS : agrupa
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : incluida
    USERS o|--o{ USER_ROLES : "otorga (granted_by)"

    USERS {
        uuid id PK
        citext email UK
    }
    ROLES {
        uuid id PK
        varchar code UK
        boolean is_system
    }
    USER_ROLES {
        uuid user_id PK,FK
        uuid role_id PK,FK
        uuid granted_by FK
        timestamptz expires_at
    }
    PERMISSIONS {
        uuid id PK
        varchar code UK
    }
    ROLE_PERMISSIONS {
        uuid role_id PK,FK
        uuid permission_id PK,FK
    }
```

### 2.3 Auditoría

```mermaid
erDiagram
    AUDIT_EVENT_TYPES ||--o{ AUDIT_EVENTS : tipifica
    USERS o|--o{ AUDIT_EVENTS : actor
    USERS o|--o{ AUDIT_EVENTS : sujeto
    MAGIC_LINK_REQUESTS o|--o{ AUDIT_EVENTS : origina

    AUDIT_EVENTS {
        timestamptz occurred_at PK
        uuid id PK
        varchar event_type_code FK
        uuid actor_user_id FK
        uuid subject_user_id FK
        uuid magic_link_request_id FK
        uuid correlation_id
        boolean succeeded
        jsonb payload
    }
```

---

## 3. Cardinalidades en palabras

| Relación | Cardinalidad | Lectura |
|---|---|---|
| `user_statuses` → `users` | 1 : N | Un estado agrupa muchos usuarios; cada usuario tiene exactamente un estado. |
| `users` → `user_identities` | 1 : N | Un usuario puede tener varias identidades (hoy solo Firebase). |
| `identity_providers` → `user_identities` | 1 : N | Un proveedor emite muchas identidades. |
| `users` → `magic_link_requests` | 1 : N | Un usuario puede pedir muchos enlaces; la solicitud puede no tener usuario aún (`user_id` nulo). |
| `magic_link_statuses` → `magic_link_requests` | 1 : N | Cada solicitud tiene un estado del catálogo. |
| `users` ↔ `roles` | N : M | Resuelta por `user_roles`, con `expires_at` y `granted_by`. |
| `roles` ↔ `permissions` | N : M | Resuelta por `role_permissions`. |
| `users` → `user_roles` (`granted_by`) | 1 : N | Auto-referencia: quién otorgó el rol. |
| `audit_event_types` → `audit_events` | 1 : N | Catálogo de tipos de evento. |
| `users` → `audit_events` | 1 : N (×2) | Un usuario puede ser actor y/o sujeto de muchos eventos. |
| `magic_link_requests` → `audit_events` | 1 : N | Cada evento puede rastrearse hasta la solicitud que lo originó. |

---

## 4. Reglas de negocio dentro del modelo

| Regla | Dónde vive | Efecto |
|---|---|---|
| Solo correos `@utt.edu.mx` | `users_email_domain` | `CHECK` con expresión regular. |
| Correo verificado ⇒ estado ≠ `pending` | `users_verified_email_consistency` | `CHECK` cruzado. |
| Estado `active` exige correo verificado | `users_active_requires_verified_email` | `CHECK` cruzado. |
| Correo inmutable tras verificación (RF‑09 / R12) | `trg_users_prevent_email_change` | Trigger `BEFORE UPDATE` que lanza excepción. |
| `updated_at` automático | `trg_users_set_updated_at`, `trg_roles_set_updated_at` | Trigger `BEFORE UPDATE`. |
| Una identidad por proveedor y usuario | `uq_user_identity_provider` | `UNIQUE (user_id, provider_id)`. |
| Una identidad por sujeto de proveedor | `uq_user_identity_subject` | `UNIQUE (provider_id, provider_subject)`. |
| Consumo coherente del enlace | `magic_link_consumed_status` | `consumed` ⇔ `consumed_at` no nulo. |
| Expiración posterior a la solicitud | `magic_link_expiration` | `CHECK (expires_at > requested_at)`. |
| Vigencia del rol | `user_role_expiration` | `CHECK (expires_at IS NULL OR expires_at > granted_at)`. |
| Catálogos con formato controlado | `role_code_format`, `permission_code_format` | `CHECK` con regex. |
| Payloads JSON siempre objeto | `user_identity_claims_object`, `magic_link_metadata_object`, `audit_payload_object` | `CHECK jsonb_typeof(...) = 'object'`. |

---

## 5. Lo que Mermaid **no** puede mostrar

El diagrama ER describe tablas, columnas y llaves. Estos elementos del script existen en la base de datos pero no se representan visualmente:

| Elemento | Detalle |
|---|---|
| **Particionamiento** | `audit_events` está particionada por rango de `occurred_at`; hoy solo existe la partición `audit_events_default`. |
| **Clave primaria compuesta** | En `audit_events` es `(occurred_at, id)`; se marca con doble `PK`. |
| **Índices** | 11 índices, varios parciales (`WHERE deleted_at IS NULL`, `WHERE expires_at IS NOT NULL`, `WHERE correlation_id IS NOT NULL`, etc.). |
| **Triggers** | 3 triggers: 2 de `updated_at` y 1 de inmutabilidad del correo. |
| **Extensiones** | `pgcrypto` (para `gen_random_uuid()`) y `citext` (correos sin distinción de mayúsculas). |
| **Borrado lógico** | `users.deleted_at`; no hay `DELETE` físico de usuarios en el flujo normal. |
| **Catálogos sembrados** | 4 estados de usuario, 1 proveedor, 3 roles, 7 estados de enlace y 10 tipos de evento de auditoría. |

---

## 6. Script para regenerarlo

Si modificas el esquema, actualiza el `.mmd` y renderízalo con:

```bash
npx @mermaid-js/mermaid-cli -i docs/mer-autenticacion.mmd -o docs/mer-autenticacion.svg
```

El bloque Mermaid de la sección 1 es la fuente de verdad (`docs/mer-autenticacion.mmd`).
