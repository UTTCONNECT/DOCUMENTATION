# ADR-001 · Autenticación sin contraseña con enlace mágico

| Campo | Valor |
|---|---|
| **Estado** | Aceptada |
| **Fecha** | 2026-11-11 |
| **Decisores** | Equipo 1 — UTT Connect |
| **Módulo** | Autenticación, autorización y auditoría |
| **Reemplaza** | RF-06, RF-07 y RF-08 originales (OTP + contraseña) |

---

## 1. Contexto

El README describía en RF-06/07/08 un registro con **OTP + contraseña**: el usuario recibía un
código, lo ingresaba y establecía una contraseña (con medidor de fortaleza y flujo de recuperación).

Sin embargo, el esquema SQL construido y validado implementa un flujo **sin contraseña**:

- La identidad la emite **Firebase Authentication** (`identity_providers`, `user_identities`).
- El acceso se solicita con un **enlace mágico** (`magic_link_requests`).
- No existe columna `password_hash`, ni tabla de OTP, ni flujo de recuperación.

Mantener ambos documentos producía una contradicción: el backend no sabría qué construir y la
documentación académica describiría algo distinto de lo demostrable.

---

## 2. Decisión

Se adopta **magic link con Firebase** como único mecanismo de autenticación:

1. El usuario escribe su correo `@utt.edu.mx`.
2. El backend crea una solicitud en `magic_link_requests` (estado `requested`).
3. El backend genera el enlace de un solo uso con Firebase y lo entrega al correo institucional
   (en desarrollo se expone como `devLink` para poder probar sin correo real).
4. El cliente (Angular) abre el enlace, completa el inicio de sesión con Firebase y obtiene un
   **ID token**.
5. El backend valida el ID token (`verifyIdToken`), crea o recupera `users` + `user_identities`,
   marca la solicitud como `consumed` y emite un **JWT propio** para consumir la API.
6. Cada paso escribe un evento en `audit_events`.

**No se almacenan contraseñas en ninguna forma.**

---

## 3. Consecuencias

### Positivas

- **Menos superficie de ataque:** no hay hashes, ni bcrypt, ni política de contraseñas, ni
  recuperación de contraseña que implementar.
- **Coincide con el esquema ya probado:** no requiere tablas nuevas para el MVP.
- **Verificación de correo implícita:** quien abre el enlace demuestra que controla la cuenta.
- **Auditoría natural:** cada solicitud y cada consumo ya son filas con IP, `user_agent`,
  `correlation_id` y timestamps.
- **Cumple RF-04, RF-05, RF-09, RF-10, RF-12 y RF-13** sin cambios.

### Negativas y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Depende de la entrega de correo (Firebase/cuotas) | Plan gratuito suficiente para el proyecto; monitorear `failure_code` en `magic_link_requests`. |
| El usuario debe abrir el correo en el mismo dispositivo | Usar `continue_url` y ofrecer “reenviar enlace”; documentar el caso. |
| No se puede demostrar sin internet | Sembrar usuarios de prueba o usar el emulador de Firebase para la demo. |
| Enumeración de cuentas | Responder siempre `202 Accepted`, exista o no el correo. |
| Abuso del endpoint | Rate limit por correo e IP en el backend; `expires_at` corto (10–15 min). |
| Enlace reutilizado | Estado `consumed` + `CHECK` de coherencia + validación al verificar el ID token. |

---

## 4. Impacto en los requisitos funcionales

| RF | Texto anterior | Texto propuesto |
|---|---|---|
| **RF-06** | Verificación de identidad por OTP y establecimiento de contraseña | **Verificación de identidad por enlace mágico:** el usuario recibe un enlace de un solo uso en su correo institucional; al abrirlo se verifica su identidad y se crea o recupera su cuenta. |
| **RF-07** | Medidor visual de contraseñas | **Se elimina.** No existen contraseñas en el sistema. |
| **RF-08** | Recuperación y cambio de contraseña por OTP | **Recuperación de acceso:** si el usuario pierde el enlace o expira, puede solicitar uno nuevo; el acceso se recupera con el mismo mecanismo. |
| **RF-15** | El admin crea cuentas “con contraseña” | El admin **invita** el correo institucional, asigna rol y departamento; la identidad se completa cuando el usuario abre el enlace. |
| **RF-11** | Máximo 2 sesiones concurrentes | **Pendiente:** no está cubierto por este módulo. Requiere tabla `user_sessions` o almacén en Redis. |
| **RF-12 / RF-13** | Auditoría de sesiones e IP | **Cubierto** por `audit_events` (`source_ip`, `user_agent`, `occurred_at`). |

> **Acción documental aplicada (2026-11-11):** el README ya no referencia bcrypt, medidor de
> contraseñas ni recuperación por OTP. RF-06 y RF-08 se reescribieron y RF-07 quedó marcado como
> eliminado en la sección 7.2.

---

## 5. Alternativas consideradas

| Alternativa | Por qué se descartó |
|---|---|
| **OTP + contraseña** | Exigía `password_hash`, tabla de códigos, política de contraseñas, medidor y recuperación. Más código y más riesgo, sin beneficio para el MVP. |
| **Solo Firebase (sin backend propio)** | Firebase resolvería el login, pero no el RBAC, ni la auditoría institucional, ni las reglas de negocio. |
| **OAuth con Google Workspace** | Requiere que la universidad administre el dominio en Google Workspace; no está garantizado. |
| **Híbrido (magic link + contraseña para departamentos)** | Duplica flujos y superficies de ataque; se puede añadir después sin romper el modelo. |

---

## 6. Contrato de implementación

| Endpoint | Entrada | Salida | Efecto en BD |
|---|---|---|---|
| `POST /auth/magic-link` | `{ email }` | `202 Accepted` siempre; en desarrollo incluye `devLink` | Inserta en `magic_link_requests` (`requested` → `sent`). |
| `POST /auth/verify` | `{ idToken }` | `{ accessToken, user, roles, permissions }` | Valida el ID token de Firebase; crea/actualiza `users` y `user_identities`; solicitud → `consumed`. |
| `GET /auth/me` | JWT | `{ user, roles, permissions }` | Solo lectura. |
| `POST /auth/logout` | JWT | `204` | Evento `auth.logout` (nuevo tipo en el catálogo). |

> `POST /auth/verify` sustituye al `GET /auth/callback` previsto: el intercambio del enlace por
> una sesión de Firebase solo puede hacerlo el SDK cliente. El backend nunca recibe el enlace,
> solo el ID token resultante.

Reglas obligatorias del backend:

- Validar dominio `@utt.edu.mx` **antes** de crear la solicitud.
- No revelar si el correo existe.
- Expiración del enlace entre 10 y 15 minutos.
- Registrar `correlation_id` en todos los eventos del flujo.
- Rechazar tokens ya consumidos aunque Firebase los acepte.

---

## 7. Pendientes derivados

1. Actualizar RF-06/07/08/15 en el README.
2. Implementar RF-11 (sesiones concurrentes) con `user_sessions` o Redis.
3. Definir la política de reenvío de enlaces (máximo N por correo/hora).
4. Agregar `auth.logout` y `auth.magic_link_resent` al catálogo `audit_event_types`.
5. Configurar el emulador de Firebase para pruebas locales sin correo real.
