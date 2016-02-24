#!/bin/bash

# s03_results.sh
# Save results to NAS
# Alexey Larionov, 11Feb2016

# Read parameters
job_file="${1}"
scripts_folder="${2}"
pipeline_log="${3}"

# Update pipeline log
echo "Started making summaries and plots for merged wes samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Set environment and start job log
echo "Saving procecced bams and qvcfs to NAS"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"
echo ""

source "${scripts_folder}/a02_read_config.sh"
echo "Read settings"
echo ""

# Get list of samples
samples=$(awk 'NR>1 {print $1}' "${merged_folder}/samples.txt")

# Copy processed bams and gvcfs
rsync -thrve "ssh -x" "${processed_folder}" "${data_server}:${project_location}/${project}/${library}/"
exit_code_1="${?}"
rsync -thrve "ssh -x" "${gvcf_folder}" "${data_server}:${project_location}/${project}/${library}/"
exit_code_2="${?}"

# Stop if copying failed
if [ "${exit_code_1}" != "0" ] || \
   [ "${exit_code_2}" != "0" ]
then
  echo ""
  echo "Failed copying results to NAS"
  echo "Script terminated"
  echo ""
  exit
fi

# Progress messages
echo ""
echo "Completed saving results to NAS: $(date +%d%b%Y_%H:%M:%S)"
echo ""
echo "Saved results to NAS: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Change ownership (to allow user manipulating files later w/o administrative privileges)
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}/${library}/gvcfs"
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}/${library}/processed"
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}/${library}" # just in case...
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}" # just in case...
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}" # just in case...

# Progress messages
echo "Updated user name and group"
echo ""
echo "Completed all tasks"
echo ""

echo "Updated user name and group" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"
echo "Done all pipeline tasks" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Update logs on NAS
scp -qp "${logs_folder}/s03_save_results.log" "${data_server}:${project_location}/${project}/${library}/processed/f00_logs/s03_save_results.log"
scp -qp "${pipeline_log}" "${data_server}:${project_location}/${project}/${library}/processed/f00_logs/a00_pipeline.log" 

# Remove results from cluster 
if [ "${remove_project_folder}" == "yes" ] || [ "${remove_project_folder}" == "Yes" ] 
then 
  rm -fr "${project_folder}"
else
  rm -fr "${processed_folder}"
  rm -fr "${gvcf_folder}"
  rm -fr "${merged_folder}"
fi 

# Update logs on NAS
ssh -x "${data_server}" "echo \"Removed data from cluster\" >> ${project_location}/${project}/${library}/processed/f00_logs/s03_save_results.log"
ssh -x "${data_server}" "echo \"Removed data from cluster\" >> ${project_location}/${project}/${library}/processed/f00_logs/a00_pipeline.log"
