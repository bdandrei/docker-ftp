#!/bin/sh

# Configuración por defecto
FTP_USER=${FTP_USER:-usuario}
FTP_PASS=${FTP_PASS:-123}
PASV_MIN=${PASV_MIN:-40000}
PASV_MAX=${PASV_MAX:-40100}
PASV_ADDRESS=${PASV_ADDRESS:-localhost}

# Crear el usuario del sistema "vsftpd" para mapeo (si no existe)
if ! id "vsftpd" > /dev/null 2>&1; then
    echo "Creando usuario de sistema vsftpd..."
    useradd --home /home/vsftpd --gid nogroup -m --shell /bin/false vsftpd
fi

# Configuración de Usuarios Virtuales (Berkeley DB)
mkdir -p /etc/vsftpd
echo "Generando base de datos de usuarios virtuales..."

# Crear archivo de texto temporal con el formato: usuario\ncontraseña
cat <<EOF > /etc/vsftpd/virtual_users.txt
$FTP_USER
$FTP_PASS
EOF

# Compilar la base de datos (db_load o db5.3_load)
if command -v db5.3_load >/dev/null 2>&1; then
    DB_LOAD_CMD="db5.3_load"
elif command -v db_load >/dev/null 2>&1; then
    DB_LOAD_CMD="db_load"
else
    # Fallback: intentar encontrar cualquier db*_load
    DB_LOAD_CMD=$(find /usr/bin -name "db*_load" | head -n 1)
fi

if [ -z "$DB_LOAD_CMD" ]; then
    echo "ERROR: No se encontró comando db_load. Asegúrate de instalar db-util."
    exit 1
fi

echo "Usando comando: $DB_LOAD_CMD"
$DB_LOAD_CMD -T -t hash -f /etc/vsftpd/virtual_users.txt /etc/vsftpd/virtual_users.db

# Asegurar permisos de la base de datos
rm /etc/vsftpd/virtual_users.txt
chmod 600 /etc/vsftpd/virtual_users.db

# Estructura de Directorios (JAULA CHROOT)
# La raíz del usuario ($USER) debe ser propiedad de root y NO escribible.
# La subcarpeta uploads SÍ debe ser escribible por el usuario mapeado (vsftpd).

USER_ROOT="/home/vsftpd/$FTP_USER"
UPLOAD_DIR="$USER_ROOT/uploads"

echo "Configurando directorios para $FTP_USER..."
mkdir -p "$UPLOAD_DIR"

# Permisos de la Raíz de la Jaula (Propiedad de root, Solo lectura para el usuario)
chown root:root "$USER_ROOT"
chmod 755 "$USER_ROOT"

# Permisos del directorio de carga (Propiedad de vsftpd:nogroup, Escritura permitida)
chown vsftpd:nogroup "$UPLOAD_DIR"
chmod 775 "$UPLOAD_DIR"

# Generar certificado SSL (Si no existe)
if [ ! -f /etc/ssl/private/vsftpd.pem ]; then
    echo "Generando certificado SSL..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/ssl/private/vsftpd.pem \
        -out /etc/ssl/private/vsftpd.pem \
        -subj "/C=ES/ST=Zaragoza/L=Zaragoza/O=ProyectoRA4/OU=IT/CN=$PASV_ADDRESS"
    
    chmod 600 /etc/ssl/private/vsftpd.pem
fi

# Configurar puertos pasivos dinámicamente
CONF_FILE="/etc/vsftpd.conf"
sed -i '/^pasv_address/d' $CONF_FILE
sed -i '/^pasv_min_port/d' $CONF_FILE
sed -i '/^pasv_max_port/d' $CONF_FILE
sed -i '/^pasv_enable/d' $CONF_FILE

echo "pasv_enable=YES" >> $CONF_FILE
echo "pasv_address=$PASV_ADDRESS" >> $CONF_FILE
echo "pasv_min_port=$PASV_MIN" >> $CONF_FILE
echo "pasv_max_port=$PASV_MAX" >> $CONF_FILE

# Logging
touch /var/log/vsftpd.log
chown vsftpd:nogroup /var/log/vsftpd.log
tail -f /var/log/vsftpd.log &

echo "Iniciando vsftpd con soporte para Usuarios Virtuales..."
exec /usr/sbin/vsftpd $CONF_FILE
