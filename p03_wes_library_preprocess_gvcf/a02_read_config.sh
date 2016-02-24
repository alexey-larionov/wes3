#!/bin/bash

# s02_read_config.sh
# Parse congig file for wes library preprocess and gvcf pipeline
# Alexey Larionov, 17Jan2016

# Function for reading parameters
function get_parameter()
{
	local parameter="${1}"
  local line
	line=$(awk -v p="${parameter}" 'BEGIN { FS=":" } $1 == p {print $2}' "${job_file}") 
	echo ${line} # return value
}

# === Data location and analysis settings === # 

data_server=$(get_parameter "Data server") # e.g. admin@mgqnap.medschl.cam.ac.uk
project_location=$(get_parameter "Project location") # e.g. /share/alexey

project=$(get_parameter "project") # e.g. project1
library=$(get_parameter "library") # e.g. library1

remove_project_folder=$(get_parameter "Remove project folder from HPC scratch after run") # e.g. no

# ============= mgqnap settings ============= #

mgqnap_user=$(get_parameter "mgqnap_user") # e.g. alexey
mgqnap_group=$(get_parameter "mgqnap_group") # e.g. mtgroup

# =============== HPC settings ============== #

working_folder=$(get_parameter "working_folder") # e.g. /scratch/medgen/users/alexey

account_copy_in=$(get_parameter "Account to use for copying source files into HPC") # e.g. TISCHKOWITZ-SL2
time_copy_in=$(get_parameter "Max time requested for copying source files (hrs.min.sec)") # e.g. 02.00.00
time_copy_in=${time_copy_in//./:} # substitute dots to colons 

account_process_gvcf=$(get_parameter "Account to use for bams preprocessing and making gvcfs") # e.g. TISCHKOWITZ-SL2
time_process_gvcf=$(get_parameter "Max time requested for bams preprocessing and making gvcf (hrs.min.sec)") # e.g. 05.00.00
time_process_gvcf=${time_process_gvcf//./:} # substitute dots to colons
 
account_move_out=$(get_parameter "Account to use for moving results out of HPC") # e.g. TISCHKOWITZ-SL2
time_move_out=$(get_parameter "Max time requested for moving results out of HPC (hrs.min.sec)") # e.g. 02.00.00
time_move_out=${time_move_out//./:} # substitute dots to colons

# ============ Standard settings ============ #

scripts_folder=$(get_parameter "scripts_folder") # e.g. /scratch/medgen/scripts/p03_wes_library_preprocess_gvcf

# ----------- Tools ---------- #

tools_folder=$(get_parameter "tools_folder") # e.g. /scratch/medgen/tools

java6=$(get_parameter "java6") # e.g. java/jre1.6.0_45/bin/java
java6="${tools_folder}/${java6}"

java7=$(get_parameter "java7") # e.g. java/jre1.7.0_76/bin/java
java7="${tools_folder}/${java7}"

picard=$(get_parameter "picard") # e.g. picard/picard-tools-1.133/picard.jar
picard="${tools_folder}/${picard}"

gatk=$(get_parameter "gatk") # e.g. gatk/gatk-3.4-46/GenomeAnalysisTK.jar
gatk="${tools_folder}/${gatk}"

r_folder=$(get_parameter "r_folder") # e.g. r/R-3.2.0/bin
r_folder="${tools_folder}/${r_folder}"
PATH="${r_folder}:${PATH}" # Some GATK tools may need R in the PATH

# ----------- Resources ---------- #

resources_folder=$(get_parameter "resources_folder") # e.g. /scratch/medgen/resources

decompressed_bundle_folder=$(get_parameter "decompressed_bundle_folder") # e.g. gatk_bundle/b37/decompressed
decompressed_bundle_folder="${resources_folder}/${decompressed_bundle_folder}"

ref_genome=$(get_parameter "ref_genome") # e.g. human_g1k_v37.fasta
ref_genome="${decompressed_bundle_folder}/${ref_genome}"

dbsnp=$(get_parameter "dbsnp") # e.g. dbsnp_138.b37.vcf
dbsnp="${decompressed_bundle_folder}/${dbsnp}"

dbsnp129=$(get_parameter "dbsnp129") # e.g. dbsnp_138.b37.excluding_sites_after_129.vcf
dbsnp129="${decompressed_bundle_folder}/${dbsnp129}"

hapmap=$(get_parameter "hapmap") # e.g. hapmap_3.3.b37.vcf
hapmap="${decompressed_bundle_folder}/${hapmap}"

omni=$(get_parameter "omni") # e.g. 1000G_omni2.5.b37.vcf
omni="${decompressed_bundle_folder}/${omni}"

phase1_1k_hc=$(get_parameter "phase1_1k_hc") # e.g. 1000G_phase1.snps.high_confidence.b37.vcf
phase1_1k_hc="${decompressed_bundle_folder}/${phase1_1k_hc}"

indels_1k=$(get_parameter "indels_1k") # e.g. 1000G_phase1.indels.b37.vcf
indels_1k="${decompressed_bundle_folder}/${indels_1k}"

indels_mills=$(get_parameter "indels_mills") # e.g. Mills_and_1000G_gold_standard.indels.b37.vcf
indels_mills="${decompressed_bundle_folder}/${indels_mills}"

nextera_folder=$(get_parameter "nextera_folder") # e.g. illumina_nextera
nextera_folder="${resources_folder}/${nextera_folder}"

nextera_targets_intervals=$(get_parameter "nextera_targets_intervals") # e.g. nexterarapidcapture_exome_targetedregions_v1.2.b37.intervals
nextera_targets_intervals="${nextera_folder}/${nextera_targets_intervals}"

# ----------- Working sub-folders ---------- #

project_folder="${working_folder}/${project}" # e.g. project1
library_folder="${project_folder}/${library}" # e.g. library1

merged_folder=$(get_parameter "merged_folder") # e.g. merged
merged_folder="${library_folder}/${merged_folder}"

dedup_bam_folder=$(get_parameter "dedup_bam_folder") # e.g. f01_bams
dedup_bam_folder="${merged_folder}/${dedup_bam_folder}"

processed_folder=$(get_parameter "processed_folder") # e.g. processed
processed_folder="${library_folder}/${processed_folder}"

logs_folder=$(get_parameter "logs_folder") # e.g. f00_logs
logs_folder="${processed_folder}/${logs_folder}"

proc_bam_folder=$(get_parameter "proc_bam_folder") # e.g. f01_bams
proc_bam_folder="${processed_folder}/${proc_bam_folder}"

idr_folder=$(get_parameter "idr_folder") # e.g. f02_idr
idr_folder="${processed_folder}/${idr_folder}"

bqr_folder=$(get_parameter "bqr_folder") # e.g. f03_bqr
bqr_folder="${processed_folder}/${bqr_folder}"

gvcf_folder=$(get_parameter "gvcf_folder") # e.g. gvcfs
gvcf_folder="${library_folder}/${gvcf_folder}"
