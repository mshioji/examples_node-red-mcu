#!/bin/bash

echo "### Installing Node.js and npm..."
if command -v node &> /dev/null && command -v npm &> /dev/null; then
    echo "### Node.js and npm are already installed. Skipping installation."
else
    echo "### Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt install nodejs -y
fi
echo "### Node.js version:"
node -v
echo "### npm version:"
npm -v

# install node-red, Node-red-mcu

echo "Installing Node-RED..."
sudo npm install -g --unsafe-perm node-red

# creating Node-RED Unit file
echo "### Creating Node-RED systemd service file..."
NODE_RED_USER=$(whoami)
NODE_RED_GROUP=$(id -gn)
NODE_RED_HOME=$HOME

cat <<EOF | sudo tee /lib/systemd/system/nodered.service > /dev/null
# systemd service file to start Node-RED

[Unit]
Description=Node-RED graphical event wiring tool
Wants=network.target
Documentation=http://nodered.org/docs/hardware/raspberrypi.html

[Service]
Type=simple
# Run as the current user
User=$NODE_RED_USER
Group=$NODE_RED_GROUP
WorkingDirectory=$NODE_RED_HOME

Environment="NODE_OPTIONS=--max_old_space_size=2048"
# define an optional environment file in Node-RED's user directory to set custom variables externally
EnvironmentFile=-$NODE_RED_HOME/.node-red/environment
# uncomment and edit next line if you need an http proxy
#Environment="HTTP_PROXY=my.httpproxy.server.address"
# uncomment the next line for a more verbose log output
#Environment="NODE_RED_OPTIONS=-v"
# uncomment next line if you need to wait for time sync before starting
#ExecStartPre=/bin/bash -c '/bin/journalctl -b -u systemd-timesyncd | /bin/grep -q "systemd-timesyncd.* Synchronized to time server"'

ExecStart=/usr/bin/env node-red-pi \$NODE_OPTIONS -- \$NODE_RED_OPTIONS
#ExecStart=/usr/bin/env node \$NODE_OPTIONS red.js -- \$NODE_RED_OPTIONS
# Use SIGINT to stop
KillSignal=SIGINT
# Auto restart on crash
Restart=on-failure
RestartSec=20
# Tag things in the log
SyslogIdentifier=Node-RED
#StandardOutput=syslog

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 644 /lib/systemd/system/nodered.service

# Node-RED user directory
USER_DIR="$HOME/.node-red"
if [ ! -d "$USER_DIR" ]; then
    echo "Creating Node-RED user directory at $USER_DIR..."
    mkdir -p "$USER_DIR"
fi

# log setting
LOG_FILE="$USER_DIR/node-red.log"

# first run Node-RED to create settings.js
echo "Starting Node-RED to generate settings.js..."
node-red --userDir $USER_DIR --safe > "$LOG_FILE" 2>&1 &
NODE_RED_PID=$!
sleep 5

# stop Node-RED
echo "Stopping Node-RED after settings.js generation..."
kill $NODE_RED_PID 2>/dev/null || true

# modify settings.js
SETTINGS_FILE="$USER_DIR/settings.js"
if [ -f "$SETTINGS_FILE" ]; then
    echo "Modifying settings.js..."

    # add process.env.MODDABLE
    if ! grep -q "process.env.MODDABLE" "$SETTINGS_FILE"; then
        echo "process.env.MODDABLE = '$HOME/.local/share/moddable';" >> "$SETTINGS_FILE"
        echo "Added process.env.MODDABLE setting."
    else
        echo "process.env.MODDABLE setting already exists. Skipping."
    fi

    # add adminAuth setting
    if grep -qE "^\s*adminAuth:" "$SETTINGS_FILE"; then
        echo "adminAuth setting is already enabled. Skipping."
    else
        sed -i '/module.exports = {/a \  adminAuth: { type: "credentials", users: [{ username: "admin", password: "$2y$08$g4OQQdpKaDVV6q.xUFIx.u0RZtOeENgGEJfLu9D5XvBWO.RkI4gg6", permissions: "*" }] },' "$SETTINGS_FILE"
        echo "Added new adminAuth setting."
    fi
else
    echo "Error: settings.js not found in $USER_DIR. Exiting."
    exit 1
fi


# install plugin and additional nodes
echo "### Installing plugin and additional nodes..."
cd "$USER_DIR"

echo " ## Installing node-red-mcu-plugin..."
npm i @ralphwetzel/node-red-mcu-plugin

echo " ## Installing mcu nodes..."
npm i @moddable-node-red/mcu

echo " ## Installing node-red-dashboard..."
npm i node-red-dashboard

#echo " ## Installing node-red-node-pi-gpio..."
#npm i node-red-node-pi-gpio

#echo " ## Installing node-red-contrib-ui-led..."
#npm i node-red-contrib-ui-led

#echo " ## Installing node-red-contrib-moment..."
#npm i node-red-contrib-moment

#echo " ## Installing node-red-contrib-aedes..."
#npm i node-red-contrib-aedes

# enable Node-RED service
echo "### enabling Node-RED..."
sudo systemctl daemon-reload
sudo systemctl enable nodered.service
sudo systemctl start nodered.service

echo '### finished.'
