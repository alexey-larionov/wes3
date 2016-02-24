#!/bin/bash

# a00_start_pipeline.sh
# Start exporting data to txt files
# Alexey Larionov, 26Jan2016

## Read parameter
job_file="${1}"
scripts_folder="${2}"

# Read job's settings
source "${scripts_folder}/a02_read_config.sh"

# Start lane pipeline log
mkdir -p "${logs_folder}"
log="${logs_folder}/${dataset}_export_txt.log"

echo "WES data analysis: exporting data to txt files" > "${log}"
echo "${dataset} export to txt" >> "${log}" 
echo "Started: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"
echo "" >> "${log}" 

echo "====================== Settings ======================" >> "${log}"
echo "" >> "${log}"

source "${scripts_folder}/a03_report_settings.sh" >> "${log}"

echo "=================== Pipeline steps ===================" >> "${log}"
echo "" >> "${log}"

# Submit job
slurm_time="--time=${time_to_request}"
slurm_account="--account=${account_to_use}"

sbatch "${slurm_time}" "${slurm_account}" \
  "${scripts_folder}/s01_export_txt.sb.sh" \
  "${job_file}" \
  "${dataset}" \
  "${scripts_folder}" \
  "${logs_folder}" \
  "${log}"

# Update pipeline log
echo "" >> "${log}"
echo "Submitted s01_export_txt: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"
echo "" >> "${log}"