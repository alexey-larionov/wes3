#!/bin/bash

# a00_start_pipeline.sh
# Start annotating filtered vcfs with vep
# Alexey Larionov, 23Jan2016

## Read parameter
job_file="${1}"
scripts_folder="${2}"

# Read job's settings
source "${scripts_folder}/a02_read_config.sh"

# Start lane pipeline log
mkdir -p "${logs_folder}"
log="${logs_folder}/${dataset}_vep.log"

echo "WES library: annotating filtered vcfs with vep" > "${log}"
echo "${dataset} vep" >> "${log}" 
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
  "${scripts_folder}/s01_annotate_with_vep.sb.sh" \
  "${job_file}" \
  "${dataset}" \
  "${scripts_folder}" \
  "${logs_folder}" \
  "${log}"

# Update pipeline log
echo "" >> "${log}"
echo "Submitted s01_annotate_with_vep: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"
echo "" >> "${log}"