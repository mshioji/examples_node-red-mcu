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

# install xs-dev
echo '### Installing xs-dev...'
sudo npm -g i xs-dev

# installing moddable SDK
echo '### Installing Moddable SDK...'
xs-dev setup

# installing ESP-IDF
echo '### Installing ESP-IDF...'
xs-dev setup --device esp32

echo '### finished.'
