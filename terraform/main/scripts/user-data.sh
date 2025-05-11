#!/bin/bash

# ====================================================================================
# INITIALIZATION AND LOGGING SETUP
# ====================================================================================
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "================================================================================"
echo "Beginning user data script execution: $(date)"
echo "================================================================================"

# Set error handling
set -e
trap 'echo "Error occurred at line $LINENO. Status code: $?" >&2' ERR

# Create necessary directories
echo "Creating application directories..."
mkdir -p /var/www/html
mkdir -p /opt/banking-app
mkdir -p /var/log/app

# ====================================================================================
# SYSTEM UPDATES AND PACKAGE INSTALLATION
# ====================================================================================
echo "Updating system packages..."
yum update -y

# Install CloudWatch agent
echo "Installing CloudWatch agent..."
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
echo "Configuring CloudWatch agent..."
aws ssm get-parameter \
  --name /${app_name}/cloudwatch-agent-config \
  --region ${aws_region} \
  --output text \
  --query Parameter.Value > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Start CloudWatch agent
echo "Starting CloudWatch agent..."
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Install Node.js
echo "Installing Node.js..."
curl -sL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
# Check if amazon-linux-extras exists (Amazon Linux 2)
if command -v amazon-linux-extras &>/dev/null; then
    amazon-linux-extras install postgresql14 -y
else
    # For Amazon Linux 2023
    yum install -y postgresql15
fi

# ====================================================================================
# NGINX INSTALLATION AND CONFIGURATION
# ====================================================================================
echo "Installing and configuring Nginx..."
# Check if amazon-linux-extras exists (Amazon Linux 2)
if command -v amazon-linux-extras &>/dev/null; then
    amazon-linux-extras install nginx1 -y
else
    # For Amazon Linux 2023
    yum install -y nginx
fi

# Create Nginx configuration directories if they don't exist
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# Configure Nginx for frontend and API
cat > /etc/nginx/sites-available/${app_name} << 'NGINX_CONFIG'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Frontend static files
    location / {
        root /var/www/html;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 30d;
            add_header Cache-Control "public, no-transform";
        }
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeout settings
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Logging configuration
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
}
NGINX_CONFIG

# Enable the site configuration
ln -sf /etc/nginx/sites-available/${app_name} /etc/nginx/sites-enabled/

# Update nginx.conf to include sites-enabled
grep -q "include /etc/nginx/sites-enabled/\*;" /etc/nginx/nginx.conf || \
  sed -i '/http {/a \    include /etc/nginx/sites-enabled/\*;' /etc/nginx/nginx.conf

# Test Nginx configuration
echo "Testing Nginx configuration..."
nginx -t

# Start and enable Nginx
echo "Starting Nginx service..."
systemctl enable nginx
systemctl start nginx

# ====================================================================================
# APPLICATION DEPLOYMENT
# ====================================================================================
echo "Deploying application from S3..."

# Download frontend assets from S3
echo "Downloading frontend assets..."
aws s3 cp s3://${s3_bucket_id}/frontend/build.zip /tmp/frontend.zip || {
    echo "Warning: Frontend assets not found in S3. Using placeholder page."
    # Create a placeholder index.html
    cat > /var/www/html/index.html << 'HTML_CONTENT'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Banking App</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 0; display: flex; justify-content: center; align-items: center; height: 100vh; background-color: #f5f5f5; }
        .container { text-align: center; padding: 2rem; background-color: white; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        h1 { color: #0066cc; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Banking App</h1>
        <p>Application is initializing. Please check back later.</p>
        <p>If this message persists, please contact support.</p>
    </div>
</body>
</html>
HTML_CONTENT
}

# If frontend assets were downloaded successfully, extract them
if [ -f "/tmp/frontend.zip" ]; then
    echo "Extracting frontend assets..."
    unzip -o /tmp/frontend.zip -d /tmp/frontend
    cp -r /tmp/frontend/* /var/www/html/
    rm -rf /tmp/frontend /tmp/frontend.zip
fi

# Download backend application from S3
echo "Downloading backend application..."
aws s3 cp s3://${s3_bucket_id}/backend/app.zip /tmp/backend.zip || {
    echo "Warning: Backend application not found in S3. Using placeholder."
    # Create a placeholder server.js
    cat > /opt/banking-app/server.js << 'JS_CONTENT'
const express = require('express');
const app = express();
const port = 3000;

app.use(express.json());

app.get('/api/status', (req, res) => {
  res.json({ status: 'initializing', message: 'Backend is being deployed.' });
});

app.listen(port, () => {
  console.log(`Placeholder server listening on port 3000`);
});
JS_CONTENT

    # Install express
    cd /opt/banking-app
    npm init -y
    npm install express
}

# If backend application was downloaded successfully, extract it
if [ -f "/tmp/backend.zip" ]; then
    echo "Extracting backend application..."
    unzip -o /tmp/backend.zip -d /opt/banking-app
    rm -rf /tmp/backend.zip
    
    # Install backend dependencies
    cd /opt/banking-app
    npm ci --production
fi

# ====================================================================================
# SERVICE SETUP AND PERMISSIONS
# ====================================================================================
echo "Setting up backend service..."

# Create systemd service for the backend application
cat > /etc/systemd/system/${app_name}.service << SERVICE_CONFIG
[Unit]
Description=${app_name} Backend Service
After=network.target

[Service]
Type=simple
User=ec2-user
WorkingDirectory=/opt/banking-app
ExecStart=/usr/bin/node /opt/banking-app/server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=${app_name}
Environment=NODE_ENV=production
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
SERVICE_CONFIG

# Set proper permissions
echo "Setting permissions..."
chown -R ec2-user:ec2-user /opt/banking-app
chown -R nginx:nginx /var/www/html

# Start backend service
echo "Starting backend service..."
systemctl enable ${app_name}
systemctl start ${app_name}

# ====================================================================================
# FINALIZATION
# ====================================================================================
echo "Reloading Nginx..."
systemctl reload nginx

# Setup log rotation
cat > /etc/logrotate.d/${app_name} << 'LOGROTATE_CONFIG'
/var/log/app/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 ec2-user ec2-user
    sharedscripts
    postrotate
        systemctl reload ${app_name} >/dev/null 2>&1 || true
    endscript
}
LOGROTATE_CONFIG

echo "================================================================================"
echo "User data script completed: $(date)"
echo "================================================================================"