# Proyecto: Servidor FTP Seguro (FTPS) con Usuarios Virtuales
## "The Backup Vault" - Tarea RA4

Este proyecto implementa un servidor FTP seguro (**vsftpd**) contenerizado con Docker, diseñado para cumplir con los requisitos de seguridad de un entorno corporativo. Utiliza **usuarios virtuales** (Berkeley DB), **jaulas chroot**, **SSL/TLS forzado** y **límites de recursos**.

---

## Puesta en Marcha Rápida

Para levantar el servicio con toda la configuración aplicada:

```bash
docker compose up -d --build
```

Esto iniciará el contenedor `backup_vault_ftp` exponiendo los puertos:
*   **21**: Control FTP
*   **20**: Datos FTP
*   **40000-40100**: Pasivo FTP

---

## Características Implementadas

1.  **Usuarios Virtuales**: Gestionados vía PAM y base de datos Berkeley (`libpam-userdb`). No son usuarios del sistema.
2.  **Seguridad**:
    *   **FTPS Explícito**: Todo (login + datos) viaja cifrado.
    *   **Chroot Jail**: Usuarios encerrados en su home. Estructura segura: Raíz (root:root) -> `uploads/` (escritura).
    *   **Certificado**: Generación automática de certificado autofirmado para "Zaragoza".
3.  **Rendimiento y Límites**:
    *   Ancho de banda limitado a **1 MB/s**.
    *   Máximo **10 clientes** simultáneos.
    *   Máximo **2 conexiones** por IP.
4.  **Logging**: Auditoría completa de comandos activada en `/var/log/vsftpd.log`.

---

## Verificación y Pruebas

A continuación se detallan los comandos para validar que el servidor cumple con todos los requisitos.

### 1. Conexión y Listado (Prueba Básica)
Verifica que el usuario `deployer` puede conectar y listar el directorio raíz (que debe ser de solo lectura).

```bash
lftp -c "set ssl:verify-certificate no; open -u deployer,A123 ftp://localhost; ls"
```
**Resultado esperado:** Debe mostrar la carpeta `uploads`.

### 2. Subida de Archivos (Upload)
El usuario solo debe tener permiso de escritura en la carpeta `uploads`.

**Paso 1: Crear un archivo de prueba**
```bash
echo "Contenido confidencial" > secreto.txt
```

**Paso 2: Intentar subir a la RAÍZ (Debe fallar)**
```bash
lftp -c "set ssl:verify-certificate no; open -u deployer,A123 ftp://localhost; put secreto.txt"
```
*   **Esperado:** `Access denied` o `553 Could not create file`.

**Paso 3: Subir a la carpeta UPLOADS (Debe funcionar)**
```bash
lftp -c "set ssl:verify-certificate no; open -u deployer,A123 ftp://localhost; cd uploads; put secreto.txt; ls"
```
*   **Esperado:** El archivo se sube correctamente y se lista.

### 3. Verificar Cifrado (SSL/TLS)
Confirma que el servidor rechaza conexiones inseguras y que el certificado es correcto.

```bash
openssl s_client -connect localhost:21 -starttls ftp
```
*   Busca en la salida: `Protocol  : TLSv1.3` (o similar) y `Subject: ... L=Zaragoza`.

### 4. Verificar Límites
Para probar el límite de conexiones simultáneas por IP (máx 2), usaremos `nc` para simular conexiones activas, ya que clientes como `lftp` pueden cerrar la conexión al estar inactivos.

Abre **3 terminales** y ejecuta en cada una:
```bash
nc -v localhost 21
```

*   **Terminal 1 y 2**: Conectarán correctamente (`220 Bienvenido...`).
*   **Terminal 3**: Será rechazada inmediatamente con `421 There are too many connections from your internet address.`

---

## Estructura de Archivos

*   `Dockerfile`: Imagen base Debian + vsftpd + db-util + openssl.
*   `docker-compose.yml`: Orquestación, puertos y variables de entorno.
*   `entrypoint.sh`: Script de inicio. Genera DB de usuarios, certificados y estructura de directorios.
*   `vsftpd.conf`: Configuración maestra del servicio.
*   `vsftpd_virtual`: Archivo PAM para la autenticación de usuarios virtuales.

---

## Limpieza

Para detener y borrar el contenedor y la red:

```bash
docker compose down
```

Para borrar también el volumen de datos persistente:

```bash
docker compose down -v
```
