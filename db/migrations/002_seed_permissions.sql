-- ============================================================
-- 002 · Semilla de permisos y asignación por rol (RBAC)
-- Requiere: 001_auth.sql
-- Idempotente: puede ejecutarse varias veces sin duplicar filas.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- Permisos del MVP
-- Convención: <modulo>.<accion>
-- Nota: los permisos con ".propios" solo habilitan la acción;
--       la verificación de propiedad (author_user_id = yo) se
--       hace en el backend, porque depende del recurso concreto.
-- ------------------------------------------------------------
INSERT INTO permissions (code, description) VALUES
    ('avisos.crear',            'Publicar avisos en el muro institucional'),
    ('avisos.editar.propios',   'Editar los avisos creados por el propio usuario'),
    ('avisos.eliminar.propios', 'Eliminar los avisos creados por el propio usuario'),
    ('avisos.moderar',          'Editar o eliminar cualquier aviso (moderación)'),
    ('departamentos.gestionar', 'Crear, editar y eliminar departamentos y sus gestores'),
    ('usuarios.gestionar',      'Consultar usuarios, asignar y revocar roles'),
    ('chat.iniciar',            'Iniciar una conversación con un departamento'),
    ('chat.responder',          'Responder conversaciones del propio departamento'),
    ('chat.archivar',           'Archivar conversaciones del propio departamento'),
    ('auditoria.ver',           'Consultar el registro de auditoría')
ON CONFLICT (code) DO NOTHING;

-- ------------------------------------------------------------
-- Lector: consulta y puede iniciar chat con un departamento
-- ------------------------------------------------------------
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN ('chat.iniciar')
WHERE r.code = 'lector'
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Departamento: publica y gestiona sus propios avisos, atiende chat
-- ------------------------------------------------------------
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
JOIN permissions p ON p.code IN (
    'avisos.crear',
    'avisos.editar.propios',
    'avisos.eliminar.propios',
    'chat.responder',
    'chat.archivar'
)
WHERE r.code = 'departamento'
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- Administrador: todos los permisos
-- ------------------------------------------------------------
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'administrador'
ON CONFLICT DO NOTHING;

COMMIT;
