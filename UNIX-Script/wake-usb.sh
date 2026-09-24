#!/usr/bin/env bash

echo "=== Scan and Reset Connected Peripheral Devs ==="
if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then
  # Laptop
  SAFE_LIST=$(lsusb | grep -i -v -E "root hub|wireless|camera|bluetooth")
else
  # PC
  SAFE_LIST=$(lsusb | grep -i -v "root hub")
fi

if [ -z "$SAFE_LIST" ]; then
  echo "Not found any valid devices."
  read -n 1 -s -r -p "Press any key to exit..."
  echo ""
  exit 0
fi

echo "$SAFE_LIST" | awk '{printf "[%d] %s\n", NR, $0}'
echo ""

read -p "Input the process number: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]]; then 
  echo "Error: Invalid input!"
  sleep 2
  exit 1
fi

TARGET_ADDR=$(echo "$SAFE_LIST" | awk -v line="$choice" 'NR==line {print $2"/"$4}' | tr -d ':')
TARGET_NAME=$(echo "$SAFE_LIST" | awk -v line="$choice" 'NR==line {for(i=7;i<=NF;i++) printf "%s ", $i}')

if [ -n "$TARGET_ADDR" ]; then
  echo "Resetting port $TARGET_ADDR ($TARGET_NAME)..."
  sudo usbreset "$TARGET_ADDR"
  echo "Done!"
else
  echo "Not found [$choice]."
fi

echo ""
read -n 1 -s -r -p "Press any key to exit..."
echo ""