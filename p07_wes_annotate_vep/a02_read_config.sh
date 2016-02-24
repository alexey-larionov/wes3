#!/bin/bash

# s02_read_config.sh
# Parse config file for annotating filtered vcfs with vep
# Alexey Larionov, 10Feb2016

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
dataset=$(get_parameter "dataset") # e.g. variantset1_filter1

remove_project_folder=$(get_parameter "Remove project folder from HPC scratch after run") # e.g. yes

# ============= mgqnap settings ============= #

mgqnap_user=$(get_parameter "mgqnap_user") # e.g. alexey
mgqnap_group=$(get_parameter "mgqnap_group") # e.g. mtgroup

# =============== HPC settings ============== #

working_folder=$(get_parameter "working_folder") # e.g. /scratch/medgen/users/alexey
account_to_use=$(get_parameter "Account to use on HPC") # e.g. TISCHKOWITZ-SL2
time_to_request=$(get_parameter "Max time to request (hrs.min.sec)") # e.g. 05.00.00
time_to_request=${time_to_request//./:} # substitute dots to colons 

# ============ Standard settings ============ #

scripts_folder=$(get_parameter "scripts_folder") # e.g. /scratch/medgen/scripts/p07_wes_annotate_with_vep

# ----------- Tools and resources ---------- #

tools_folder=$(get_parameter "tools_folder") # e.g. /scratch/medgen/tools

ensembl_version=$(get_parameter "ensembl_version") # e.g. v82
ensembl_api_folder=$(get_parameter "ensembl_api_folder") # e.g. ensembl
ensembl_api_folder="${tools_folder}/${ensembl_api_folder}/${ensembl_version}" # e.g. .../ensembl/v82

vep_script=$(get_parameter "vep_script") # e.g. ensembl-tools/scripts/variant_effect_predictor/variant_effect_predictor.pl
vep_script="${ensembl_api_folder}/${vep_script}"

vep_cache=$(get_parameter "vep_cache") # e.g. grch37_vep_cache
vep_cache="${ensembl_api_folder}/${vep_cache}"

# ----------- Working sub-folders ---------- #

project_folder="${working_folder}/${project}"
annotated_vcf_folder="${project_folder}/${dataset}_vep"
logs_folder="${annotated_vcf_folder}/logs"
tmp_folder="${annotated_vcf_folder}/tmp"

# ----------- Additional settings ---------- #

txt_vep_fields=$(get_parameter "txt_vep_fields") # e.g. "Uploaded_variation,Location,SYMBOL,Consequence,Existing_variation,GMAF ... CLIN_SIG,SIFT,PolyPhen,SYMBOL_SOURCE"
vcf_vep_fields=$(get_parameter "vcf_vep_fields") # e.g. "SYMBOL,Consequence,Existing_variation,GMAF ... CLIN_SIG,SIFT,PolyPhen,SYMBOL_SOURCE"