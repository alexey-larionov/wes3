#!/bin/bash

# u01_res_monitor.sh
# Recording load and memory usage
# Alexey Larionov, 10Jul2015

# Use: 
# u01_res_monitor.sh time_increment_min time_max log_file
# u01_res_monitor.sh 1 test.res

# Read parameters
time_increment_min="${1}"
log_file="${2}"

# Quick check of the user's input
if [ "${time_increment_min}" == "-h" ] || [ "${time_increment_min}" == "--help" ] || [ -z "${time_increment_min}" ] || [ -z "${log_file}" ]
then
  echo ""
  echo "Recording load and memory usage"
  echo ""
  echo "Usage:" 
  echo "u01_node_stats.sh time_increment_min log_file"
  echo ""
  echo "Example:"
  echo "u01_node_stats.sh 1 test.res"
  echo ""
  echo "Notes:"
  echo "- Script starts infinite loop that never stops by itself"
  echo "  Script has to be stopped from outside, when monitoring is no longer necessary"
  echo "- If log file exists, it will be re-written"
  echo "- Time increment is in minutes"
  echo ""
  echo "Alexey Larionov, 10Jul2015"
  echo ""
  exit 1
fi

# Write header to log file
echo -e "time\tload\tram" > "${log_file}"

# Convert time increment into seconds
time_increment_sec=$(( ${time_increment_min} * 60 ))

# Start endless loop
time_min="0"
while true
do

  # Read load and memory usage 
  uptime_string="$(uptime)"
  loads=${uptime_string#*average:}
  load=$(echo ${loads} | awk 'BEGIN { FS = "," } ; {print $1}')
  ram=$(free -g | grep Mem: | awk '{print $3}')
  
  # Increment time
  time_min=$(( ${time_min} + ${time_increment_min} ))
  
  # Write the stats to log
  echo -e "${time_min}\t${load}\t${ram}" >> "${log_file}"
  
  # Pause for the required interval
  sleep "${time_increment_sec}" 
  
done # Next readings
