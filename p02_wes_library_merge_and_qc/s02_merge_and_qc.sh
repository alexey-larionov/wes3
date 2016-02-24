#!/bin/bash

# s02_merge_and_qc.sh
# Merge and qc bams for a wes sample
# Alexey Larionov, 23Aug2015

# Read parameters
sample="${1}"
job_file="${2}"
scripts_folder="${3}"
pipeline_log="${4}"

# Update pipeline log
echo "Started merging and QC for ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Progress report to the job log
echo "Merging and preprocessing bams for a wes sample"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"
echo ""
echo "sample: ${sample}"
echo ""

echo "====================== Settings ======================"
echo ""

source "${scripts_folder}/a02_read_config.sh"
source "${scripts_folder}/a03_report_settings.sh"

echo "====================================================="
echo ""

# ------- Merge and sort ------- #

# Merged bam file name
merged_raw_bam="${bam_folder}/${sample}_raw.bam"
sort_bam="${bam_folder}/${sample}_sort.bam"

# Check number of lanes
lanes_count=$(wc -w <<< "${lanes}")
if [ "${lanes_count}" == "1" ]
then

  # There is a single source bam file
  input_bam="${bam_folder}/${sample}_${lanes}_fixmate_sort_rg.bam"

  # Rename the source file
  # No need to merge and sort, if a single lane is used
  mv -f "${input_bam}" "${sort_bam}"

  # Progress report
  echo "No need to merge and sort source bam for one lane analysis"
  echo ""

# If multiple lanes are given
else

  # --- Merge --- #

  # Progress report
  echo "Started merging source bams: $(date +%d%b%Y_%H:%M:%S)"
  
  # Make source bams list
  bams_list=""
  for lane in ${lanes}
  do
    input_bam="${bam_folder}/${sample}_${lane}_fixmate_sort_rg.bam"
    bams_list="${bams_list} ${input_bam}"
  done
  
  # Merge source bams
  # -f forces to overwrite the output file if present
  "${samtools}" merge -f "${merged_raw_bam}" ${bams_list}

  # Remove source bams
  rm -f ${bams_list}
  
  echo ""
  echo "rm -f ${bams_list}"
  echo ""

  # Progress report
  echo "Completed merging source bams: $(date +%d%b%Y_%H:%M:%S)"
  echo ""
  
  # --- Sort --- #
  
  # Progress report
  echo "Started sorting merged bam"
  
  # Sort using samtools (later may be switched to picard SortSam)
  ${samtools} sort -o "${sort_bam}" -T "${sort_bam/_sort.bam/_sort_tmp}_${RANDOM}" "${merged_raw_bam}"
  
  # Remove raw bam
  rm -f "${merged_raw_bam}"

  # Progress report
  echo "Completed sorting merged bam: $(date +%d%b%Y_%H:%M:%S)"
  echo ""
  
fi

# ------- Mark duplicates ------- #

# Progress report
echo "Started marking PCR duplicates"

# File names
mkdup_bam="${bam_folder}/${sample}_mkdup.bam"
mkdup_stats="${picard_mkdup_folder}/${sample}_mkdup.txt"
  
# Process sample
"${java6}" -Xmx60g -jar "${picard}" MarkDuplicates \
  INPUT="${sort_bam}" \
  OUTPUT="${mkdup_bam}" \
  METRICS_FILE="${mkdup_stats}" \
  REMOVE_DUPLICATES=false \
  TMP_DIR="${bam_folder}" \
  MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000 \
  CREATE_INDEX=true \
  VERBOSITY=ERROR \
  QUIET=true

# Notes about MarkDuplicates options:

# Mkdup writes many temporary files on disk (gigabaites).  
# This may generate error, if /tmp folder size is insufficient.  
# To avoid this error, an explicit address for tmp folder may be used. 

# Another parameter that may need to be controlled: the max num of 
# file handlers per process.  On Darwin cores it is set to 1024 (ulimit -n)
# Hence the MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000

# Remove non-mkdupped bam
rm -f "${sort_bam}"

# Progress report
echo "Completed marking PCR duplicates: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect flagstat metrics ------- #

# Progress report
echo "Started collecting flagstat metrics"

# flagstats metrics file name
flagstats="${flagstat_folder}/${sample}_flagstat.txt"

# Sort using samtools (later may be switched to picard SortSam)
${samtools} flagstat "${mkdup_bam}" > "${flagstats}"

# Progress report
echo "Completed collecting flagstat metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --------- Remove duplicates --------- #

# Progress report
echo "Started removing PCR duplicates"

# File names
dedup_bam="${bam_folder}/${sample}_dedup.bam"

# Remove records flagged as duplicates
"${samtools}" view -b -F 1024 -o "${dedup_bam}" "${mkdup_bam}"

# Remove non-dedupped bam
rm -f "${mkdup_bam}"
rm -f "${mkdup_bam%bam}bai"

# Progress report
echo "Completed removing PCR duplicates: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Index dedupped file ------- #

# Progress report
echo "Started building dedupped bam index"

# File names
dedup_bai="${bam_folder}/${sample}_dedup.bai"

# make index
"${java6}" -Xmx60g -jar "${picard}" BuildBamIndex \
  INPUT="${dedup_bam}" \
  OUTPUT="${dedup_bai}" \
  VERBOSITY=ERROR \
  QUIET=true

# Progress report
echo "Completed building dedupped bam index: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- md5 dedupped file ------- #

# Progress report
echo "Started calculating md5 sums for dedupped bam with index"

# Go to bam folder to avoid path in md5 file
cur_folder=$(pwd)
cd "${bam_folder}"

# File names
md5="${sample}_dedup.md5"
bam=$(basename "${dedup_bam}")
bai=$(basename "${dedup_bai}")

# make index
md5sum "${bam}" "${bai}" > "${md5}"

# Return back to scripts folder
cd "${cur_folder}"

# Progress report
echo "Completed calculating md5 sums for dedupped bam with index: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect inserts sizes ------- #

# Progress report
echo "Started collecting inserts sizes"

# Stats files names
inserts_stats="${picard_inserts_folder}/${sample}_insert_sizes.txt"
inserts_plot="${picard_inserts_folder}/${sample}_insert_sizes.pdf"

# Process sample
"${java6}" -Xmx20g -jar "${picard}" CollectInsertSizeMetrics \
  INPUT="${dedup_bam}" \
  OUTPUT="${inserts_stats}" \
  HISTOGRAM_FILE="${inserts_plot}" \
  VERBOSITY=ERROR \
  QUIET=true &

# Done in parallel with two other picard stats, which are
# started below. Hence akward Xmx20 to assure enough memory
# for each tool (it's more than plenty anyway). 
# Requires Rscript in the path.  

# ------- Collect alignment summary metrics ------- #

# Progress report
echo "Started collecting alignment summary metrics"

# Mkdup stats file names
alignment_metrics="${picard_alignment_folder}/${sample}_as_metrics.txt"

# Process sample (using default adapters list)
"${java6}" -Xmx20g -jar "${picard}" CollectAlignmentSummaryMetrics \
  INPUT="${dedup_bam}" \
  OUTPUT="${alignment_metrics}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  VERBOSITY=ERROR \
  QUIET=true &

# Runs in parallel with two other tools; hence Xmx20

# ------- Collect hybridisation selection metrics ------- #

# Progress report
echo "Started collecting hybridisation selection metrics"

# Stats file names
hs_metrics="${picard_hybridisation_folder}/${sample}_hs_metrics.txt"
hs_coverage="${picard_hybridisation_folder}/${sample}_hs_coverage.txt"

# Process sample (using b37 interval lists)
"${java6}" -Xmx20g -jar "${picard}" CalculateHsMetrics \
  BAIT_SET_NAME="${hs_metrics_probes_name}" \
  BAIT_INTERVALS="${nextera_probes_intervals}" \
  TARGET_INTERVALS="${nextera_targets_intervals}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  INPUT="${dedup_bam}" \
  OUTPUT="${hs_metrics}" \
  PER_TARGET_COVERAGE="${hs_coverage}" \
  VERBOSITY=ERROR \
  QUIET=true &

# Runs in parallel with two other tools; hence Xmx20

# Wait until all picard metrics are calculated and report progress
wait
echo "Completed collecting various picard metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Qualimap ------- #

# Progress report
echo "Started qualimap"

# Folder for sample
qualimap_sample_folder="${qualimap_results_folder}/${sample}"
mkdir -p "${qualimap_sample_folder}"

# Variable to reset default memory settings for qualimap
export JAVA_OPTS="-Xms1G -Xmx60G"

# Start qualimap
qualimap_log="${qualimap_sample_folder}/${sample}.log"
"${qualimap}" bamqc \
  -bam "${dedup_bam}" \
  --paint-chromosome-limits \
  --genome-gc-distr HUMAN \
  --feature-file "${nextera_targets_bed_6}" \
  --outside-stats \
  -nt 14 \
  -outdir "${qualimap_sample_folder}" &> "${qualimap_log}"

# Progress report
echo "Completed qualimap: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Samstat ------- #

# Progress report
echo "Started samstat"

# Run sumstat
samstat_log="${samstat_results_folder}/${sample}_samstat.log"
"${samstat}" "${dedup_bam}" &> "${samstat_log}"

# Move results to the designated folder
samstat_source="${dedup_bam}.samstat.html"
samstat_target=$(basename "${dedup_bam}.samstat.html")
samstat_target="${samstat_results_folder}/${samstat_target}"
mv -f "${samstat_source}" "${samstat_target}"

# Progress report
echo "Completed samstat: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ----- Add sample to the library's sample list ----- #
# may be needed for variants calling step later

merged_samples_file="${merged_folder}/samples.txt"

bam_file_name=$(basename "${dedup_bam}")
bam_file_name="f01_bams/${bam_file_name}"
echo -e "${sample}\t${bam_file_name}" >> "${merged_samples_file}"

# Progress report
echo "Added sample to the library's sample list (may be used in the variant calling step later)"
echo ""

# ------------------- Update pipeline log  ------------------- #

echo "Completed ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# ------- Plot summary QC reports for multiple samples ------- #

# Get source samples file name
# Get sorted list of samples for the first lane
lanes_arr=(${lanes})
lane1="${lanes_arr[0]}"
source_samples=$(awk 'NR>1 {print $1}' "${merged_folder}/${lane1}_samples.txt")

# Check that file still exists and samples have been red 
# (many things may happen on a shared area on cluster...) 
if [ -z "${source_samples}" ]
then
  echo "Script terminated with error because samples"
  echo "could not be red from the following file:"
  echo "${merged_folder}/${lane1}_samples.txt"
  exit 1
fi

# Set flag as if all samples were completed
all_completed="yes"

# For each sample
for sample in $source_samples
do

  # Look for completion record in pipeline log
  sample_check=$(grep "^Completed ${sample}:" "${pipeline_log}")
  
  # Update flag if no completion record has been found
  if [ -z "${sample_check}" ]
  then
    all_completed="no"
    break
  fi
done

# If all samples have been completed
if [ "${all_completed}" == "yes" ]
then
  
  # Reorder library samples file according to the initial order of samples in the lanes
  merged_samples_temp=$(mktemp "${merged_samples_file}.tmp.XXXX")
  cp -f "${merged_samples_file}" "${merged_samples_temp}"
  
  header=$(head -n 1 "${merged_samples_temp}")
  echo "${header}" > "${merged_samples_file}"
  
  for sample in $source_samples
  do
    cur_line=$(awk -v smp="${sample}" '$1==smp {print}' "${merged_samples_temp}")
    echo "${cur_line}" >> "${merged_samples_file}"
  done
  
  rm -f "${merged_samples_temp}"

  # Report to pipeline
  echo "" >> "${pipeline_log}"
  echo "Completed all samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

  # Report to sample log
  echo "Completed all samples"
  echo "Submitting job to collect and plot summary metrics"

  # Set time and account for pipeline submissions
  slurm_time="--time=${time_move_out}"
  slurm_account="--account=${account_move_out}"

  # Submit job to plot summary metrics and save results to NAS
  sbatch "${slurm_time}" "${slurm_account}" \
       "${scripts_folder}/s03_summarise_and_save.sb.sh" \
       "${job_file}" \
       "${logs_folder}" \
       "${scripts_folder}" \
       "${pipeline_log}"

  # Report to pipeline log
  echo "Submitted job to plot summary metrics and save results to NAS" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"

  echo ""
  
fi

# ------- Completion ------- #

# Update sample log
echo "Completed sample pipeline: $(date +%d%b%Y_%H:%M:%S)"
echo ""
