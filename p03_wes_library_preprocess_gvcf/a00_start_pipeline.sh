#!/bin/bash

# a00_start_pipeline.sh
# Start wes library preprocess and gvcf pipeline
# Alexey Larionov, 21Sep2015

## Read parameter
job_file="${1}"
scripts_folder="${2}"

# Read job's settings
source "${scripts_folder}/a02_read_config.sh"

# Start lane pipeline log
mkdir -p "${logs_folder}"
pipeline_log="${logs_folder}/a00_pipeline.log"

echo "WES library: preprocess and make gvcf files" > "${pipeline_log}"
echo "Started: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

echo "====================== Settings ======================" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

source "${scripts_folder}/a03_report_settings.sh" >> "${pipeline_log}"

echo "=================== Pipeline steps ===================" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# ================= Make working folders on cluster ==================== #

mkdir -p "${dedup_bam_folder}"
mkdir -p "${proc_bam_folder}"
mkdir -p "${idr_folder}"
mkdir -p "${bqr_folder}"
mkdir -p "${gvcf_folder}"

# Progress update 
echo "Made working folders on cluster"
echo ""

# Start sample lists (may be used later in the variant calling step)
proc_bams_list_file="${processed_folder}/samples.txt"
gvcfs_list_file="${gvcf_folder}/samples.txt"

# Add header to the lane's samples list
echo -e "samples\tfiles" > "${proc_bams_list_file}"
echo -e "samples\tfiles" > "${gvcfs_list_file}"

# Progress report
echo "Started library's samples list (may be used later in the variant calling step)" >> "${pipeline_log}"

# Submit the first step to the queue
slurm_time="--time=${time_copy_in}"
slurm_account="--account=${account_copy_in}"
sbatch "${slurm_time}" "${slurm_account}" \
  "${scripts_folder}/s01_copy_and_dispatch.sb.sh" \
  "${job_file}" \
  "${logs_folder}" \
  "${scripts_folder}" \
  "${pipeline_log}"

# Update pipeline log
echo "Submitted s01_copy_and_dispatch: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
