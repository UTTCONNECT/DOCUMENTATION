# Guía de inicio · Módulo de autenticación (magic link)

> **Proyecto:** UTT Connect · Equipo 1
> **Stack:** NestJS 11 · TypeORM · PostgreSQL 18 · Firebase Auth (emulador)
> **Última actualización:** 11 de noviembre de 2026
> **Documentos relacionados:** [`ADR-001`](adr/ADR-001-autenticacion-magic-link.md) · [`db/migrations/README.md`](../db/migrations/README.md)

Esta guía lleva a un integrante desde “acabo de clonar el repositorio” hasta “el módulo de auth responde y está probado”. Sigue el orden: cada sección depende de la anterior.

---

<a id="indice"></a>

## Índice

1. [Objetivo y alcance](#objetivo)
2. [Programas necesarios](#programas)
3. [Clonación de repositorios](#clonacion)
4. [Creación de ramas](#ramas)
5. [Cómo hacer commits](#commits)
6. [Push y Pull Request](#push)
7. [Script de base de datos](#script-bd)
8. [Cómo ejecutar el script](#ejecutar-script)
9. [Preparar el proyecto NestJS](#preparar-nest)
10. [Entities, DTOs, Services, Controllers, Module y Specs](#estructura)
11. [Cómo empezar: levantar y verificar](#empezar)
12. [Testear](#testear)
13. [Consumir rutas](#consumir)
14. [Errores comunes](#errores)
15. [Checklist de terminado](#checklist)

---

<a id="objetivo"></a>

## 1. Objetivo y alcance

Al terminar esta guía debe existir un flujo funcional **sin contraseñas**:

```
1. POST /auth/magic-link   → registra la solicitud y genera el enlace (Firebase)
2. El usuario abre el enlace y obtiene un ID token de Firebase
3. POST /auth/verify       → valida el token, crea/recupera el usuario y emite un JWT propio
4. GET  /auth/me           → devuelve usuario, roles y permisos efectivos
```

**Incluye:** base de datos, proyecto NestJS, entidades, DTOs, servicios, controladores, guards, pruebas y consumo de rutas.

**No incluye:** pantallas de Angular (solo se mencionan para el login), envío real de correos, notificaciones push ni chat.

> **Decisión vigente:** no se almacenan contraseñas. Ver [`ADR-001`](adr/ADR-001-autenticacion-magic-link.md).

---

<a id="programas"></a>

## 2. Programas necesarios

| Programa | Versión recomendada | Para qué | Cómo verificar |
|---|---|---|---|
| **Git** | 2.40+ | Clonar, ramas, commits | `git --version` |
| **Node.js** | 24 LTS (mínimo 20.19) | NestJS 11 y Angular 21 | `node -v` |
| **npm** | 10+ | Dependencias | `npm -v` |
| **PostgreSQL** | 15 – 18 | Base de datos | `psql --version` |
| **pgAdmin 4** | Incluido con PostgreSQL | Ejecutar el script y consultar | Abrir la app |
| **Nest CLI** | 11 | Generar módulos y servicios | `nest --version` |
| **Angular CLI** | 21 | Proyecto frontend | `ng version` |
| **Postman o Insomnia** | Última | Probar las rutas | Abrir la app |
| **Firebase CLI** | 13+ | Emulador de Authentication | `firebase --version` |
| **Java JDK** | 11+ | Requisito del emulador de Firebase | `java -version` |
| **VS Code** (opcional) | Última | Editor con ESLint y Prettier | — |
| **Docker** (opcional) | Última | Alternativa para levantar PostgreSQL | `docker --version` |

### Instalación de las CLI

```bash
npm install -g @nestjs/cli @angular/cli firebase-tools
```

> **Windows:** si `nest` o `ng` no se reconocen después de instalar, cierra y vuelve a abrir la terminal para que se recargue el `PATH`.

### Verificación rápida del entorno

```bash
node -v && npm -v && git --version && psql --version && nest --version && firebase --version && java -version
```

---

<a id="clonacion"></a>

## 3. Clonación de repositorios

La organización [`UTTCONNECT`](https://github.com/UTTCONNECT) tiene **tres repositorios**:

| Repositorio | Contenido | Rama por defecto |
|---|---|---|
| `DOCUMENTATION` | Documentación, MER y **scripts de base de datos** | `master` |
| `utt_connect-backend` | API NestJS | `master` |
| `utt_connect-frontend` | Aplicación Angular | `master` |

> Las migraciones `001_auth.sql` y `002_seed_permissions.sql` viven en **`DOCUMENTATION/db/migrations/`**. Por eso el backend y la documentación deben clonarse **lado a lado**.

### 3.1 Configurar Git (solo la primera vez)

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu.correo@utt.edu.mx"
```

### 3.2 Configurar llave SSH (recomendado)

```bash
ssh-keygen -t ed25519 -C "tu.correo@utt.edu.mx"
# Enter, Enter, Enter (o usa passphrase)
cat ~/.ssh/id_ed25519.pub
```

Copia la salida en GitHub → **Settings → SSH and GPG keys → New SSH key**. Verifica:

```bash
ssh -T git@github.com
```

### 3.3 Clonar los tres repositorios

```bash
mkdir UTT-Connect
cd UTT-Connect

git clone git@github.com:UTTCONNECT/DOCUMENTATION.git
git clone git@github.com:UTTCONNECT/utt_connect-backend.git
git clone git@github.com:UTTCONNECT/utt_connect-frontend.git
```

Si no usas SSH, cambia el prefijo por HTTPS:

```bash
git clone https://github.com/UTTCONNECT/utt_connect-backend.git
```

La estructura esperada es:

```
UTT-Connect/
├── DOCUMENTATION/
│   └── db/migrations/
│       ├── 001_auth.sql
│       └── 002_seed_permissions.sql
├── utt_connect-backend/
└── utt_connect-frontend/
```

### 3.4 Instalar dependencias

```bash
cd utt_connect-backend
npm install

cd ../utt_connect-frontend
npm install
```

---

<a id="ramas"></a>

## 4. Creación de ramas

**Regla:** nadie trabaja directo en `master`. Cada tarea vive en una rama corta y se integra por Pull Request.

### 4.1 Nomenclatura

| Prefijo | Cuándo usarlo | Ejemplo |
|---|---|---|
| `feature/` | Funcionalidad nueva | `feature/auth-entities` |
| `fix/` | Corrección de un error | `fix/auth-token-expired` |
| `docs/` | Documentación | `docs/guia-auth` |
| `test/` | Pruebas | `test/auth-e2e` |
| `chore/` | Configuración o dependencias | `chore/typeorm-setup` |

Formato: `prefijo/descripcion-corta-en-kebab-case`.

### 4.2 Crear la rama

```bash
# 1. Actualiza master
git checkout master
git pull origin master

# 2. Crea y cambia a tu rama
git checkout -b feature/auth-setup
```

### 4.3 Reglas del equipo

- Una rama = una tarea. No mezcles entidades con pruebas en la misma rama.
- Vida corta: **máximo 3 días**. Si tarda más, divide la tarea.
- Antes de pedir revisión, actualiza tu rama con `master`:

```bash
git fetch origin
git rebase origin/master
```

- Si el rebase genera conflictos, resuélvelos en tu rama y **nunca** hagas `push --force` sobre `master`.

### 4.4 Ramas sugeridas para este módulo

| Rama | Contenido |
|---|---|
| `feature/auth-setup` | Dependencias, `.env`, TypeORM, `main.ts` |
| `feature/auth-entities` | Entidades de las 12 tablas |
| `feature/auth-endpoints` | DTOs, servicios, controlador, guards |
| `feature/auth-audit` | `AuditService` y eventos |
| `test/auth-unit` | Pruebas unitarias |
| `test/auth-e2e` | Pruebas de integración |

---

<a id="commits"></a>

## 5. Cómo hacer commits

El proyecto usa **Conventional Commits** (ya definido en el README, sección 21).

### 5.1 Formato

```
<tipo>(<alcance>): <descripción en imperativo>
```

| Tipo | Uso |
|---|---|
| `feat` | Funcionalidad nueva |
| `fix` | Corrección de error |
| `docs` | Documentación |
| `test` | Pruebas |
| `refactor` | Cambio interno sin alterar comportamiento |
| `chore` | Dependencias, configuración, build |
| `style` | Formato, espacios, comas |

### 5.2 Ejemplos correctos

```bash
git commit -m "feat(auth): agregar endpoint para solicitar enlace magico"
git commit -m "feat(auth): validar id token de firebase"
git commit -m "fix(auth): rechazar correos fuera del dominio utt"
git commit -m "test(auth): cubrir creacion de usuario pendiente"
git commit -m "chore(deps): instalar typeorm y driver pg"
git commit -m "docs(auth): documentar variables de entorno"
```

### 5.3 Ejemplos incorrectos

```bash
git commit -m "cambios"                 # no dice qué
git commit -m "Fix login"               # mayúscula y sin alcance
git commit -m "feat: todo el modulo"    # commit gigante
```

### 5.4 Buenas prácticas

- **Un commit, una idea.** Si el mensaje necesita “y”, probablemente son dos commits.
- Usa `git add -p` para elegir qué fragmentos entran.
- No subas `.env`, credenciales ni `node_modules`.
- Revisa antes de confirmar:

```bash
git status
git diff --staged
```

- Mensaje en minúsculas, imperativo, máximo ~72 caracteres en la primera línea.

---

<a id="push"></a>

## 6. Push y Pull Request

### 6.1 Publicar la rama

```bash
git push -u origin feature/auth-setup
```

El `-u` solo se usa la primera vez; después basta `git push`.

### 6.2 Abrir el Pull Request

1. Entra al repositorio en GitHub. Aparecerá el aviso **“Compare & pull request”**.
2. Base: `master`. Compare: tu rama.
3. Título con el mismo formato del commit: `feat(auth): agregar entidades del modulo`.
4. Descripción con esta plantilla:

```markdown
## Qué cambia
- Se agregan las entidades de users, identities y magic links.

## Por qué
- Requisito: RF-04, RF-05 (autenticación con correo institucional).

## Cómo probarlo
1. npm run start:dev
2. GET /health → 200

## Checklist
- [ ] Compila sin errores
- [ ] Pasa el linter
- [ ] No incluye .env ni credenciales
```

5. Solicita revisión a **al menos un integrante** (regla del README).
6. Al aprobar, usa **Squash and merge** para dejar un solo commit en `master`.

### 6.3 Después del merge

```bash
git checkout master
git pull origin master
git branch -d feature/auth-setup
git push origin --delete feature/auth-setup
```

### 6.4 Si `master` avanzó mientras trabajabas

```bash
git fetch origin
git rebase origin/master
# resuelve conflictos si los hay
git add .
git rebase --continue
git push --force-with-lease
```

`--force-with-lease` solo sobre **tu rama**, nunca sobre `master`.

---

<a id="script-bd"></a>

## 7. Script de base de datos

Los scripts están en el repositorio de documentación:

```
DOCUMENTATION/db/migrations/
├── 001_auth.sql            ← esquema completo (no idempotente)
├── 002_seed_permissions.sql ← permisos y roles (idempotente)
└── README.md
```

### 7.1 Qué crea `001_auth.sql`

| Grupo | Objetos |
|---|---|
| Extensiones | `pgcrypto`, `citext` |
| Catálogos | `user_statuses`, `identity_providers`, `magic_link_statuses`, `audit_event_types` |
| Identidad | `users`, `user_identities` |
| Autorización | `roles`, `permissions`, `role_permissions`, `user_roles` |
| Autenticación | `magic_link_requests` |
| Auditoría | `audit_events` (particionada) + `audit_events_default` |
| Lógica | 3 triggers (`updated_at` ×2, inmutabilidad del correo) |
| Rendimiento | 15 índices explícitos (parciales incluidos) |

### 7.2 Qué crea `002_seed_permissions.sql`

- **10 permisos** del MVP.
- Asignación: `lector` → 1, `departamento` → 5, `administrador` → 10.
- Es **idempotente**: se puede volver a ejecutar sin duplicar.

> **Advertencia:** `001` no es idempotente. Si se ejecuta dos veces fallará porque las tablas ya existen. Eso es lo esperado: se aplica **una sola vez**.

---

<a id="ejecutar-script"></a>

## 8. Cómo ejecutar el script

### 8.1 Requisitos

- PostgreSQL encendido.
- Usuario con permiso para `CREATE EXTENSION` (normalmente `postgres`).
- La base `utt_connect` creada y vacía.

### 8.2 Opción A — pgAdmin 4 (gráfica)

1. Abre **pgAdmin** y conéctate al servidor local.
2. Clic derecho en **Databases → Create → Database…**
   - Name: `utt_connect`
   - Owner: `postgres`
   - Save.
3. Selecciona `utt_connect` y abre **Tools → Query Tool** (`Alt + Shift + Q`).
4. Abre el archivo: **File → Open File** → `DOCUMENTATION/db/migrations/001_auth.sql`.
5. Ejecuta con **F5** (o el botón ▶).
6. Revisa la pestaña **Messages**: debe terminar en `COMMIT` sin errores en rojo.
7. Repite los pasos 4–6 con `002_seed_permissions.sql`.

### 8.3 Opción B — `psql` (terminal)

```powershell
# PowerShell (Windows)
$env:PGPASSWORD = "tu_password"
$PSQL = "C:\Program Files\PostgreSQL\18\bin\psql.exe"

# 1. Crear la base (si no existe)
& $PSQL -U postgres -h localhost -d postgres -c "CREATE DATABASE utt_connect;"

# 2. Aplicar las migraciones en orden
& $PSQL -U postgres -h localhost -d utt_connect -v ON_ERROR_STOP=1 -f "..\DOCUMENTATION\db\migrations\001_auth.sql"
& $PSQL -U postgres -h localhost -d utt_connect -v ON_ERROR_STOP=1 -f "..\DOCUMENTATION\db\migrations\002_seed_permissions.sql"
```

```bash
# Bash / macOS / Linux
export PGPASSWORD="tu_password"
psql -U postgres -h localhost -d postgres -c "CREATE DATABASE utt_connect;"
psql -U postgres -h localhost -d utt_connect -v ON_ERROR_STOP=1 -f ../DOCUMENTATION/db/migrations/001_auth.sql
psql -U postgres -h localhost -d utt_connect -v ON_ERROR_STOP=1 -f ../DOCUMENTATION/db/migrations/002_seed_permissions.sql
```

`-v ON_ERROR_STOP=1` hace que psql se detenga en el primer error, en lugar de continuar y dejar la base a medias.

### 8.4 Verificar que quedó bien

```sql
-- 12 tablas del modelo + 1 partición
SELECT count(*) FROM pg_tables WHERE schemaname = 'public';   -- 13

-- Debe ser 10
SELECT count(*) FROM permissions;

-- administrador 10 · departamento 5 · lector 1
SELECT r.code, count(rp.permission_id) AS permisos
FROM roles r
LEFT JOIN role_permissions rp ON rp.role_id = r.id
GROUP BY r.code
ORDER BY r.code;

-- 3 triggers
SELECT tgname FROM pg_trigger WHERE NOT tgisinternal;
```

### 8.5 Si necesitas empezar de cero

```sql
DROP DATABASE utt_connect;
CREATE DATABASE utt_connect;
```

Luego vuelve a aplicar `001` y `002`. **No** intentes “arreglar” una migración a medias: recrea la base.

---

<a id="preparar-nest"></a>

## 9. Preparar el proyecto NestJS

### 9.1 Instalar dependencias

```bash
cd utt_connect-backend

# Acceso a datos
npm install @nestjs/typeorm typeorm pg

# Configuración y validación
npm install @nestjs/config class-validator class-transformer

# Autenticación
npm install @nestjs/jwt firebase-admin

# Límite de solicitudes (anti-abuso del magic link)
npm install @nestjs/throttler
```

Verifica que `package.json` incluya `@nestjs/typeorm`, `typeorm`, `pg`, `@nestjs/config`, `class-validator`, `class-transformer`, `@nestjs/jwt`, `firebase-admin` y `@nestjs/throttler`.

### 9.2 Crear `.env` y `.env.example`

`.env` **no se sube al repositorio**. `.env.example` sí, con valores falsos.

```dotenv
# .env.example
NODE_ENV=development
PORT=3000

# Base de datos
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=cambia_esto
DB_NAME=utt_connect

# JWT propio de la API
JWT_SECRET=cambia_esto_por_una_cadena_larga_y_aleatoria
JWT_EXPIRES_IN=1h

# Firebase (emulador)
FIREBASE_PROJECT_ID=demo-utt-connect
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099

# Enlaces
FRONTEND_URL=http://localhost:4200
MAGIC_LINK_TTL_MINUTES=15
```

Copia el archivo y ajusta los valores:

```bash
cp .env.example .env
```

Confirma que `.env` esté ignorado:

```bash
git check-ignore -v .env
```

Si no aparece, agrégalo a `.gitignore`.

> **Genera un secreto real** (no uses el de ejemplo):
>
> ```bash
> node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
> ```

### 9.3 Configurar TypeORM

En `src/app.module.ts`:

```ts
import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { HealthController } from './health/health.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),

    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: 'postgres',
        host: config.get<string>('DB_HOST', 'localhost'),
        port: Number(config.get('DB_PORT', 5432)),
        username: config.get<string>('DB_USER'),
        password: config.get<string>('DB_PASSWORD'),
        database: config.get<string>('DB_NAME'),
        autoLoadEntities: true,
        synchronize: false, // NUNCA true: el esquema lo manejan los .sql
        logging: ['error', 'warn'],
      }),
    }),

    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 30 }]),
    AuthModule,
  ],
  controllers: [HealthController],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
  ],
})
export class AppModule {}
```

> **Regla de oro:** `synchronize: false`. Si lo pones en `true`, TypeORM intentará modificar tus tablas y puede romper los `CHECK`, triggers y la partición de auditoría.

### 9.4 Ajustar `src/main.ts`

```ts
import { ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.enableCors({
    origin: config.get<string>('FRONTEND_URL', 'http://localhost:4200'),
  });

  const port = Number(config.get('PORT', 3000));
  await app.listen(port);
  console.log(`API en http://localhost:${port}`);
}

bootstrap();
```

### 9.5 Endpoint de salud

Crea `src/health/health.controller.ts`:

```ts
import { Controller, Get } from '@nestjs/common';
import { DataSource } from 'typeorm';
import { Public } from '../common/decorators/public.decorator';

@Controller('health')
export class HealthController {
  constructor(private readonly dataSource: DataSource) {}

  @Public()
  @Get()
  async check() {
    await this.dataSource.query('SELECT 1');
    return { status: 'ok', database: 'up', timestamp: new Date().toISOString() };
  }
}
```

Regístralo en `AppModule` (`controllers: [HealthController]`).

---

<a id="estructura"></a>

## 10. Entities, DTOs, Services, Controllers, Module y Specs

### 10.1 Estructura de carpetas

```
src/
├── auth/
│   ├── dto/
│   │   ├── request-magic-link.dto.ts
│   │   └── verify-magic-link.dto.ts
│   ├── entities/
│   │   ├── identity-provider.entity.ts
│   │   ├── magic-link-request.entity.ts
│   │   ├── magic-link-status.entity.ts
│   │   └── user-identity.entity.ts
│   ├── auth.controller.ts
│   ├── auth.service.ts
│   ├── auth.module.ts
│   ├── firebase.service.ts
│   └── auth.service.spec.ts
├── users/
│   └── entities/
│       ├── user.entity.ts
│       └── user-status.entity.ts
├── rbac/
│   ├── entities/
│   │   ├── permission.entity.ts
│   │   ├── role.entity.ts
│   │   ├── role-permission.entity.ts
│   │   └── user-role.entity.ts
│   └── rbac.service.ts
├── audit/
│   ├── entities/
│   │   ├── audit-event.entity.ts
│   │   └── audit-event-type.entity.ts
│   └── audit.service.ts
└── common/
    ├── decorators/
    │   ├── current-user.decorator.ts
    │   ├── permissions.decorator.ts
    │   └── public.decorator.ts
    └── guards/
        ├── jwt-auth.guard.ts
        └── permissions.guard.ts
```

Puedes generar los esqueletos con el CLI:

```bash
nest g module auth
nest g controller auth
nest g service auth
nest g service auth/firebase --flat
```

Para las entidades conviene crearlas a mano: el CLI no aporta mucho y hay que ajustar decoradores.

### 10.2 Entidades (TypeORM)

> **Importante:** todas usan `@Entity({ name: '...' })` con el nombre exacto de la tabla y `name:` en cada columna para respetar `snake_case`. Si te falta un `name`, TypeORM buscará `displayName` en lugar de `display_name` y fallará.

#### `users`

```ts
import {
  Column, CreateDateColumn, DeleteDateColumn, Entity,
  PrimaryGeneratedColumn, UpdateDateColumn,
} from 'typeorm';

@Entity({ name: 'users' })
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ type: 'citext', unique: true })
  email: string;

  @Column({ name: 'display_name', type: 'varchar', length: 160, nullable: true })
  displayName: string | null;

  @Column({ name: 'status_code', type: 'varchar', length: 32, default: 'pending' })
  statusCode: string;

  @Column({ name: 'email_verified_at', type: 'timestamptz', nullable: true })
  emailVerifiedAt: Date | null;

  @Column({ name: 'last_login_at', type: 'timestamptz', nullable: true })
  lastLoginAt: Date | null;

  @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
  updatedAt: Date;

  @DeleteDateColumn({ name: 'deleted_at', type: 'timestamptz', nullable: true })
  deletedAt: Date | null;
}
```

#### `magic_link_requests`

```ts
import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn } from 'typeorm';

@Entity({ name: 'magic_link_requests' })
export class MagicLinkRequest {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id', type: 'uuid', nullable: true })
  userId: string | null;

  @Column({ type: 'citext' })
  email: string;

  @Column({ name: 'status_code', type: 'varchar', length: 32, default: 'requested' })
  statusCode: string;

  @Column({ name: 'correlation_id', type: 'uuid', unique: true })
  correlationId: string;

  @Column({ name: 'continue_url', type: 'text' })
  continueUrl: string;

  @Column({ name: 'client_nonce_hash', type: 'bytea', nullable: true })
  clientNonceHash: Buffer | null;

  @Column({ name: 'requested_ip', type: 'inet', nullable: true })
  requestedIp: string | null;

  @Column({ name: 'user_agent', type: 'text', nullable: true })
  userAgent: string | null;

  @Column({ name: 'firebase_event_id', type: 'varchar', length: 255, nullable: true })
  firebaseEventId: string | null;

  @CreateDateColumn({ name: 'requested_at', type: 'timestamptz' })
  requestedAt: Date;

  @Column({ name: 'sent_at', type: 'timestamptz', nullable: true })
  sentAt: Date | null;

  @Column({ name: 'expires_at', type: 'timestamptz' })
  expiresAt: Date;

  @Column({ name: 'consumed_at', type: 'timestamptz', nullable: true })
  consumedAt: Date | null;

  @Column({ name: 'failure_code', type: 'varchar', length: 100, nullable: true })
  failureCode: string | null;

  @Column({ name: 'failure_detail', type: 'varchar', length: 500, nullable: true })
  failureDetail: string | null;

  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  metadata: Record<string, unknown>;
}
```

#### `audit_events` (clave primaria compuesta)

```ts
import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity({ name: 'audit_events' })
export class AuditEvent {
  @PrimaryColumn({ name: 'occurred_at', type: 'timestamptz', default: () => 'now()' })
  occurredAt: Date;

  @PrimaryColumn({ type: 'uuid', default: () => 'gen_random_uuid()' })
  id: string;

  @Column({ name: 'event_type_code', type: 'varchar', length: 80 })
  eventTypeCode: string;

  @Column({ name: 'actor_user_id', type: 'uuid', nullable: true })
  actorUserId: string | null;

  @Column({ name: 'subject_user_id', type: 'uuid', nullable: true })
  subjectUserId: string | null;

  @Column({ name: 'magic_link_request_id', type: 'uuid', nullable: true })
  magicLinkRequestId: string | null;

  @Column({ name: 'correlation_id', type: 'uuid', nullable: true })
  correlationId: string | null;

  @Column({ name: 'resource_type', type: 'varchar', length: 80, nullable: true })
  resourceType: string | null;

  @Column({ name: 'resource_id', type: 'varchar', length: 255, nullable: true })
  resourceId: string | null;

  @Column({ name: 'source_ip', type: 'inet', nullable: true })
  sourceIp: string | null;

  @Column({ name: 'user_agent', type: 'text', nullable: true })
  userAgent: string | null;

  @Column({ type: 'boolean' })
  succeeded: boolean;

  @Column({ type: 'jsonb', default: () => "'{}'::jsonb" })
  payload: Record<string, unknown>;
}
```

#### `role_permissions` (clave compuesta)

```ts
import { CreateDateColumn, Entity, PrimaryColumn } from 'typeorm';

@Entity({ name: 'role_permissions' })
export class RolePermission {
  @PrimaryColumn({ name: 'role_id', type: 'uuid' })
  roleId: string;

  @PrimaryColumn({ name: 'permission_id', type: 'uuid' })
  permissionId: string;

  @CreateDateColumn({ name: 'granted_at', type: 'timestamptz' })
  grantedAt: Date;
}
```

#### Resto de entidades

| Entidad | Tabla | Llave | Columnas clave |
|---|---|---|---|
| `UserStatus` | `user_statuses` | `code` | `description` |
| `IdentityProvider` | `identity_providers` | `id` (identity) | `code`, `description` |
| `UserIdentity` | `user_identities` | `id` | `user_id`, `provider_id`, `provider_subject`, `provider_email`, `claims_snapshot` (jsonb), `linked_at`, `last_verified_at` |
| `MagicLinkStatus` | `magic_link_statuses` | `code` | `description`, `is_terminal` |
| `Role` | `roles` | `id` | `code`, `name`, `description`, `is_system`, `created_at`, `updated_at` |
| `Permission` | `permissions` | `id` | `code`, `description`, `created_at` |
| `UserRole` | `user_roles` | `(user_id, role_id)` | `granted_by`, `granted_at`, `expires_at` |
| `AuditEventType` | `audit_event_types` | `code` | `description` |

`IdentityProvider.id` es `smallint GENERATED ALWAYS AS IDENTITY`: en TypeORM se marca así:

```ts
@PrimaryGeneratedColumn('increment', { type: 'smallint' })
id: number;
```

### 10.3 DTOs

```ts
// src/auth/dto/request-magic-link.dto.ts
import { Transform } from 'class-transformer';
import { IsEmail, Matches } from 'class-validator';

export class RequestMagicLinkDto {
  @Transform(({ value }) =>
    typeof value === 'string' ? value.trim().toLowerCase() : value,
  )
  @IsEmail({}, { message: 'El correo no tiene un formato válido' })
  @Matches(/@utt\.edu\.mx$/i, {
    message: 'Solo se aceptan correos institucionales @utt.edu.mx',
  })
  email: string;
}
```

```ts
// src/auth/dto/verify-magic-link.dto.ts
import { IsNotEmpty, IsString } from 'class-validator';

export class VerifyMagicLinkDto {
  @IsString()
  @IsNotEmpty()
  idToken: string;
}
```

> El DTO valida el dominio **antes** de tocar la base. Es la primera barrera; el `CHECK` de PostgreSQL es la segunda.

### 10.4 Servicios

#### `FirebaseService`

```ts
import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { App, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private app: App;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    if (getApps().length > 0) {
      this.app = getApps()[0];
      return;
    }
    this.app = initializeApp({
      projectId: this.config.get<string>('FIREBASE_PROJECT_ID'),
    });
  }

  generateSignInLink(email: string, continueUrl: string): Promise<string> {
    return getAuth(this.app).generateSignInWithEmailLink(email, {
      url: continueUrl,
      handleCodeInApp: true,
    });
  }

  verifyIdToken(idToken: string) {
    return getAuth(this.app).verifyIdToken(idToken);
  }
}
```

> El emulador se activa solo con la variable `FIREBASE_AUTH_EMULATOR_HOST`. El SDK la lee de `process.env`, por eso debe estar en `.env` **antes** de `initializeApp`.
>
> **En producción** el emulador no existe: hay que crear una cuenta de servicio en Firebase Console (Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada) y apuntar `GOOGLE_APPLICATION_CREDENTIALS` al JSON. Nunca subas ese archivo al repositorio.

#### `AuditService`

```ts
import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditEvent } from '../entities/audit-event.entity';

export interface AuditInput {
  eventTypeCode: string;
  actorUserId?: string | null;
  subjectUserId?: string | null;
  magicLinkRequestId?: string | null;
  correlationId?: string | null;
  resourceType?: string | null;
  resourceId?: string | null;
  sourceIp?: string | null;
  userAgent?: string | null;
  succeeded: boolean;
  payload?: Record<string, unknown>;
}

@Injectable()
export class AuditService {
  private readonly logger = new Logger(AuditService.name);

  constructor(
    @InjectRepository(AuditEvent)
    private readonly repo: Repository<AuditEvent>,
  ) {}

  async record(input: AuditInput): Promise<void> {
    try {
      await this.repo.insert({
        eventTypeCode: input.eventTypeCode,
        actorUserId: input.actorUserId ?? null,
        subjectUserId: input.subjectUserId ?? null,
        magicLinkRequestId: input.magicLinkRequestId ?? null,
        correlationId: input.correlationId ?? null,
        resourceType: input.resourceType ?? null,
        resourceId: input.resourceId ?? null,
        sourceIp: input.sourceIp ?? null,
        userAgent: input.userAgent ?? null,
        succeeded: input.succeeded,
        payload: input.payload ?? {},
      });
    } catch (error) {
      // La auditoría nunca debe tumbar el flujo principal.
      this.logger.error('No se pudo registrar el evento de auditoría', error);
    }
  }
}
```

#### `RbacService`

```ts
import { Injectable } from '@nestjs/common';
import { DataSource } from 'typeorm';

@Injectable()
export class RbacService {
  constructor(private readonly dataSource: DataSource) {}

  async getRoles(userId: string): Promise<string[]> {
    const rows = await this.dataSource.query<{ code: string }[]>(
      `SELECT r.code
         FROM user_roles ur
         JOIN roles r ON r.id = ur.role_id
        WHERE ur.user_id = $1
          AND (ur.expires_at IS NULL OR ur.expires_at > now())
        ORDER BY r.code`,
      [userId],
    );
    return rows.map((r) => r.code);
  }

  async getEffectivePermissions(userId: string): Promise<string[]> {
    const rows = await this.dataSource.query<{ code: string }[]>(
      `SELECT DISTINCT p.code
         FROM user_roles ur
         JOIN role_permissions rp ON rp.role_id = ur.role_id
         JOIN permissions p ON p.id = rp.permission_id
        WHERE ur.user_id = $1
          AND (ur.expires_at IS NULL OR ur.expires_at > now())
        ORDER BY p.code`,
      [userId],
    );
    return rows.map((r) => r.code);
  }
}
```

#### `AuthService`

```ts
import {
  ForbiddenException, Injectable, UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'node:crypto';
import { In, IsNull, Repository } from 'typeorm';
import { AuditService } from '../audit/audit.service';
import { RbacService } from '../rbac/rbac.service';
import { RequestMagicLinkDto } from './dto/request-magic-link.dto';
import { VerifyMagicLinkDto } from './dto/verify-magic-link.dto';
import { IdentityProvider } from './entities/identity-provider.entity';
import { MagicLinkRequest } from './entities/magic-link-request.entity';
import { UserIdentity } from './entities/user-identity.entity';
import { User } from '../users/entities/user.entity';
import { FirebaseService } from './firebase.service';

export interface RequestContext {
  ip: string | null;
  userAgent: string | null;
}

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(UserIdentity) private readonly identities: Repository<UserIdentity>,
    @InjectRepository(IdentityProvider) private readonly providers: Repository<IdentityProvider>,
    @InjectRepository(MagicLinkRequest) private readonly links: Repository<MagicLinkRequest>,
    private readonly firebase: FirebaseService,
    private readonly rbac: RbacService,
    private readonly audit: AuditService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async requestMagicLink(dto: RequestMagicLinkDto, ctx: RequestContext) {
    const correlationId = randomUUID();
    const ttl = Number(this.config.get('MAGIC_LINK_TTL_MINUTES', 15));
    const continueUrl = `${this.config.get<string>('FRONTEND_URL')}/auth/callback`;

    const request = await this.links.save(
      this.links.create({
        email: dto.email,
        statusCode: 'requested',
        correlationId,
        continueUrl,
        requestedIp: ctx.ip,
        userAgent: ctx.userAgent,
        expiresAt: new Date(Date.now() + ttl * 60_000),
        metadata: {},
      }),
    );

    await this.audit.record({
      eventTypeCode: 'auth.magic_link_requested',
      magicLinkRequestId: request.id,
      correlationId,
      sourceIp: ctx.ip,
      userAgent: ctx.userAgent,
      succeeded: true,
      payload: { email: dto.email },
    });

    try {
      const link = await this.firebase.generateSignInLink(dto.email, continueUrl);

      await this.links.update(request.id, {
        statusCode: 'sent',
        sentAt: new Date(),
      });

      await this.audit.record({
        eventTypeCode: 'auth.magic_link_sent',
        magicLinkRequestId: request.id,
        correlationId,
        sourceIp: ctx.ip,
        userAgent: ctx.userAgent,
        succeeded: true,
      });

      return {
        correlationId,
        expiresAt: request.expiresAt,
        // Solo en desarrollo: permite probar sin correo real.
        devLink:
          this.config.get<string>('NODE_ENV') !== 'production' ? link : undefined,
      };
    } catch (error) {
      await this.links.update(request.id, {
        statusCode: 'failed',
        failureCode: 'FIREBASE_SEND_FAILED',
        failureDetail: String(error).slice(0, 500),
      });
      await this.audit.record({
        eventTypeCode: 'auth.magic_link_requested',
        magicLinkRequestId: request.id,
        correlationId,
        sourceIp: ctx.ip,
        userAgent: ctx.userAgent,
        succeeded: false,
        payload: { reason: 'firebase_send_failed' },
      });
      // No se revela el error al cliente (evita enumeración).
      return { correlationId, expiresAt: request.expiresAt };
    }
  }

  async verify(dto: VerifyMagicLinkDto, ctx: RequestContext) {
    let decoded;
    try {
      decoded = await this.firebase.verifyIdToken(dto.idToken);
    } catch {
      await this.audit.record({
        eventTypeCode: 'auth.login_failed',
        sourceIp: ctx.ip,
        userAgent: ctx.userAgent,
        succeeded: false,
        payload: { reason: 'invalid_token' },
      });
      throw new UnauthorizedException('Token inválido o expirado');
    }

    const email = (decoded.email ?? '').toLowerCase();
    if (!email.endsWith('@utt.edu.mx')) {
      throw new ForbiddenException('Solo se aceptan correos @utt.edu.mx');
    }
    if (!decoded.email_verified) {
      throw new ForbiddenException('El correo todavía no está verificado');
    }

    const provider = await this.providers.findOneByOrFail({ code: 'firebase' });

    const identity = await this.identities.findOneBy({
      providerId: provider.id,
      providerSubject: decoded.uid,
    });

    let user: User;

    if (identity) {
      user = await this.users.findOneByOrFail({ id: identity.userId });
    } else {
      user = await this.users.findOneBy({ email });

      if (!user) {
        user = await this.users.save(
          this.users.create({
            email,
            displayName: decoded.name ?? null,
            statusCode: 'pending',
          }),
        );
        await this.audit.record({
          eventTypeCode: 'user.created',
          subjectUserId: user.id,
          sourceIp: ctx.ip,
          userAgent: ctx.userAgent,
          succeeded: true,
          payload: { email },
        });
      }

      await this.identities.save(
        this.identities.create({
          userId: user.id,
          providerId: provider.id,
          providerSubject: decoded.uid,
          providerEmail: email,
          claimsSnapshot: decoded as unknown as Record<string, unknown>,
          lastVerifiedAt: new Date(),
        }),
      );
    }

    const now = new Date();
    const nextStatus = user.statusCode === 'pending' ? 'active' : user.statusCode;
    const verifiedAt = user.emailVerifiedAt ?? now;

    await this.users.update(user.id, {
      emailVerifiedAt: verifiedAt,
      lastLoginAt: now,
      statusCode: nextStatus,
    });

    // Cierra la solicitud pendiente más reciente, si existe.
    const pending = await this.links.findOne({
      where: { email, statusCode: In(['requested', 'sent']), consumedAt: IsNull() },
      order: { requestedAt: 'DESC' },
    });

    if (pending && pending.expiresAt > now) {
      await this.links.update(pending.id, {
        statusCode: 'consumed',
        consumedAt: now,
      });
    } else if (pending) {
      await this.links.update(pending.id, { statusCode: 'expired' });
    }

    const roles = await this.rbac.getRoles(user.id);
    const permissions = await this.rbac.getEffectivePermissions(user.id);

    const accessToken = await this.jwt.signAsync({
      sub: user.id,
      email: user.email,
      roles,
    });

    await this.audit.record({
      eventTypeCode: 'auth.login_succeeded',
      actorUserId: user.id,
      subjectUserId: user.id,
      magicLinkRequestId: pending?.id ?? null,
      correlationId: pending?.correlationId ?? null,
      sourceIp: ctx.ip,
      userAgent: ctx.userAgent,
      succeeded: true,
      payload: { method: 'magic_link' },
    });

    return {
      accessToken,
      user: {
        id: user.id,
        email: user.email,
        displayName: user.displayName,
        status: nextStatus,
      },
      roles,
      permissions,
    };
  }

  async me(userId: string) {
    const user = await this.users.findOneBy({ id: userId });
    if (!user) throw new UnauthorizedException();

    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      status: user.statusCode,
      emailVerifiedAt: user.emailVerifiedAt,
      roles: await this.rbac.getRoles(user.id),
      permissions: await this.rbac.getEffectivePermissions(user.id),
    };
  }
}
```

### 10.5 Guards y decoradores

```ts
// src/common/decorators/public.decorator.ts
import { SetMetadata } from '@nestjs/common';
export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
```

```ts
// src/common/decorators/permissions.decorator.ts
import { SetMetadata } from '@nestjs/common';
export const PERMISSIONS_KEY = 'permissions';
export const RequirePermissions = (...permissions: string[]) =>
  SetMetadata(PERMISSIONS_KEY, permissions);
```

```ts
// src/common/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface JwtPayload {
  sub: string;
  email: string;
  roles: string[];
}

export const CurrentUser = createParamDecorator(
  (data: keyof JwtPayload | undefined, ctx: ExecutionContext) => {
    const req = ctx.switchToHttp().getRequest();
    return data ? req.user?.[data] : req.user;
  },
);
```

```ts
// src/common/guards/jwt-auth.guard.ts
import {
  CanActivate, ExecutionContext, Injectable, UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const req = context.switchToHttp().getRequest();
    const [type, token] = (req.headers.authorization ?? '').split(' ');

    if (type !== 'Bearer' || !token) {
      throw new UnauthorizedException('Falta el token');
    }

    try {
      req.user = await this.jwt.verifyAsync(token);
      return true;
    } catch {
      throw new UnauthorizedException('Token inválido o expirado');
    }
  }
}
```

```ts
// src/common/guards/permissions.guard.ts
import {
  CanActivate, ExecutionContext, ForbiddenException, Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { RbacService } from '../../rbac/rbac.service';
import { PERMISSIONS_KEY } from '../decorators/permissions.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly rbac: RbacService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<string[]>(PERMISSIONS_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required?.length) return true;

    const req = context.switchToHttp().getRequest();
    const permissions = await this.rbac.getEffectivePermissions(req.user.sub);

    if (!required.every((p) => permissions.includes(p))) {
      throw new ForbiddenException('No tienes permisos para esta acción');
    }
    return true;
  }
}
```

> `JwtAuthGuard` se registra globalmente en `AppModule` con `APP_GUARD`. `PermissionsGuard` se aplica por ruta con `@UseGuards(PermissionsGuard)` y debe estar en `providers` del módulo donde se use.

### 10.6 Controlador

```ts
// src/auth/auth.controller.ts
import {
  Body, Controller, Get, HttpCode, Post, Req, UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';
import { CurrentUser, JwtPayload } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { AuthService, RequestContext } from './auth.service';
import { RequestMagicLinkDto } from './dto/request-magic-link.dto';
import { VerifyMagicLinkDto } from './dto/verify-magic-link.dto';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Post('magic-link')
  @HttpCode(202)
  requestMagicLink(@Body() dto: RequestMagicLinkDto, @Req() req: Request) {
    return this.auth.requestMagicLink(dto, this.contextOf(req));
  }

  @Public()
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Post('verify')
  @HttpCode(200)
  verify(@Body() dto: VerifyMagicLinkDto, @Req() req: Request) {
    return this.auth.verify(dto, this.contextOf(req));
  }

  @Get('me')
  me(@CurrentUser() user: JwtPayload) {
    return this.auth.me(user.sub);
  }

  private contextOf(req: Request): RequestContext {
    return {
      ip: req.ip ?? null,
      userAgent: req.headers['user-agent'] ?? null,
    };
  }
}
```

### 10.7 Módulo

```ts
// src/auth/auth.module.ts
import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { TypeOrmModule } from '@nestjs/typeorm';
import { AuditEvent } from '../audit/entities/audit-event.entity';
import { AuditService } from '../audit/audit.service';
import { RbacService } from '../rbac/rbac.service';
import { User } from '../users/entities/user.entity';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { IdentityProvider } from './entities/identity-provider.entity';
import { MagicLinkRequest } from './entities/magic-link-request.entity';
import { UserIdentity } from './entities/user-identity.entity';
import { FirebaseService } from './firebase.service';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      User,
      UserIdentity,
      IdentityProvider,
      MagicLinkRequest,
      AuditEvent,
    ]),
    JwtModule.registerAsync({
      global: true,
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.getOrThrow<string>('JWT_SECRET'),
        signOptions: { expiresIn: config.get<string>('JWT_EXPIRES_IN', '1h') },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, FirebaseService, RbacService, AuditService],
  exports: [AuthService, RbacService, AuditService],
})
export class AuthModule {}
```

### 10.8 Specs (opcional, pero recomendado)

```ts
// src/auth/auth.service.spec.ts
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AuditService } from '../audit/audit.service';
import { RbacService } from '../rbac/rbac.service';
import { User } from '../users/entities/user.entity';
import { AuthService } from './auth.service';
import { IdentityProvider } from './entities/identity-provider.entity';
import { MagicLinkRequest } from './entities/magic-link-request.entity';
import { UserIdentity } from './entities/user-identity.entity';
import { FirebaseService } from './firebase.service';

describe('AuthService', () => {
  let service: AuthService;

  const users = {
    findOneBy: jest.fn(),
    findOneByOrFail: jest.fn(),
    save: jest.fn(),
    create: jest.fn((v) => v),
    update: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();

    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: getRepositoryToken(User), useValue: users },
        { provide: getRepositoryToken(UserIdentity), useValue: {} },
        { provide: getRepositoryToken(IdentityProvider), useValue: {} },
        { provide: getRepositoryToken(MagicLinkRequest), useValue: {} },
        { provide: FirebaseService, useValue: {} },
        { provide: RbacService, useValue: {} },
        { provide: AuditService, useValue: { record: jest.fn() } },
        { provide: JwtService, useValue: { signAsync: jest.fn() } },
        { provide: ConfigService, useValue: { get: jest.fn() } },
      ],
    }).compile();

    service = moduleRef.get(AuthService);
  });

  it('debería estar definido', () => {
    expect(service).toBeDefined();
  });
});
```

> El ejemplo anterior es un esqueleto. Complétalo con casos reales: usuario nuevo, usuario existente, token inválido y dominio no permitido. Los `useValue` de los repositorios deben exponer los métodos que usa el servicio (`findOneBy`, `save`, `create`, `update`, etc.).

---

<a id="empezar"></a>

## 11. Cómo empezar: levantar y verificar

### 11.1 Levantar el emulador de Firebase

El emulador no necesita cuenta de Firebase si el proyecto empieza con `demo-`. Crea una carpeta y un `firebase.json` mínimo:

```bash
mkdir firebase-emulator && cd firebase-emulator
```

```json
{
  "emulators": {
    "auth": { "port": 9099 },
    "ui": { "enabled": true, "port": 4000 },
    "singleProjectMode": true
  }
}
```

Guárdalo como `firebase.json` y arranca:

```bash
firebase emulators:start --only auth --project demo-utt-connect
```

Debe mostrar:

```
✔  All emulators ready! It is now safe to connect your app.
│ Authentication │ 127.0.0.1:9099 │ http://127.0.0.1:4000 │
```

> La primera ejecución descarga el emulador (necesita internet y Java 11+).
> La consola del emulador está en `http://127.0.0.1:4000`.
>
> En el emulador, el acceso por enlace ya está disponible. En un proyecto real hay que habilitarlo en **Authentication → Sign-in method → Email/Password → Email link (passwordless)** y autorizar el dominio de `FRONTEND_URL`.

### 11.2 Levantar NestJS

```bash
cd utt_connect-backend
npm run start:dev
```

Salida esperada:

```
[Nest] LOG [NestApplication] Nest application successfully started
API en http://localhost:3000
```

### 11.3 Verificar

```bash
curl http://localhost:3000/health
```

```json
{ "status": "ok", "database": "up", "timestamp": "2026-11-11T..." }
```

Si `/health` falla, revisa `.env`, que PostgreSQL esté encendido y que la base `utt_connect` exista.

---

<a id="testear"></a>

## 12. Testear

### 12.1 Pruebas unitarias

```bash
npm run test
npm run test:cov
```

Casos mínimos para `AuthService`:

| Caso | Resultado esperado |
|---|---|
| Correo con dominio distinto | `ForbiddenException` |
| Token inválido | `UnauthorizedException` |
| Primera autenticación | Crea `users` en `pending` y luego `active` |
| Segunda autenticación | Reutiliza el usuario, no duplica |
| Solicitud pendiente | Pasa a `consumed` con `consumed_at` |
| Evento de login | Se escribe en `audit_events` |

### 12.2 Pruebas de integración (e2e)

```bash
npm run test:e2e
```

Ejemplo mínimo:

```ts
// test/auth.e2e-spec.ts
import { Test } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Auth (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /auth/me sin token → 401', () => {
    return request(app.getHttpServer()).get('/auth/me').expect(401);
  });

  it('POST /auth/magic-link con dominio inválido → 400', () => {
    return request(app.getHttpServer())
      .post('/auth/magic-link')
      .send({ email: 'ana@gmail.com' })
      .expect(400);
  });
});
```

> Las pruebas e2e necesitan una base de datos de prueba. Crea `utt_connect_test`, aplica `001` y `002`, y apunta `DB_NAME` a ella. Nunca corras e2e contra la base de desarrollo.

### 12.3 Pruebas manuales

Usa Postman o Insomnia con la colección de la sección 13. Verifica al menos:

- [ ] `POST /auth/magic-link` responde `202`.
- [ ] `POST /auth/magic-link` con `gmail.com` responde `400`.
- [ ] `POST /auth/verify` con token válido responde `200` y devuelve `accessToken`.
- [ ] `GET /auth/me` con el token responde `200` con roles y permisos.
- [ ] `GET /auth/me` sin token responde `401`.
- [ ] Un usuario sin rol de administrador recibe `403` en una ruta protegida.

---

<a id="consumir"></a>

## 13. Consumir rutas

### 13.1 Variables de entorno para Postman

Crea un entorno con:

| Variable | Valor |
|---|---|
| `baseUrl` | `http://localhost:3000` |
| `token` | (se llena automáticamente) |

En la petición `POST /auth/verify`, pestaña **Tests**:

```js
pm.environment.set('token', pm.response.json().accessToken);
```

### 13.2 Obtener un token del emulador (prueba rápida)

El emulador permite crear un usuario y devolver un `idToken` sin enviar correos:

```bash
curl -s -X POST \
  "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key" \
  -H "Content-Type: application/json" \
  -d '{"email":"ana@utt.edu.mx","password":"Password123!","returnSecureToken":true}'
```

Copia el `idToken` de la respuesta.

### 13.3 Solicitar el enlace

```bash
curl -X POST http://localhost:3000/auth/magic-link \
  -H "Content-Type: application/json" \
  -d '{"email":"ana@utt.edu.mx"}'
```

```powershell
# PowerShell
$body = @{ email = "ana@utt.edu.mx" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri http://localhost:3000/auth/magic-link `
  -Body $body -ContentType "application/json"
```

Respuesta (en desarrollo incluye `devLink`):

```json
{
  "correlationId": "0f0c...",
  "expiresAt": "2026-11-11T18:45:00.000Z",
  "devLink": "http://127.0.0.1:9099/emulator/action?mode=signIn&oobCode=..."
}
```

> En producción `devLink` **no** se devuelve. El enlace se envía por correo.

### 13.4 Verificar el token

```bash
curl -X POST http://localhost:3000/auth/verify \
  -H "Content-Type: application/json" \
  -d '{"idToken":"PEGA_AQUI_EL_ID_TOKEN"}'
```

Respuesta:

```json
{
  "accessToken": "eyJhbGciOi...",
  "user": { "id": "...", "email": "ana@utt.edu.mx", "status": "active" },
  "roles": ["lector"],
  "permissions": ["chat.iniciar"]
}
```

### 13.5 Consultar el perfil

```bash
curl http://localhost:3000/auth/me \
  -H "Authorization: Bearer $TOKEN"
```

```powershell
Invoke-RestMethod -Uri http://localhost:3000/auth/me `
  -Headers @{ Authorization = "Bearer $env:TOKEN" }
```

### 13.6 Probar los rechazos

```bash
# Dominio no institucional → 400
curl -i -X POST http://localhost:3000/auth/magic-link \
  -H "Content-Type: application/json" \
  -d '{"email":"ana@gmail.com"}'

# Sin token → 401
curl -i http://localhost:3000/auth/me

# Token alterado → 401
curl -i http://localhost:3000/auth/me -H "Authorization: Bearer token_falso"
```

### 13.7 Verificar la auditoría

```sql
SELECT occurred_at, event_type_code, succeeded, correlation_id, source_ip
FROM audit_events
ORDER BY occurred_at DESC
LIMIT 10;
```

Debe aparecer, como mínimo, `auth.magic_link_requested`, `auth.magic_link_sent`, `user.created` y `auth.login_succeeded`.

---

<a id="errores"></a>

## 14. Errores comunes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `database "utt_connect" does not exist` | No se creó la base | `CREATE DATABASE utt_connect;` |
| `extension "citext" is not available` | Falta `postgresql-contrib` | Linux: `apt install postgresql-contrib` · Windows: Stack Builder |
| `permission denied to create extension` | Usuario sin privilegios | Ejecuta como `postgres` o pide permisos |
| `relation "users" already exists` | Se ejecutó `001` dos veces | Recrea la base y vuelve a aplicar |
| `column "displayName" does not exist` | Falta `name: 'display_name'` en la entidad | Agrega el `name` explícito |
| `synchronize` intenta alterar tablas | `synchronize: true` | Cámbialo a `false` |
| `ECONNREFUSED 127.0.0.1:5432` | PostgreSQL apagado | Inicia el servicio |
| `ECONNREFUSED 127.0.0.1:9099` | Emulador apagado | `firebase emulators:start --only auth` |
| `FirebaseAppError: ... project` | `FIREBASE_PROJECT_ID` incorrecto | Usa `demo-utt-connect` en desarrollo |
| `401` en todas las rutas | Token ausente o expirado | Vuelve a llamar `/auth/verify` |
| `403` en rutas de administrador | El usuario no tiene el permiso | Asigna el rol en `user_roles` |
| `devLink` no aparece | `NODE_ENV=production` | Usa `NODE_ENV=development` |
| El emulador no arranca | Falta Java | Instala JDK 11+ y reinicia la terminal |
| Puerto 3000 ocupado | Otro proceso | `PORT=3001` en `.env` |

---

<a id="checklist"></a>

## 15. Checklist de terminado

### Entorno

- [ ] Los tres repositorios clonados lado a lado.
- [ ] `npm install` sin errores en backend y frontend.
- [ ] PostgreSQL encendido y base `utt_connect` creada.

### Base de datos

- [ ] `001_auth.sql` aplicado sin errores.
- [ ] `002_seed_permissions.sql` aplicado.
- [ ] 13 tablas en `pg_tables` (12 del modelo + partición).
- [ ] 10 permisos y reparto 10/5/1.
- [ ] 3 triggers presentes.

### Backend

- [ ] TypeORM conectado con `synchronize: false`.
- [ ] `.env` creado y fuera de Git.
- [ ] `GET /health` responde `200`.
- [ ] `POST /auth/magic-link` responde `202` y respeta el dominio.
- [ ] `POST /auth/verify` crea el usuario y emite JWT.
- [ ] `GET /auth/me` devuelve roles y permisos.
- [ ] Guards devuelven `401` y `403` correctamente.
- [ ] `npm run lint` sin errores.
- [ ] `npm run test` en verde.

### Auditoría

- [ ] Cada solicitud, envío y login genera su evento.
- [ ] `correlation_id` permite reconstruir el flujo.
- [ ] La IP y el `user_agent` quedan registrados.

### Git

- [ ] Rama `feature/...` creada desde `master`.
- [ ] Commits con Conventional Commits.
- [ ] Pull Request abierto y revisado.
- [ ] Sin `.env`, credenciales ni `node_modules` en el commit.

---

**Siguiente paso:** migración `003_departments.sql` y CRUD de departamentos (RF-14, RF-15, RF-16).
