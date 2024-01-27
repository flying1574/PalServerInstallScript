#!/bin/bash

steam_user=steam
log_path=/tmp/pal_server.log

if getent passwd "$steam_user" >/dev/null 2>&1; then
    echo "User $steam_user exists."
else
    echo "User $steam_user does not exist.Adding $steam_user ..."
    sudo useradd -m -s /bin/bash $steam_user
fi

echo "Installing SteamCMD..."

sudo add-apt-repository multiverse -y > $log_path
sudo dpkg --add-architecture i386 >> $log_path
sudo apt-get update -y >> $log_path
sudo apt-get remove needrestart -y >> $log_path

echo steam steam/license note '' | sudo debconf-set-selections 
echo steam steam/question select "I AGREE" | sudo debconf-set-selections 
sudo apt-get install steamcmd -y >> $log_path

steam_user_path=~steam
steamcmd_path=$(whereis steamcmd|awk '{print $2}')

sudo -u $steam_user mkdir -p $steam_user_path/.steam/sdk64/ >> $log_path
echo "Downloading palServer..."
sudo -u $steam_user $steamcmd_path +login anonymous +app_update 1007 validate +quit >> $log_path
sudo -u $steam_user $steamcmd_path +login anonymous +app_update 2394010 validate +quit >> $log_path

sudo cp $steam_user_path/Steam/steamapps/common/Steamworks\ SDK\ Redist/linux64/steamclient.so $steam_user_path/.steam/sdk64/

systemd_unit=pal-server
cat <<EOF > $systemd_unit.service
[Unit]
Description=$systemd_unit.service

[Service]
Type=simple
User=$steam_user
Restart=on-failure
RestartSec=30s
ExecStart=$steam_user_path/Steam/steamapps/common/PalServer/PalServer.sh -useperfthreads -NoAsyncLoadingThread -UseMultithreadForDS

[Install]
WantedBy=multi-user.target
EOF

sudo mv $systemd_unit.service /usr/lib/systemd/system/
echo "Starting palServer..."
sudo systemctl enable $systemd_unit
sudo systemctl restart $systemd_unit
sudo systemctl -l --no-pager status $systemd_unit

if systemctl --quiet is-active "$systemd_unit"
then
    echo -e "\nPalServer is running successfully, enjoy!"
else
    echo -e "\nThere were some problems with the installation, please check the log $log_path."
fi
