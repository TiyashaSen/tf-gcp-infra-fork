#Path to webapp folder
cd /opt/csye6225/webapp

#Create env and set variables
sudo touch .env

sudo tee .env <<EOF
PSQL_USERNAME=${psql_username}
PSQL_PASSWORD=${psql_password}
PSQL_DATABASE=${psql_database}
PSQL_HOSTNAME=${psql_hostname}
EOF

#Reload
sudo systemctl restart webappdev.service