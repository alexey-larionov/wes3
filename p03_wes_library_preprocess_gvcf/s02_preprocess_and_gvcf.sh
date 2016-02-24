#!/bin/bash

# s02_preprocess_and_gvcf.sh
# Bam preprocessing and making gvcf for a wes sample
# Alexey Larionov, 21Sep2015

# Read parameters
sample="${1}"
job_file="${2}"
scripts_folder="${3}"
pipeline_log="${4}"

# Update pipeline log
echo "Started bam preprocessing and making gvcf for ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Progress report to the job log
echo "Bam preprocessing and making gvcf for a wes sample"
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

# ------- Preparing targets for local realignment around indels ------- #

# Notes:

# Takes 10-20min for an initial dedupped bam of 5-10GB, whith up to 50% of 
# bases on targets.  Time estimates for the later steps refer to similar initial bams.     

# GATK tools supporting -nt option (RealignerTargetCreator and UnifyedGenotyper) require 
# more memory for running in parallel (-nt) than for running in a single-thread mode.
# Broad's web site suggests that RealignerTargetCreator with one data thread may need ~2G.
# Accordingly, in -nt 12 mode it would require ~24G.  Darwin node provide 60G, which is 
# more than enough to support -nt 12 run. 

# Progress report
echo "Preparing targets for local realignment around indels"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
dedup_bam="${dedup_bam_folder}/${sample}_dedup.bam"
idr_targets="${idr_folder}/${sample}_idr_targets.intervals"
idr_targets_log="${idr_folder}/${sample}_idr_targets.log"

# Process sample
"${java7}" -Xmx60g -jar "${gatk}" \
  -T RealignerTargetCreator \
	-R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -known "${indels_1k}" \
  -known "${indels_mills}" \
	-I "${dedup_bam}" \
  -o "${idr_targets}" \
  -nt 12 2> "${idr_targets_log}"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Performing local realignment around indels ------- #

# Notes:
# Takes 15-30min.
# -nt / -nct options are NOT available to paralellise IndelRealigner by multi-thrading: 
# this is one of the non-parallelisable bottlenecks when processing one sample at a time.
# -L at this step REMOVES all data outside of the target intervals from the output bam file.   
# To preserve all reads the -L option could be omitted at this step.

# Progress report
echo "Performing local realignment around indels"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
idr_bam="${proc_bam_folder}/${sample}_idr.bam"
idr_log="${idr_folder}/${sample}_idr.log"

# Process sample
"${java7}" -Xmx60g -jar "${gatk}" \
  -T IndelRealigner \
	-R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -targetIntervals "${idr_targets}" \
  -known "${indels_1k}" \
  -known "${indels_mills}" \
  -I "${dedup_bam}" \
  -o "${idr_bam}" 2> "${idr_log}"

# Remove dedup bam 
rm -f "${dedup_bam}"
rm -f "${dedup_bam%bam}bai"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# -- Check whether new PCR duplicates have been detected after realignment (remove, if any) -- #

# Notes:
# Takes 10-20min. 
# Some GATK Best Practices examples place the second dedup step after merging and local realignment.
# Dedup after merging is necessary without doubt.  Our pipeline already done dedup after merging.  
# Whether, in such case, an additional dedup may be needed again after realignment is questionable.  
# Empirically: this detects ~20-30 "new" duplicates per bam (less than 0.001% of reads). 
# Most likely they are not on the same site...  This shows that this step is not necessary and 
# can be removed leter. However, it is not difficult to keep this step for now. 

# MAX_FILE_HANDLES_FOR_READ_ENDS_MAP refers to the number of file handlers available for bash?
# ulimit -n

# Progress report
echo "Check whether new PCR duplicates have been detected after realignment (remove, if any)"

# File names
idr_dedup_bam="${proc_bam_folder}/${sample}_idr_dedup.bam"
idr_dedup_stats="${idr_folder}/${sample}_idr_dedup.txt"

# Process sample
"${java6}" -Xmx60g -jar "${picard}" MarkDuplicates \
  INPUT="${idr_bam}" \
  OUTPUT="${idr_dedup_bam}" \
  METRICS_FILE="${idr_dedup_stats}" \
  REMOVE_DUPLICATES=true \
  TMP_DIR="${bam_folder}" \
  MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000 \
  CREATE_INDEX=true \
  VERBOSITY=ERROR \
  QUIET=true

# Remove non-dedupped bam
rm -f "${idr_bam}"
rm -f "${idr_bam%bam}bai"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Making bqr tables before recalibration ------- #

# Notes:
# Takes 20-40min. 
# Running GATK with -nct option does not require more memory than running GATK in a single-thread mode.
# 60G memory, available on Darwin nodes, significantly exceed minimal requirement of ~4G mentioned on 
# Broad's web site for tools supperting -nct (BaseRecalibrator and PrintReads)

# Progress report
echo "Making bqr tables before recalibration"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
bqr_table_before="${bqr_folder}/${sample}_bqr_before.table"
bqr_table_before_log="${bqr_folder}/${sample}_bqr_table_before.log"

# Process sample
"${java7}" -Xmx60g -jar "${gatk}" \
  -T BaseRecalibrator \
	-R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -knownSites "${dbsnp}" \
  -knownSites "${indels_1k}" \
  -knownSites "${indels_mills}" \
	-I "${idr_dedup_bam}" \
  -o "${bqr_table_before}" \
  -nct 12 2> "${bqr_table_before_log}"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# -------------- Performing bqr ------------- #

# Note
# Takes 15-30min. 
# PrintReads is a generic tool that is used whider than in bqr context.
# In bqr context it prints reads adding the new recalibrated quality scores to bases.   
# If -L option is used, PrintReads REMOVES any reads outside of the target regions. 
# To preserve all reads the -L option could be omitted.   

# Progress report
echo "Performing bqr"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# Set files' names
idr_bqr_bam="${proc_bam_folder}/${sample}_idr_bqr.bam"
bqr_log="${bqr_folder}/${sample}_bqr.log"

# Process sample
"${java7}" -Xmx60g -jar "${gatk}" \
  -T PrintReads \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -BQSR "${bqr_table_before}" \
  -I "${idr_dedup_bam}" \
  -o "${idr_bqr_bam}" \
  -nct 12 2> "${bqr_log}"

# Make md5 for processed bams
cur_folder="$(pwd)"
cd "${proc_bam_folder}"
md5sum "${sample}_idr_bqr.bam" "${sample}_idr_bqr.bai" > "${sample}_idr_bqr.md5"
cd "${cur_folder}"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# -------------- Making bqr tables after recalibration ------------- #

# Note:
# Takes 40-60 min

# Progress report
echo "Making bqr tables after recalibration"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
bqr_table_after="${bqr_folder}/${sample}_bqr_after.table"
bqr_table_after_log="${bqr_folder}/${sample}_bqr_table_after.log"

# Process sample
"${java7}" -Xmx60g -jar "${gatk}" \
  -T BaseRecalibrator \
	-R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -knownSites "${dbsnp}" \
  -knownSites "${indels_1k}" \
  -knownSites "${indels_mills}" \
	-I "${idr_dedup_bam}" \
  -BQSR "${bqr_table_before}" \
  -o "${bqr_table_after}" \
  -nct 12 2> "${bqr_table_after_log}"

# Remove source bam
rm -f "${idr_dedup_bam}"
rm -f "${idr_dedup_bam%bam}bai"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# -------------- Making bqr plots ------------- #

# Notes:
# Takes 1-2min
# No bam file or targets file (-L option) is needed.
# No parallelism is required because it is a quick step. 

# Progress report
echo "Making bqr plots"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
bqr_plots="${bqr_folder}/${sample}_bqr_plots.pdf"
bqr_plots_data="${bqr_folder}/${sample}_bqr_plots_data.csv"
bqr_plots_log="${bqr_folder}/${sample}_bqr_plots.log"

# Process sample
"${java7}" -Xmx60g -jar "${gatk}" \
  -T AnalyzeCovariates \
  -R "${ref_genome}" \
  -before "${bqr_table_before}" \
  -after "${bqr_table_after}" \
  -plots "${bqr_plots}" \
  -csv "${bqr_plots_data}" 2> "${bqr_plots_log}"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# -------------- Calling variants in gvcf mode ------------- #

# Notes:
# Takes 1-2 hrs

# Progress report
echo "Calling variants in gvcf mode"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"

# File names
gvcf="${gvcf_folder}/${sample}.g.vcf"
gvcf_log="${gvcf_folder}/${sample}_gvcf.log"
gvcf_md5="${gvcf_folder}/${sample}_gvcf.md5"

# Run HaplotypeCaller in GVCF mode
"${java7}" -Xmx60g -jar "${gatk}" \
  -T HaplotypeCaller \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -I "${idr_bqr_bam}" \
  -o "${gvcf}" \
  -ERC GVCF \
  -nct 12 2> "${gvcf_log}"

# Make md5 for gvcf
cur_folder="$(pwd)"
cd "${gvcf_folder}"
md5sum $(basename "${gvcf}") > $(basename "${gvcf_md5}")
cd "${cur_folder}"

# Progress report
echo "Completed: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ----- Add sample to the sample lists ----- #
# may be needed for variants calling step later

proc_bams_list_file="${processed_folder}/samples.txt"
gvcfs_list_file="${gvcf_folder}/samples.txt"

proc_bam_file_name=$(basename "${idr_bqr_bam}")
gvcf_file_name=$(basename "${gvcf}")

echo -e "${sample}\tf01bams/${proc_bam_file_name}" >> "${proc_bams_list_file}"
echo -e "${sample}\t${gvcf_file_name}" >> "${gvcfs_list_file}"

# Progress report
echo "Added sample to the samples lists (may be used in the variant calling step later)"
echo ""

# ------------------- Update pipeline log  ------------------- #

echo "Completed ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# ------- Check completion of all samples, sort samples list and save results to NAS ------- #

# Get source samples file name
source_samples=$(awk 'NR>1 {print $1}' "${merged_folder}/samples.txt")

# Check that file samples still exists 
# (odd things may happen on a shared area on cluster...) 
if [ -e "${source_samples}" ]
then
  echo "Script terminated with error because samples file vanished:"
  echo "${merged_folder}/samples.txt"
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
  
  # Reorder bams list according to the initial order of samples
  proc_bams_tmp=$(mktemp "${proc_bams_list_file}.tmp.XXXX")
  cp -f "${proc_bams_list_file}" "${proc_bams_tmp}"
  
  header=$(head -n 1 "${proc_bams_tmp}")
  echo "${header}" > "${proc_bams_list_file}"
  
  for sample in $source_samples
  do
    cur_line=$(awk -v smp="${sample}" '$1==smp {print}' "${proc_bams_tmp}")
    echo "${cur_line}" >> "${proc_bams_list_file}"
  done
  
  rm -f "${proc_bams_tmp}"

  # Reorder gvcfs list according to the initial order of samples
  gvcfs_list_tmp=$(mktemp "${gvcfs_list_file}.tmp.XXXX")
  cp -f "${gvcfs_list_file}" "${gvcfs_list_tmp}"
  
  header=$(head -n 1 "${gvcfs_list_tmp}")
  echo "${header}" > "${gvcfs_list_file}"
  
  for sample in $source_samples
  do
    cur_line=$(awk -v smp="${sample}" '$1==smp {print}' "${gvcfs_list_tmp}")
    echo "${cur_line}" >> "${gvcfs_list_file}"
  done
  
  rm -f "${gvcfs_list_tmp}"

  # Report to pipeline log
  echo "" >> "${pipeline_log}"
  echo "Completed all samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

  # Report to sample log
  echo "Completed all samples"
  echo "Submitting job to save results to NAS"

  # Set time and account for pipeline submissions
  slurm_time="--time=${time_move_out}"
  slurm_account="--account=${account_move_out}"

  # Submit job to save results to NAS
  sbatch "${slurm_time}" "${slurm_account}" \
       "${scripts_folder}/s03_save_results.sb.sh" \
       "${job_file}" \
       "${logs_folder}" \
       "${scripts_folder}" \
       "${pipeline_log}"

  # Report to pipeline log
  echo "Submitted job to save results to NAS" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"

  echo ""
  
fi

# ------- Completion ------- #

# Update sample log
echo "Completed sample pipeline: $(date +%d%b%Y_%H:%M:%S)"
echo ""
