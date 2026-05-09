#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Update and install Nginx
yum update -y
yum install -y nginx

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Create a custom Nginx configuration for reverse proxy
cat > /etc/nginx/conf.d/app_proxy.conf <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://${app_alb_dns}:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        access_log off;
        return 200 'healthy\n';
    }
}
EOF

# Remove default server block if it exists or conflicts
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
cat > /etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
EOF

# Restart Nginx to apply changes
systemctl restart nginx
