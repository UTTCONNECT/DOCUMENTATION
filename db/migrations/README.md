# Migraciones de base de datos

Orden de ejecución del módulo de identidad. Cada archivo se aplica **una sola vez** y en orden.

| # | Archivo | Qué crea | ¿Idempotente? |
|---|---|---|---|
| 001 | `001_auth.sql` | Extensiones, catálogos, 12 tablas, índices, triggers y partición de auditoría. | No |
| 002 | `002_seed_permissions.sql` | 10 permisos del MVP y su asignación a los 3 roles. | Sí |

> `001` no es idempotente a propósito: es una migración, no un script de instalación.
> Si se ejecuta dos veces fallará con “la relación ya existe”. Eso es lo esperado.

---

## Cómo aplicar

```bash
# 1. Crear la base (una sola vez)
createdb -U postgres utt_connect

# 2. Aplicar en orden
psql -U postgres -d utt_connect -v ON_ERROR_STOP=1 -f db/migrations/001_auth.sql
psql -U postgres -d utt_connect -v ON_ERROR_STOP=1 -f db/migrations/002_seed_permissions.sql
```

En PowerShell:

```powershell
$env:PGPASSWORD = "tu_password"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d utt_connect -v ON_ERROR_STOP=1 -f db/migrations/001_auth.sql
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d utt_connect -v ON_ERROR_STOP=1 -f db/migrations/002_seed_permissions.sql
```

---

## Requisitos

- **PostgreSQL 15 o superior** (probado en 18).
- Usuario con permiso para `CREATE EXTENSION` (`pgcrypto`, `citext`).
  En Postgres gestionado (Supabase, Neon, RDS) suele bastar el rol administrador del proyecto.
- Codificación UTF-8.

---

## Verificación rápida

```sql
-- Deben ser 10
SELECT count(*) FROM permissions;

-- Debe dar: administrador 10, departamento 5, lector 1
SELECT r.code, count(rp.permission_id) AS permisos
FROM roles r
LEFT JOIN role_permissions rp ON rp.role_id = r.id
GROUP BY r.code
ORDER BY r.code;

-- Permisos efectivos de un usuario
SELECT DISTINCT p.code
FROM user_roles ur
JOIN role_permissions rp ON rp.role_id = ur.role_id
JOIN permissions p ON p.id = rp.permission_id
WHERE ur.user_id = $1
  AND (ur.expires_at IS NULL OR ur.expires_at > now());
```

---

## Próximas migraciones previstas

| # | Archivo | Módulo |
|---|---|---|
| 003 | `003_departments.sql` | Departamentos y sus gestores (RF-14, RF-15) |
| 004 | `004_announcements.sql` | Muro de avisos y adjuntos (RF-17, RF-18, RF-19) |
| 005 | `005_chat.sql` | Conversaciones y mensajes (RF-20, RF-21, RF-22) |
| 006 | `006_sessions.sql` | Sesiones concurrentes (RF-11), si se implementa en BD |

Los nuevos tipos de evento de auditoría **no requieren migración de esquema**: basta un
`INSERT INTO audit_event_types`.
