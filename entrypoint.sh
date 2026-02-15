#!/bin/sh

# Configuración por defecto si no se especifican variables de entorno
FTP_USER=${FTP_USER:-usuario}
FTP_PASS=${FTP_PASS:-123}
PASV_MIN=${PASV_MIN:-21100}
PASV_MAX=${PASV_MAX:-21110}
PASV_ADDRESS=${PASV_ADDRESS:-0.0.0.0}

#Crear usuario FTP
if ! id "$FTP_USER" > /dev/null 2>&1; then
    echo "Creando usuario FTP: $FTP_USER"
    useradd -m -d /home/$FTP_USER -s /bin/sh $FTP_USER
    echo "$FTP_USER:$FTP_PASS" | chpasswd
    chown $FTP_USER:$FTP_USER /home/$FTP_USER
else
    echo "Usuario $FTP_USER ya existe. Actualizando contraseña..."
    echo "$FTP_USER:$FTP_PASS" | chpasswd
fi

# Generar certificado SSL automático si no existe
if [ ! -f /etc/ssl/private/vsftpd.pem ]; then
    echo "Generando certificado SSL autofirmado..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/vsftpd.pem \
        -out /etc/ssl/private/vsftpd.pem \
        -subj "/C=ES/ST=Zaragoza/L=Zaragoza/O=DockerFTP/CN=localhost"
    chmod 600 /etc/ssl/private/vsftpd.pem
fi

# Configurar puertos pasivos en tiempo de ejecución
CONF_FILE="/etc/vsftpd.conf"

# Limpiar configuraciones anteriores de pasv para evitar duplicados
sed -i '/^pasv_address/d' $CONF_FILE
sed -i '/^pasv_min_port/d' $CONF_FILE
sed -i '/^pasv_max_port/d' $CONF_FILE
sed -i '/^pasv_enable/d' $CONF_FILE

# Añadir configuración dinámica
echo "pasv_enable=YES" >> $CONF_FILE
echo "pasv_address=$PASV_ADDRESS" >> $CONF_FILE
echo "pasv_min_port=$PASV_MIN" >> $CONF_FILE
echo "pasv_max_port=$PASV_MAX" >> $CONF_FILE


# 4. Asegurar logging en stdout
touch /var/log/vsftpd.log
tail -f /var/log/vsftpd.log &

echo "Iniciando vsftpd..."
# Ejecutar vsftpd
exec /usr/sbin/vsftpd $CONF_FILE
