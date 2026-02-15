## Implementación


1.  **Dockerfile Personalizado**: He creado una imagen basada en `debian:stable-slim` para mantenerla ligera, instalando únicamente `vsftpd` y `openssl`.
2.  **Script de Entrada (`entrypoint.sh`)**: He programado un script en bash que se ejecuta al iniciar el contenedor. Este script es clave porque:
    *   Genera automáticamente el certificado SSL si no existe (configurado para **Zaragoza**).
    *   Crea el usuario FTP y asigna la contraseña dinámicamente.
    *   Configura el direccionamiento de puertos pasivos.
3.  **Docker Compose**: He orquestado todo en un archivo `docker-compose.yml` que facilita el levantamiento del servicio con un solo comando.

## Cómo ponerlo en marcha

Para levantar el servidor, simplemente ejecuto:

```bash
docker compose up -d --build
```

Esto construye la imagen, crea los volúmenes para persistencia de datos y arranca el servicio en segundo plano.

## Verificación del Trabajo

He preparado una serie de comandos para demostrar que se cumplen todos los requisitos, especialmente los de seguridad y configuración personalizada.

### 1. Verificar el Certificado (Lugar: Zaragoza)

Para demostrar que el certificado SSL se ha generado correctamente, utilizo `openssl` para conectar y extraer el "Subject" del certificado:

```bash
echo | openssl s_client -connect localhost:21 -starttls ftp 2>/dev/null | openssl x509 -noout -subject
```
**Resultado esperado:** Debes ver `ST=Zaragoza, L=Zaragoza`.

### 2. Verificar Cifrado de Mensajes (SSL/TLS)

Para demostrar que la conexión es realmente segura y que los mensajes van cifrados, uso `curl` en modo verboso (`-v`) forzando SSL. Esto muestra el "handshake" TLS.

```bash
curl -v --ftp-ssl --insecure -u "usuario_ftp:123" ftp://localhost:21/
```

**Qué buscar en la salida:**
Busca líneas que indiquen el establecimiento de la seguridad, como:
*   `SSL connection using TLSv1.3`
*   `TLS handshake, Client hello`
*   `TLS handshake, Server hello`
*   `226 Transfer complete` (indica que la transferencia de datos también fue exitosa bajo el canal seguro).

### 3. Verificar Persistencia y Logs

Para ver los logs del servidor (que he redirigido a la salida estándar de Docker para facilitar la depuración):

```bash
docker compose logs -f
```

### Configuración (Variables de Entorno)

La configuración se define en `docker-compose.yml`. Las credenciales actuales son:
*   **Usuario**: `usuario_ftp`
*   **Contraseña**: `123`
*   **Puerto**: 21 (Control), 20 (Datos), 21100-21110 (Pasivo)
