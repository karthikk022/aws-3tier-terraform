#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Install Node.js
curl -sL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Create app directory
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# Initialize npm and install dependencies
npm init -y
npm install express mysql2 dotenv

# Create server.js with DB integration
cat > /home/ec2-user/app/server.js << 'EOF'
const express = require('express');
const mysql = require('mysql2');
const app = express();

const PORT = ${app_port};

// DB Connection details from Terraform
const dbConfig = {
  host: '${db_endpoint}'.split(':')[0],
  user: '${db_username}',
  password: '${db_password}',
  database: '${db_name}'
};

const pool = mysql.createPool(dbConfig);

app.get('/health', (req, res) => {
  res.json({ status: 'healthy', tier: 'app' });
});

app.get('/db-test', (req, res) => {
  pool.query('SELECT 1 + 1 AS solution', (error, results) => {
    if (error) {
      return res.status(500).json({ error: error.message });
    }
    res.json({ message: 'Database connection successful', result: results[0].solution });
  });
});

app.get('/', (req, res) => {
  res.json({
    message: 'App Tier - 3-Tier AWS Architecture',
    service: 'application-server',
    db_status: 'connected'
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`App server running on port ${PORT}`);
});
EOF

# Create systemd service
cat > /etc/systemd/system/app.service << 'UNIT'
[Unit]
Description=Node.js App Server
After=network.target

[Service]
ExecStart=/usr/bin/node /home/ec2-user/app/server.js
Restart=always
User=ec2-user
WorkingDirectory=/home/ec2-user/app
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
UNIT

# Start service
systemctl daemon-reload
systemctl enable app
systemctl start app
