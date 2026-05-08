#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Install Node.js
curl -sL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

mkdir -p /home/ec2-user/app
cat > /home/ec2-user/app/server.js << 'EOF'
const http = require('http');

const PORT = ${app_port};

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', tier: 'app' }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    message: 'App Tier - 3-Tier AWS Architecture',
    service: 'application-server',
    port: PORT
  }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log("App server running on port " + PORT);
});
EOF

cat > /etc/systemd/system/app.service << 'UNIT'
[Unit]
Description=Node.js App Server
After=network.target

[Service]
ExecStart=/usr/bin/node /home/ec2-user/app/server.js
Restart=always
User=ec2-user
WorkingDirectory=/home/ec2-user/app

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable app
systemctl start app
