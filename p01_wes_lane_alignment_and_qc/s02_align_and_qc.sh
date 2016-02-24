#!/bin/bash

# s02_align_and_qc.sh
# Wes sample alignment and QC
# Alexey Larionov, 21Aug2015

# Read parameters
sample="${1}"
job_file="${2}"
scripts_folder="${3}"
pipeline_log="${4}"

# Update pipeline log
echo "Started ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Progress report to the job log
echo "Wes sample alignment and QC"
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

# ------- FastQC before trimming ------- #

# Progress report
echo "Started FastQC before trimming"

# Set fastq folder depending on the use of contents.csv
if [ "${use_contents_csv}" == "yes" ] || [ "${use_contents_csv}" == "Yes" ]
then
  source_fastq_folder="${renamed_fastq_folder}"
fi

# Get samples file
samples_file="${source_fastq_folder}/samples.txt"

# Get names of fastq files
fastq_1=$(awk -v s="${sample}" '$1==s {print $2}' "${samples_file}")
raw_fastq_1="${source_fastq_folder}/${fastq_1}"

fastq_2=$(awk -v s="${sample}" '$1==s {print $3}' "${samples_file}")
raw_fastq_2="${source_fastq_folder}/${fastq_2}"

# FastQC read 1 and read 2 in parallel
"${fastqc}" --quiet --noextract -j "${java8}" -o "${fastqc_raw_folder}" "${raw_fastq_1}" &
"${fastqc}" --quiet --noextract -j "${java8}" -o "${fastqc_raw_folder}" "${raw_fastq_2}" &

# Wait for completion of both reads and report progress
wait
echo "Completed FastQC before trimming: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Trimming of fastq files ------- #

# Progress report
echo "Started trimming of fastq files"

# File names
trimmed_fastq_1="${trimmed_fastq_folder}/${fastq_1/.fq.gz/_trim.fq.gz}"
trimmed_fastq_2="${trimmed_fastq_folder}/${fastq_2/.fq.gz/_trim.fq.gz}"
trimming_log="${trimmed_fastq_folder}/${sample}_trimming.log"

# Submit sample to cutadapt
"${cutadapt}" \
  -q "${cutadapt_trim_qual}" \
  -m "${cutadapt_min_len}" \
  -a "${cutadapt_adapter_1}" \
  -A "${cutadapt_adapter_2}" \
  -o "${trimmed_fastq_1}" \
  -p "${trimmed_fastq_2}" \
  "${raw_fastq_1}" "${raw_fastq_2}" > "${trimming_log}"

# Progress report
echo "Completed trimming of fastq files: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- FastQC after trimming ------- #

# Progress report
echo "Started FastQC after trimming"

# FastQC read 1 and read 2 in parallel
"${fastqc}" --quiet --noextract -j "${java8}" -o "${fastqc_trimmed_folder}" "${trimmed_fastq_1}" &
"${fastqc}" --quiet --noextract -j "${java8}" -o "${fastqc_trimmed_folder}" "${trimmed_fastq_2}" &

# Wait for completion of both reads and report progress
wait
echo "Completed FastQC after trimming: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Alignment ------- #

# Progress report
echo "Started alignment"

# File names
raw_bam_file="${sample}_raw.bam"
raw_bam="${bam_folder}/${raw_bam_file}"

alignment_log="${sample}_${lane}_alignment.log"
alignment_log="${bam_folder}/${alignment_log}"

# Submit sample for alignment and immediately 
# convert outputted SAM to BAM (using samtools)
"${bwa}" mem -M -t 14 "${bwa_index}" \
  "${trimmed_fastq_1}" "${trimmed_fastq_2}" 2>> "${alignment_log}" | \
  "${samtools}" view -b - > "${raw_bam}"

# Options:
# -t  Number of threads
# -M  Mark shorter split hits as secondary (for Picard compatibility)

# Remove trimmed fastq
rm -f "${trimmed_fastq_1}" "${trimmed_fastq_2}"

# Progress report
echo "Completed alignment: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Sort by name ------- #

# Progress report
echo "Started sorting by name (required by fixmate)"

# Sorted bam file name
nsort_bam_file="${sample}_${lane}_nsort.bam"
nsort_bam="${bam_folder}/${nsort_bam_file}"

# Sort using samtools (later may be switched to picard SortSam)
${samtools} sort -n -o "${nsort_bam}" -T "${nsort_bam/_nsort.bam/_nsort_tmp}_${RANDOM}" "${raw_bam}"

# Remove raw bam
rm -f "${raw_bam}"

# Progress report
echo "Completed sorting by name: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Fixmate ------- #

# Progress report
echo "Started fixing mate-pairs"

# Fixmated bam file name  
fixmate_bam_file="${sample}_${lane}_fixmate.bam"
fixmate_bam="${bam_folder}/${fixmate_bam_file}"
  
# Fixmate (later may be switched to Picard FixMateInformation)
${samtools} fixmate "${nsort_bam}" "${fixmate_bam}"

# Remove nsorted bam
rm -f "${nsort_bam}"

# Progress report
echo "Completed fixing mate-pairs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Sort by coortdinate ------- #

# Progress report
echo "Started sorting by coordinate"

# Sorted bam file name
sort_bam_file="${sample}_${lane}_fixmate_sort.bam"
sort_bam="${bam_folder}/${sort_bam_file}"

# Sort using samtools (later may be switched to picard SortSam)
${samtools} sort -o "${sort_bam}" -T "${sort_bam/_sort.bam/_sort_tmp}_${RANDOM}" "${fixmate_bam}"

# Remove fixmated bam
rm -f "${fixmate_bam}"

# Progress report
echo "Completed sorting by coordinate: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Add RG and index ------- #

# Progress report
echo "Started adding read group information"

# File name for bam with RGs
rg_bam_file="${sample}_${lane}_fixmate_sort_rg.bam"
rg_bam="${bam_folder}/${rg_bam_file}"

# Add read groups
"${java6}" -Xmx60g -jar "${picard}" AddOrReplaceReadGroups \
  INPUT="${sort_bam}" \
  OUTPUT="${rg_bam}" \
 	RGID="${sample}_${project}_${library}_${lane}" \
 	RGLB="${project}_${library}" \
 	RGPL="${platform}" \
 	RGPU="${project}_${library}_${lane}" \
 	RGSM="${sample}" \
 	VERBOSITY=ERROR \
  CREATE_MD5_FILE=true \
  CREATE_INDEX=true \
 	QUIET=true

# Note: 
# md5 created for it's the final bam (mkdupped will be removed)...
# The MD5 file is of special format: it contains md5 sum only, without the file name

# Remove bam without RG
rm -f "${sort_bam}"

# Progress report
echo "Completed indexing and adding read group information: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Mark duplicates ------- #

# Progress report
echo "Started marking PCR duplicates"

# Mkdup bam name
mkdup_bam_file="${sample}_${lane}_fixmate_sort_rg_mkdup.bam"
mkdup_bam="${bam_folder}/${mkdup_bam_file}"

# Mkdup stats file name
mkdup_stats_file="${sample}_mkdup.txt"
mkdup_stats="${picard_mkdup_folder}/${mkdup_stats_file}"
  
# Process sample
"${java6}" -Xmx60g -jar "${picard}" MarkDuplicates \
  INPUT="${rg_bam}" \
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

# Progress report
echo "Completed marking PCR duplicates: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect flagstat metrics ------- #

# Progress report
echo "Started collecting flagstat metrics"

# flagstats metrics file name
flagstats_file="${sample}_flagstat.txt"
flagstats="${flagstat_folder}/${flagstats_file}"

# Sort using samtools (later may be switched to picard SortSam)
${samtools} flagstat "${mkdup_bam}" > "${flagstats}"

# Progress report
echo "Completed collecting flagstat metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect inserts sizes ------- #

# Progress report
echo "Started collecting inserts sizes"

# Stats files names
inserts_stats="${picard_inserts_folder}/${sample}_insert_sizes.txt"
inserts_plot="${picard_inserts_folder}/${sample}_insert_sizes.pdf"

# Process sample
"${java6}" -Xmx20g -jar "${picard}" CollectInsertSizeMetrics \
  INPUT="${mkdup_bam}" \
  OUTPUT="${inserts_stats}" \
  HISTOGRAM_FILE="${inserts_plot}" \
  VERBOSITY=ERROR \
  QUIET=true &

# .. in parallel with other stats started after this .. hence akward Xmx15
# add R to path ... 

# ------- Collect alignment summary metrics ------- #

# Progress report
echo "Started collecting alignment summary metrics"

# Mkdup stats file names
alignment_metrics="${picard_alignment_folder}/${sample}_as_metrics.txt"

# Process sample (using default adapters list)
"${java6}" -Xmx20g -jar "${picard}" CollectAlignmentSummaryMetrics \
  INPUT="${mkdup_bam}" \
  OUTPUT="${alignment_metrics}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  VERBOSITY=ERROR \
  QUIET=true &

# .. in parallel with other stats started after this .. hence akward Xmx20
# use same genome as for BWA index in alignment ... 

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
  INPUT="${mkdup_bam}" \
  OUTPUT="${hs_metrics}" \
  PER_TARGET_COVERAGE="${hs_coverage}" \
  VERBOSITY=ERROR \
  QUIET=true &

# .. in parallel with other stats started after this .. hence akward Xmx20

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
  -bam "${mkdup_bam}" \
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
"${samstat}" "${mkdup_bam}" &> "${samstat_log}"

# Move results to the designated folder
samstat_source="${mkdup_bam}.samstat.html"
samstat_target=$(basename "${mkdup_bam}.samstat.html")
samstat_target="${samstat_results_folder}/${samstat_target}"
mv -f "${samstat_source}" "${samstat_target}"

# Progress report
echo "Completed samstat: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------------------ Remove mkdupped bams -------------------- #

rm -f "${mkdup_bam}"
rm -f "${mkdup_bam}.md5"
rm -f "${mkdup_bam%.bam}.bai"

# Progress report
echo "Removed mkdupped bams"
echo ""

# Note:
# Pipeline performs duplication analysis for QC. However, if 
# several lanes will be run for the same library, the marking
# and removing PCR duplicates should be done AFTER merging files 
# from different lanes.  It is possible, however, to consider
# re-makdupping of merged mkdupped files. 

# -- Add sample to the lane's sample list (for merging step) -- #

bam_samples_file="${lane_folder}/samples.txt"

bam_file_name=$(basename "${rg_bam}")
bam_file_name="f03_bam/${bam_file_name}"
echo -e "${sample}\t${bam_file_name}" >> "${bam_samples_file}"

# Progress report
echo "Added sample to the lane's bam list (may be used in the merging step later)"
echo ""

# ------------------- Update pipeline log  ------------------- #

echo "Completed ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# ------- Plot summary QC reports for multiple samples ------- #

# Get source samples file name
fastq_samples_file="${source_fastq_folder}/samples.txt"

# Get list of fastq_samples
fastq_samples=$(awk 'NR>1 {print $1}' "${fastq_samples_file}")

# Check that file still exists and samples have been red 
# (many things may happen on a shared area on cluster...) 
if [ -z "${fastq_samples}" ]
then
  echo "Script terminated with error because samples"
  echo "could not be red from the following file:"
  echo "${source_fastq_folder}/samples.txt"
  exit 1
fi

# Set flag as if all samples were completed
all_completed="yes"

# For each sample
for sample in $fastq_samples
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
  
  # Report to pipeline
  echo "" >> "${pipeline_log}"
  echo "Completed all samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

  # Report to sample log
  echo "Completed all samples"
  echo "Submitting job to collect and plot summary metrics"

  # Reorder bam samples file according to the initial order of fastq samples
  bam_samples_temp=$(mktemp "${bam_samples_file}.tmp.XXXX")
  cp -f "${bam_samples_file}" "${bam_samples_temp}"
  
  header=$(head -n 1 "${bam_samples_temp}")
  echo "${header}" > "${bam_samples_file}"
  
  for sample in $fastq_samples
  do
    cur_line=$(awk -v smp="${sample}" '$1==smp {print}' "${bam_samples_temp}")
    echo "${cur_line}" >> "${bam_samples_file}"
  done
  
  rm -f "${bam_samples_temp}"
  
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
