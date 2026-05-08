#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

yum update -y
yum install -y nginx

systemctl enable nginx
systemctl start nginx

cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Web Tier - 3-Tier AWS Architecture</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding-top: 50px; background: #f0f2f5; }
        h1 { color: #232f3e; }
        .card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
        .badge { display: inline-block; padding: 6px 14px; border-radius: 4px; font-size: 14px; margin-top: 20px; }
        .badge-web { background: #ff9900; color: white; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Web Tier</h1>
        <p>Deployed via Terraform - 3-Tier Architecture</p>
        <div class="badge badge-web">Healthy</div>
    </div>
</body>
</html>
EOF
