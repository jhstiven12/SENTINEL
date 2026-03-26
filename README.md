# SENTINEL — Descubrimiento automatizado de servicios para AAP 2.6

Descubre servicios activos, procesos Java (JVM) y puertos en escucha en RHEL 7/8/9/10 y Windows Server 2016/2019/2022, persistiendo snapshots completos en Oracle Database (esquema `CONFIGURACION`).

---

## Estructura del proyecto

```
SENTINEL/
├── playbook_rhel.yml                           # Playbook RHEL (invoca rol svc_disc_rhel)
├── playbook_windows.yml                        # Playbook Windows (invoca rol svc_disc_win)
├── Dockerfile                                  # EE custom para AAP 2.6
├── requirements.yml / .txt / bindep.txt        # Dependencias de colecciones y Python
├── ansible.cfg                                 # Configuración Ansible
├── ddl_changes.sql                             # DDL Oracle (tablas y secuencias)
└── roles/
    ├── svc_disc_rhel/                          # Rol RHEL
    │   ├── defaults/main.yml                   # Parámetros técnicos (timeouts, maps, SQL)
    │   ├── vars/main.yml                       # Credenciales y configuración por entorno ⚠️
    │   ├── meta/main.yml
    │   └── tasks/
    │       ├── main.yml                        # Orquestador de 14 fases
    │       ├── preflight.yml                   # Validación Oracle pre-ejecución
    │       ├── batch_init.yml                  # UUID + INSERT OBS_BATCH_EXECUTION
    │       ├── server.yml                      # MERGE OBS_SERVER
    │       ├── ports.yml                       # ss / netstat → svc_disc_rhel_pid_ports
    │       ├── services.yml                    # systemctl → svc_disc_rhel_parsed_services
    │       ├── java_detection.yml              # JVM → svc_disc_rhel_java_services
    │       ├── pm2_detection.yml               # PM2 → svc_disc_rhel_pm2_services
    │       ├── db_detection.yml                # Motores DB → svc_disc_rhel_db_services
    │       ├── webserver_detection.yml         # Web/proxy → svc_disc_rhel_web_services
    │       ├── docker_detection.yml            # Containers → svc_disc_rhel_docker_services
    │       ├── infra_agents_detection.yml      # Agentes infra → svc_disc_rhel_infra_services
    │       ├── normalize.yml                   # Dedup+fusión → svc_disc_rhel_sentinel_services
    │       ├── oracle_persist.yml              # MERGE OBS_SERVICE + INSERT OBS_SERVICE_LOG
    │       └── batch_finalize.yml              # UPDATE TOTAL_SERVERS
    └── svc_disc_win/                           # Rol Windows
        ├── defaults/main.yml                   # Parámetros técnicos (timeouts, maps, SQL)
        ├── vars/main.yml                       # Credenciales y configuración por entorno ⚠️
        ├── meta/main.yml
        └── tasks/
            ├── main.yml
            ├── preflight.yml
            ├── batch_init.yml
            ├── server.yml
            ├── ports.yml                       # Get-NetTCPConnection + netstat UDP
            ├── services.yml                    # Win32_Service + Get-Process
            ├── java_detection.yml              # JVM en Windows (Win32_Process)
            ├── pm2_detection.yml
            ├── db_detection.yml
            ├── webserver_detection.yml
            ├── docker_detection.yml
            ├── infra_agents_detection.yml
            ├── normalize.yml
            ├── oracle_persist.yml
            └── batch_finalize.yml
```

---

## Convención de nombres

**Todas** las variables llevan como prefijo el nombre del rol:

| Rol | Prefijo de variable | Ejemplo |
|---|---|---|
| `svc_disc_rhel` | `svc_disc_rhel_` | `svc_disc_rhel_batch_id`, `svc_disc_rhel_pid_ports` |
| `svc_disc_win` | `svc_disc_win_` | `svc_disc_win_batch_id`, `svc_disc_win_pid_ports` |

Esto incluye: `defaults/`, `vars/`, facts registrados, `register` vars y `loop_var`.

---

## Variables sensibles — `roles/<rol>/vars/main.yml`

Cada rol gestiona sus propias credenciales en `vars/main.yml`. Estos archivos deben cifrarse con Ansible Vault antes de usar en producción.

```bash
# Cifrar
ansible-vault encrypt roles/svc_disc_rhel/vars/main.yml
ansible-vault encrypt roles/svc_disc_win/vars/main.yml

# Editar en producción
ansible-vault edit roles/svc_disc_rhel/vars/main.yml
ansible-vault edit roles/svc_disc_win/vars/main.yml
```

### `roles/svc_disc_rhel/vars/main.yml`

| Variable | Descripción |
|---|---|
| `svc_disc_rhel_oracle_user` | Usuario Oracle |
| `svc_disc_rhel_oracle_password` | Contraseña Oracle |
| `svc_disc_rhel_oracle_dsn` | `host:port/service` |
| `svc_disc_rhel_oracle_db_node` | Hostname del nodo delegado para queries Oracle |
| `svc_disc_rhel_execution_type` | `SCHEDULED` \| `MANUAL` \| `ADHOC` |
| `svc_disc_rhel_environment` | `PRODUCTION` \| `STAGING` \| `DEVELOPMENT` |

### `roles/svc_disc_win/vars/main.yml`

| Variable | Descripción |
|---|---|
| `svc_disc_win_oracle_user` | Usuario Oracle |
| `svc_disc_win_oracle_password` | Contraseña Oracle |
| `svc_disc_win_oracle_dsn` | `host:port/service` |
| `svc_disc_win_oracle_db_node` | Hostname del nodo delegado para queries Oracle |
| `svc_disc_win_winrm_user` | Usuario WinRM |
| `svc_disc_win_winrm_password` | Contraseña WinRM |
| `svc_disc_win_execution_type` | `SCHEDULED` \| `MANUAL` \| `ADHOC` |
| `svc_disc_win_environment` | `PRODUCTION` \| `STAGING` \| `DEVELOPMENT` |

> **Nota:** `oracle_host`, `oracle_port` y `oracle_service` se derivan automáticamente de `oracle_dsn` en `defaults/main.yml`. No es necesario definirlos manualmente.

---

## Parámetros ajustables — `roles/<rol>/defaults/main.yml`

Los siguientes parámetros tienen valores por defecto funcionales y pueden sobreescribirse vía inventario o `extra_vars`:

| Variable | Por defecto | Descripción |
|---|---|---|
| `svc_disc_rhel_oracle_schema` | `CONFIGURACION` | Esquema Oracle destino |
| `svc_disc_rhel_discovery_timeout` | `120` | Timeout (segundos) por comando de descubrimiento |
| `svc_disc_rhel_excluded_services` | `[kdump, serial-getty]` | Servicios systemd excluidos |
| `svc_disc_rhel_severity_running` | `INFO` | Severidad para servicios activos |
| `svc_disc_rhel_severity_stopped` | `WARNING` | Severidad para servicios inactivos |

*(El rol Windows expone los mismos parámetros con prefijo `svc_disc_win_`.)*

---

## Detección de procesos Java

Ambos roles incluyen `java_detection.yml` que:

1. Busca procesos con binario `java` / `java.exe` **no** cubiertos por systemd o Win32_Service.
2. Extrae el nombre del servicio del cmdline:
   - `-jar app.jar` → `app`
   - `com.example.Application` → `Application`
   - `-Dcatalina.home` → `tomcat-direct`
   - fallback → `java-<PID>`
3. Clasifica la tecnología buscando keywords en el cmdline via `svc_disc_*_java_technology_map` (Tomcat, Spring Boot, Kafka, Jenkins, Keycloak, etc.).
4. Obtiene versión JVM: `/proc/PID/exe -version` (RHEL) o `VersionInfo` (Windows).
5. Cruza puertos desde `svc_disc_*_pid_ports`.
6. Se fusiona con todos los orígenes en `normalize.yml` → lista final unificada `svc_disc_*_sentinel_services`.

---

## Fuentes de descubrimiento y prioridad de deduplicación

| Prioridad | Origen | Variable producida |
|---|---|---|
| 1 (mayor) | systemd / Win32_Service | `svc_disc_*_parsed_services` |
| 2 | Motores de base de datos | `svc_disc_*_db_services` |
| 3 | Procesos Java (JVM) | `svc_disc_*_java_services` |
| 4 | Web servers y proxies | `svc_disc_*_web_services` |
| 5 | PM2 / Node.js | `svc_disc_*_pm2_services` |
| 6 | Agentes de infraestructura | `svc_disc_*_infra_services` |
| 7 (menor) | Contenedores Docker/Podman | `svc_disc_*_docker_services` |

La deduplicación se realiza en dos pasos en `normalize.yml`: primero por PID, luego por nombre de servicio. Gana siempre la fuente de mayor prioridad.

---

## Requisitos previos

| Componente | Versión mínima |
|---|---|
| AAP | 2.6 |
| Oracle Database | 19c+ |
| Python en `oracle_db_node` | 3.9+ con `oracledb>=2.0` |
| Podman o Docker | Cualquiera (para construir el EE) |

Ejecutar DDL antes del primer uso:

```bash
sqlplus CONFIGURACION/<pass>@<host>:<port>/<service> @ddl_changes.sql
```

---

## Construir el Execution Environment

```bash
podman login registry.redhat.io
podman build --tag sentinel-ee:2.6 --file Dockerfile .
podman run --rm sentinel-ee:2.6 ansible --version
```

---

## Ejecución

```bash
# RHEL — descubrimiento completo
ansible-navigator run playbook_rhel.yml \
  --inventory inventory.ini \
  --execution-environment-image sentinel-ee:2.6 \
  --mode stdout

# Windows — descubrimiento completo
ansible-navigator run playbook_windows.yml \
  --inventory inventory.ini \
  --execution-environment-image sentinel-ee:2.6 \
  --mode stdout

# Solo descubrimiento (sin escritura Oracle)
ansible-navigator run playbook_rhel.yml \
  --inventory inventory.ini \
  --execution-environment-image sentinel-ee:2.6 \
  --mode stdout --tags discovery

# Solo procesos Java
ansible-navigator run playbook_rhel.yml \
  --inventory inventory.ini \
  --execution-environment-image sentinel-ee:2.6 \
  --mode stdout --tags java
```

---

## Tags disponibles

| Tag | Alcance |
|---|---|
| `always` | Difusión de `BATCH_ID` a todos los hosts |
| `batch` | `OBS_BATCH_EXECUTION` init y finalize |
| `servers` | `OBS_SERVER` upsert |
| `discovery` | Toda la recolección remota (puertos, servicios, procesos) |
| `services` | systemd / Win32_Service únicamente |
| `java` | Procesos JVM únicamente |
| `oracle_insert` | Todas las operaciones DML Oracle |
