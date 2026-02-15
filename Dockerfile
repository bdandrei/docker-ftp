FROM debian:stable-slim

# Instalar vsftpd y openssl
RUN apt-get update && apt-get install -y \
    vsftpd \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Copiar archivos de configuración y script de inicio
COPY vsftpd.conf /etc/vsftpd.conf
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Dar permisos de ejecución al entrypoint
RUN chmod +x /usr/local/bin/entrypoint.sh

# Crear directorio necesario para vsftpd
RUN mkdir -p /var/run/vsftpd/empty

# Exponer puertos: 20 (datos), 21 (control), y rango PASV
EXPOSE 20 21 21100-21110

# Definir el comando de inicio
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
