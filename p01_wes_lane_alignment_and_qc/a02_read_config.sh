#!/bin/bash

# s02_read_config.sh
# Parse congig file for wes lane alignment pipeline
# Alexey Larionov, 11Feb2016

# Function for reading parameters
function get_parameter()
{
	local parameter="${1}"
  local line
	line=$(awk -v p="${parameter}" 'BEGIN { FS=":" } $1 == p {print $2}' "${job_file}") 
	echo ${line} # return value
}

# === Data location and analysis settings === # 

source_server=$(get_parameter "Source server") # e.g. admin@mgqnap.medschl.cam.ac.uk
source_folder=$(get_parameter "Source folder") # e.g. /share/mtgroup/SLX-9871_150601_D00491_0172_C71EDANXX_s8

results_server=$(get_parameter "Results server") # e.g. admin@mgqnap.medschl.cam.ac.uk
results_folder=$(get_parameter "Results folder") # e.g. /share/alexey

project=$(get_parameter "project") # e.g. project1
library=$(get_parameter "library") # e.g. library1
lane=$(get_parameter "lane") # e.g. lane1

use_contents_csv=$(get_parameter "Use CI's contents.csv file and make folder with renamed fastq files") # e.g. no

remove_project_folder=$(get_parameter "Remove project and library folders from HPC scratch after run") # e.g. no

# ============= mgqnap settings ============= #

mgqnap_user=$(get_parameter "mgqnap_user") # e.g. alexey
mgqnap_group=$(get_parameter "mgqnap_group") # e.g. mtgroup

# =============== HPC settings ============== #

working_folder=$(get_parameter "working_folder") # e.g. /scratch/medgen/users/alexey
project_folder="${working_folder}/${project}"
lane_folder="${working_folder}/${project}/${library}/${lane}"

account_copy_in=$(get_parameter "Account to use for copying source files into HPC") # e.g. TISCHKOWITZ-SL2
time_copy_in=$(get_parameter "Max time requested for copying source files (hrs.min.sec)") # e.g. 00.30.00
time_copy_in=${time_copy_in//./:} # substitute dots to colons 

account_alignment_qc=$(get_parameter "Account to use for alignment and QC") # e.g. TISCHKOWITZ-SL2
time_alignment_qc=$(get_parameter "Max time requested for alignment and QC (hrs.min.sec)") # e.g. 02.00.00
time_alignment_qc=${time_alignment_qc//./:} # substitute dots to colons
 
account_move_out=$(get_parameter "Account to use for moving results out of HPC") # e.g. TISCHKOWITZ-SL2
time_move_out=$(get_parameter "Max time requested for moving results out of HPC (hrs.min.sec)") # e.g. 00.30.00
time_move_out=${time_move_out//./:} # substitute dots to colons

# ============ Standard settings ============ #

scripts_folder=$(get_parameter "scripts_folder") # e.g. /scratch/medgen/scripts/wes_lane_alignment

# ----------- Tools ---------- #

tools_folder=$(get_parameter "tools_folder") # e.g. /scratch/medgen/tools

java6=$(get_parameter "java6") # e.g. java/jre1.6.0_45/bin/java
java6="${tools_folder}/${java6}"

java7=$(get_parameter "java7") # e.g. java/jre1.7.0_76/bin/java
java7="${tools_folder}/${java7}"

java8=$(get_parameter "java8") # e.g. java/jre1.8.0_40/bin/java
java8="${tools_folder}/${java8}"

fastqc=$(get_parameter "fastqc") # e.g. fastqc/fastqc_v0.11.3/fastqc
fastqc="${tools_folder}/${fastqc}"

cutadapt=$(get_parameter "cutadapt") # e.g. python/python_2.7.10/bin/cutadapt"
cutadapt="${tools_folder}/${cutadapt}"

cutadapt_min_len=$(get_parameter "cutadapt_min_len") # e.g. 50
cutadapt_trim_qual=$(get_parameter "cutadapt_trim_qual") # e.g. 20
cutadapt_adapter_1=$(get_parameter "cutadapt_adapter_1") # e.g. CTGTCTCTTATACACATCTCCGAGCCCACGAGACNNNNNNNNATCTCGTATGCCGTCTTCTGCTTG
cutadapt_adapter_2=$(get_parameter "cutadapt_adapter_2") # e.g. CTGTCTCTTATACACATCTGACGCTGCCGACGANNNNNNNNGTGTAGATCTCGGTGGTCGCCGTATCATT

bwa=$(get_parameter "bwa") # e.g. bwa/bwa-0.7.12/bwa
bwa="${tools_folder}/${bwa}"

bwa_index=$(get_parameter "bwa_index") # e.g. bwa/bwa-0.7.12/indices/b37/b37_bwtsw
bwa_index="${tools_folder}/${bwa_index}"

samtools=$(get_parameter "samtools") # e.g. samtools/samtools-1.2/bin/samtools
samtools="${tools_folder}/${samtools}"

samtools_folder=$(get_parameter "samtools_folder") # e.g. samtools/samtools-1.2/bin
samtools_folder="${tools_folder}/${samtools_folder}"
PATH="${samtools_folder}:${PATH}" # samstat needs samtools in the PATH

picard=$(get_parameter "picard") # e.g. picard/picard-tools-1.133/picard.jar
picard="${tools_folder}/${picard}"

r_folder=$(get_parameter "r_folder") # e.g. r/R-3.2.0/bin
r_folder="${tools_folder}/${r_folder}"
PATH="${r_folder}:${PATH}" # picard, GATK and Qualimap need R in the PATH

qualimap=$(get_parameter "qualimap") # e.g. qualimap/qualimap_v2.1.1/qualimap.modified
qualimap="${tools_folder}/${qualimap}"

gnuplot=$(get_parameter "gnuplot") # e.g. gnuplot/gnuplot-5.0.1/bin/gnuplot
gnuplot="${tools_folder}/${gnuplot}"

LiberationSansRegularTTF=$(get_parameter "LiberationSansRegularTTF") # e.g. fonts/liberation-fonts-ttf-2.00.1/LiberationSans-Regular.ttf
LiberationSansRegularTTF="${tools_folder}/${LiberationSansRegularTTF}"

samstat=$(get_parameter "samstat") # e.g. samstat/samstat-1.5.1/bin/samstat
samstat="${tools_folder}/${samstat}"

# ----------- Resources ---------- #

resources_folder=$(get_parameter "resources_folder") # e.g. /scratch/medgen/resources

ref_genome=$(get_parameter "ref_genome") # e.g. gatk_bundle/b37/decompressed/human_g1k_v37.fasta
ref_genome="${resources_folder}/${ref_genome}"

hs_metrics_probes_name=$(get_parameter "hs_metrics_probes_name") # e.g. Nexera_Rapid_Capture_Exome

nextera_probes_intervals=$(get_parameter "nextera_probes_intervals") 
# e.g. illumina_nextera/nexterarapidcapture_exome_probes_v1.2.b37.intervals
nextera_probes_intervals="${resources_folder}/${nextera_probes_intervals}"

nextera_targets_intervals=$(get_parameter "nextera_targets_intervals") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.intervals
nextera_targets_intervals="${resources_folder}/${nextera_targets_intervals}"

nextera_targets_bed_3=$(get_parameter "nextera_targets_bed_3") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.bed
nextera_targets_bed_3="${resources_folder}/${nextera_targets_bed_3}"

nextera_targets_bed_6=$(get_parameter "nextera_targets_bed_6") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.6.bed
nextera_targets_bed_6="${resources_folder}/${nextera_targets_bed_6}"

# ----------- Working folders ---------- #

logs_folder=$(get_parameter "logs_folder") # e.g. f00_logs
logs_folder="${lane_folder}/${logs_folder}"

source_fastq_folder=$(get_parameter "source_fastq_folder") # e.g. f01_source_fastq
source_fastq_folder="${lane_folder}/${source_fastq_folder}"

renamed_fastq_folder=$(get_parameter "renamed_fastq_folder") # e.g. f02_renamed_fastq
renamed_fastq_folder="${lane_folder}/${renamed_fastq_folder}"

fastqc_raw_folder=$(get_parameter "fastqc_raw_folder") # e.g. f02_fastq_stats/f01_fastqc_raw
fastqc_raw_folder="${lane_folder}/${fastqc_raw_folder}"

trimmed_fastq_folder=$(get_parameter "trimmed_fastq_folder") # e.g. f02_fastq_stats/f02_adaptors_trimming
trimmed_fastq_folder="${lane_folder}/${trimmed_fastq_folder}"

fastqc_trimmed_folder=$(get_parameter "fastqc_trimmed_folder") # e.g. f02_fastq_stats/f03_fastqc_trimmed
fastqc_trimmed_folder="${lane_folder}/${fastqc_trimmed_folder}"

bam_folder=$(get_parameter "bam_folder") # e.g. f03_bam
bam_folder="${lane_folder}/${bam_folder}"

flagstat_folder=$(get_parameter "flagstat_folder") # e.g. f04_bam_stats/f01_flagstat
flagstat_folder="${lane_folder}/${flagstat_folder}"

picard_mkdup_folder=$(get_parameter "picard_mkdup_folder") # e.g. f04_bam_stats/f02_picard/f01_mkdup_metrics
picard_mkdup_folder="${lane_folder}/${picard_mkdup_folder}"

picard_inserts_folder=$(get_parameter "picard_inserts_folder") # e.g. f04_bam_stats/f02_picard/f02_inserts_metrics
picard_inserts_folder="${lane_folder}/${picard_inserts_folder}"

picard_alignment_folder=$(get_parameter "picard_alignment_folder") # e.g. f04_bam_stats/f02_picard/f03_alignment_metrics
picard_alignment_folder="${lane_folder}/${picard_alignment_folder}"

picard_hybridisation_folder=$(get_parameter "picard_hybridisation_folder") # e.g. f04_bam_stats/f02_picard/f04_hybridisation_metrics
picard_hybridisation_folder="${lane_folder}/${picard_hybridisation_folder}"

picard_summary_folder=$(get_parameter "picard_summary_folder") # e.g. f04_bam_stats/f02_picard/f05_metrics_summaries
picard_summary_folder="${lane_folder}/${picard_summary_folder}"

qualimap_results_folder=$(get_parameter "qualimap_results_folder") # e.g. f04_bam_stats/f03_qualimap
qualimap_results_folder="${lane_folder}/${qualimap_results_folder}"

samstat_results_folder=$(get_parameter "samstat_results_folder") # e.g. f04_bam_stats/f04_samstat
samstat_results_folder="${lane_folder}/${samstat_results_folder}"

# ----------- Additional parameters ---------- #

platform=$(get_parameter "platform") # e.g. illumina

