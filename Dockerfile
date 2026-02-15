FROM debian:stable-slim

# Instalar vsftpd, openssl y herramientas para base de datos (Berkeley DB)
RUN apt-get update && apt-get install -y \
    vsftpd \
    openssl \
    db-util \
    && rm -rf /var/lib/apt/lists/*

# Copiar archivos de configuración y script de inicio
COPY vsftpd.conf /etc/vsftpd.conf
COPY vsftpd_virtual /etc/pam.d/vsftpd_virtual
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Dar permisos de ejecución al entrypoint
RUN chmod +x /usr/local/bin/entrypoint.sh

# Crear directorio necesario para vsftpd
RUN mkdir -p /var/run/vsftpd/empty

# Exponer puertos: 20 (datos), 21 (control), y rango PASV
EXPOSE 20 21 21100-21110

# Definir el comando de inicio
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
