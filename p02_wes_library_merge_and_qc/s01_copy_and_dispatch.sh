#!/bin/bash

# s01_copy_and_dispatch.sh
# Wes library merge pipeline
# Copy source files and dispatch samples to nodes
# Alexey Larionov, 11Feb2016

# Read parameters
job_file="${1}"
scripts_folder="${2}"
pipeline_log="${3}"

# Update pipeline log
echo "Started s01_copy_and_dispatch: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Set parameters
source "${scripts_folder}/a02_read_config.sh"
echo "Read settings"
echo ""

# ================= Make working folders on cluster ==================== #

mkdir -p "${merged_folder}"
mkdir -p "${bam_folder}"
mkdir -p "${flagstat_folder}"
mkdir -p "${picard_mkdup_folder}"
mkdir -p "${picard_inserts_folder}"
mkdir -p "${picard_alignment_folder}"
mkdir -p "${picard_hybridisation_folder}"
mkdir -p "${qualimap_results_folder}"
mkdir -p "${samstat_results_folder}"

mkdir -p "${gatk_diagnose_targets_folder}"
mkdir -p "${gatk_depth_of_coverage_folder}"
echo "Not yet implemented.  Hopefully I will do it later. AL30Sep2015" > "${gatk_diagnose_targets_folder}/not_yet_implemented.txt"
echo "Not yet implemented.  Hopefully I will do it later. AL30Sep2015" > "${gatk_depth_of_coverage_folder}/not_yet_implemented.txt"

# Progress update 
echo "Made working folders on cluster"
echo ""

# ============== Check consistency in lists of samples =============== #

echo "Getting lists of samples"
echo ""

# Copy samples lists for all lanes
for lane in ${lanes}
do
  rsync -thrve "ssh -x" "${data_server}:${project_location}/${project}/${library}/${lane}/samples.txt" "${merged_folder}/${lane}_samples.txt" 
  exit_code="${?}"

  # Stop if copying failed
  if [ "${exit_code}" != "0" ] 
  then
    echo ""
    echo "Failed getting source data from NAS"
    echo "Script terminated"
    echo ""
    exit
  fi
  
  echo ""

done

echo "Checking lists of samples"
echo ""

# Get sorted list of samples for the first lane
lanes_arr=(${lanes})
lane1="${lanes_arr[0]}"
samples=$(awk 'NR>1 {print $1}' "${merged_folder}/${lane1}_samples.txt" | sort)

# Note about sorting samples:
# Initially, the order of samples in the sample files was inconsistent:
# it depended on the speed of samples processing during the alignment step.
# This was the reason for sorting samples here.  Later I added sorting
# to the end of alignment step, so it became redundant here.  However, 
# sorting was left at both places for compartibility with some early data. 

# For all lanes
for lane in ${lanes}
do

  # Get list of samples for a lane
  samples_check=$(awk 'NR>1 {print $1}' "${merged_folder}/${lane}_samples.txt" | sort)
  
  # Check that samples are the same as in lane 1
  if [ "${samples_check}" == "${samples}" ]
  then
    echo "${lane} is OK"
  else
    echo ""
    echo "${lane}: inconsistent list of samples"
    echo "Script terminated"
    echo ""

    echo "" >> "${pipeline_log}"
    echo "Inconsistent lists of samples in ${lane}" >> "${pipeline_log}"
    echo "Script terminated" >> "${pipeline_log}"
    echo "" >> "${pipeline_log}"
    
    exit 1
  fi
done

# ================= Copy source split bams to cluster ================= #

# Progress report to the job log
echo ""
echo "Copying source split bam files to cluster"
echo ""

# For each sample
samples=$(awk 'NR>1 {print $1}' "${merged_folder}/${lane1}_samples.txt")
for sample in ${samples}
do

  # Progress report
  echo "Started ${sample}"
  echo ""
  
  # For each lane
  for lane in ${lanes}
  do
  
    # Copy data
    bam_file=$(awk -v sm="${sample}" '$1==sm {print $2}' "${merged_folder}/${lane}_samples.txt")
    rsync -thrve "ssh -x" "${data_server}:${project_location}/${project}/${library}/${lane}/${bam_file}" "${bam_folder}/"
    exit_code="${?}"

    # Stop if copying failed
    if [ "${exit_code}" != "0" ] 
    then
        echo ""
        echo "Failed getting source data from NAS"
        echo "Script terminated"
        echo ""
        exit
    fi
    
    echo ""
    
  done

  # Progress report
  echo "Done ${sample}"
  echo ""
  
done

# ================= Dispatch samples to nodes for processing ================= #

# Progress report
echo "Submitting samples to merge and QC"
echo ""

# Set time and account for pipeline submissions
slurm_time="--time=${time_merge_qc}"
slurm_account="--account=${account_merge_qc}"

# For each sample
for sample in ${samples}
do

  # Start pipeline on a separate node
  sbatch "${slurm_time}" "${slurm_account}" \
       "${scripts_folder}/s02_merge_and_qc.sb.sh" \
       "${sample}" \
       "${job_file}" \
       "${logs_folder}" \
       "${scripts_folder}" \
       "${pipeline_log}" &
  
  # Progress report
  echo "${sample}"
  
done # Next sample
echo ""

# Progress update 
echo "Submitted all samples: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Update pipeline log
echo "Completed s01_copy_and_dispatch: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"