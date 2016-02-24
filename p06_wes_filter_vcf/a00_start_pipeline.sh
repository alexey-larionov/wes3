#!/bin/bash

# a00_start_pipeline.sh
# Start filtering vcf by DP, QUAL and VQSLOD
# Alexey Larionov, 06Feb2016

## Read parameter
job_file="${1}"
scripts_folder="${2}"

# Read job's settings
source "${scripts_folder}/a02_read_config.sh"

# Check the value of AF threshold
if [ "${fa_threshold}" != "no" ] && \
   [ "${fa_threshold}" != "90" ] && \
   [ "${fa_threshold}" != "95" ] && \
   [ "${fa_threshold}" != "99" ] && \
   [ "${fa_threshold}" != "100" ]
then
  echo "" 
  echo "Unexpected value for 1k ALT frequency threshold: ${fa_threshold}"
  echo ""
  echo "Allowed values: no, 90, 95, 99, 100"
  echo ""
  echo "Script terminated"
  echo "" 
  exit 1
fi

# Start lane pipeline log
mkdir -p "${logs_folder}"
log="${logs_folder}/${dataset_name}_${filter_name}.log"

echo "WES library: filtering vcf" > "${log}"
echo "${dataset_name} ${filter_name}" >> "${log}" 
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
  "${scripts_folder}/s01_filter_vcf.sb.sh" \
  "${job_file}" \
  "${dataset_name}" \
  "${filter_name}" \
  "${scripts_folder}" \
  "${logs_folder}" \
  "${log}"

# Update pipeline log
echo "" >> "${log}"
echo "Submitted s01_filter_vcf: $(date +%d%b%Y_%H:%M:%S)" >> "${log}"
echo "" >> "${log}"