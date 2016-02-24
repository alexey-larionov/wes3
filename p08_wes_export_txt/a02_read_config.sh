#!/bin/bash

# s02_read_config.sh
# Parse config file for data export
# Alexey Larionov, 12Feb2016

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
dataset=$(get_parameter "vep annotated dataset") # e.g. variantset1_filter1

remove_project_folder=$(get_parameter "Remove project folder from HPC scratch after run") # e.g. no

# ============= mgqnap settings ============= #

mgqnap_user=$(get_parameter "mgqnap_user") # e.g. alexey
mgqnap_group=$(get_parameter "mgqnap_group") # e.g. mtgroup

# =============== HPC settings ============== #

working_folder=$(get_parameter "working_folder") # e.g. /scratch/medgen/users/alexey

account_to_use=$(get_parameter "Account to use on HPC") # e.g. TISCHKOWITZ-SL2
time_to_request=$(get_parameter "Max time to request (hrs.min.sec)") # e.g. 02.00.00
time_to_request=${time_to_request//./:} # substitute dots to colons 

# ============ Standard settings ============ #

scripts_folder=$(get_parameter "scripts_folder") # e.g. /scratch/medgen/scripts/p06_wes_filter

# ----------- Tools ---------- #

tools_folder=$(get_parameter "tools_folder") # e.g. /scratch/medgen/tools

java7=$(get_parameter "java7") # e.g. java/jre1.7.0_76/bin/java
java7="${tools_folder}/${java7}"

gatk=$(get_parameter "gatk") # e.g. gatk/gatk-3.4-46/GenomeAnalysisTK.jar
gatk="${tools_folder}/${gatk}"

r_bin_folder=$(get_parameter "r_bin_folder") # e.g. r/R-3.2.2/bin/
r_bin_folder="${tools_folder}/${r_bin_folder}"

r_lib_folder=$(get_parameter "r_lib_folder") # e.g. r/R-3.2.2/lib64/R/library
r_lib_folder="${tools_folder}/${r_lib_folder}"

# ----------- Resources ---------- #

resources_folder=$(get_parameter "resources_folder") # e.g. /scratch/medgen/resources

decompressed_bundle_folder=$(get_parameter "decompressed_bundle_folder") # e.g. gatk_bundle/b37/decompressed
decompressed_bundle_folder="${resources_folder}/${decompressed_bundle_folder}"

ref_genome=$(get_parameter "ref_genome") # e.g. human_g1k_v37.fasta
ref_genome="${decompressed_bundle_folder}/${ref_genome}"

nextera_folder=$(get_parameter "nextera_folder") # e.g. illumina_nextera
nextera_folder="${resources_folder}/${nextera_folder}"

nextera_targets_intervals=$(get_parameter "nextera_targets_intervals") # e.g. nexterarapidcapture_exome_targetedregions_v1.2.b37.intervals
nextera_targets_intervals="${nextera_folder}/${nextera_targets_intervals}"

# ----------- Working sub-folders ---------- #

project_folder="${working_folder}/${project}"

export_folder="${dataset}_txt"
export_folder="${project_folder}/${export_folder}"

biallelic_folder="${export_folder}/biallelic"
multiallelic_folder="${export_folder}/multiallelic"

tmp_folder="${export_folder}/tmp"
logs_folder="${export_folder}/logs"

# ----------- Additional parameters ---------- #

vep_fields=$(get_parameter "VEP fields") # e.g. SYMBOL|Allele|...|STRAND|SYMBOL_SOURCE