#!/bin/bash

#put a "sleep 30" here if you run it at startup
#to make sure this starts after the nvidia driver does
#sleep 30

#temperature that should trigger 100% GPU fan utilization
MAX_GPU_TEMP=75

#IDs of GPUs in space seperated string
GPU_IDS="0 1"

#"cool enough" temp. The temperature below which we assign the baseline fan percentage - we don't care about temps below this
BASELINE_GPU_TEMP=35

#the minimum fan utilization percentage to which we assign all temps at or below the baseline gpu temp
BASELINE_FAN_PERCENTAGE=20

echo "GPU fan controller service started."

for gpu_id in $GPU_IDS; do
  DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 nvidia-settings -a [gpu:$GPU_ID]/GPUFanControlState=1 > /dev/null
done

HOSTNAME=$(hostname)
check=$(DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 nvidia-settings -a [fan:$GPU_ID]/GPUTargetFanSpeed=30 | tr -d [[:space:]])

working="Attribute'GPUTargetFanSpeed'($HOSTNAME:0fan:0)assignedvalue30."
if [[ $check != *$working ]]; then
    echo "error on fan speed assignment: $check"
    echo "Should be: $working"
    exit 1
fi
RATE_OF_CHANGE=$(echo "(100-$BASELINE_FAN_PERCENTAGE)/($MAX_GPU_TEMP-$BASELINE_GPU_TEMP)" | bc -l )

while true
do
  for gpu_id in $GPU_IDS; do
    degreesC=$(nvidia-smi -q -d TEMPERATURE -i $gpu_id | grep 'GPU Current Temp' | grep -o '[0-9]*')

    if (( $degreesC < $BASELINE_GPU_TEMP )); then
      fanSpeed=$BASELINE_FAN_PERCENTAGE
    else
      fanSpeed=$(echo "$RATE_OF_CHANGE * ($degreesC - $BASELINE_GPU_TEMP) + $BASELINE_FAN_PERCENTAGE" | bc -l | cut -d. -f1)
    fi

    if [[ $fanSpeed -gt 100 ]]; then
      fanSpeed=100
    fi

    echo "setting fan speed to $fanSpeed for gpu $gpu_id"

    DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 nvidia-settings -a [fan:$gpu_id]/GPUTargetFanSpeed=$fanSpeed > /dev/null
  done

  sleep 8
done