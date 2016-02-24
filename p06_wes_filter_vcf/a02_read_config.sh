#!/bin/bash

# s02_read_config.sh
# Parse config file for filtering step
# Alexey Larionov, 06Feb2016

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

project=$(get_parameter "project") # e.g. priject1
dataset_name=$(get_parameter "raw variantset name") # e.g. variantset1
filter_name=$(get_parameter "filter name") # e.g. filter1

MIN_SNP_DP=$(get_parameter "Min SNP DP") # e.g. 5000.0
MIN_SNP_QUAL=$(get_parameter "Min SNP QUAL") # e.g. 100.0
MIN_SNP_VQSLOD=$(get_parameter "Min SNP VQSLOD") # e.g. 10.0
SNP_TS=$(get_parameter "SNP TS") # e.g. 97.0

MIN_INDEL_DP=$(get_parameter "Min INDEL DP") # e.g. 5000.0
MIN_INDEL_QUAL=$(get_parameter "Min INDEL QUAL") # e.g. 100.0
MIN_INDEL_VQSLOD=$(get_parameter "Min INDEL VQSLOD") # e.g. 1.0
INDEL_TS=$(get_parameter "INDEL TS") # e.g. 95.0

MIN_MIXED_DP=$(get_parameter "Min INDEL DP") # e.g. 5000.0
MIN_MIXED_QUAL=$(get_parameter "Min INDEL QUAL") # e.g. 100.0
MIN_MIXED_VQSLOD=$(get_parameter "Min INDEL VQSLOD") # e.g. 1.0

padding=$(get_parameter "Padding") # e.g. 10

ExcludeMultiAllelic=$(get_parameter "Exclude MultiAllelic") # e.g. yes

fa_threshold=$(get_parameter "Apply 1k ALT frequency threshold") # e.g. no

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

bcftools=$(get_parameter "bcftools") # e.g. bcftools/bcftools-1.2/bin/bcftools
bcftools="${tools_folder}/${bcftools}"

plot_vcfstats=$(get_parameter "plot_vcfstats") # e.g. bcftools/bcftools-1.2/bin/plot-vcfstats
plot_vcfstats="${tools_folder}/${plot_vcfstats}"

python_bin=$(get_parameter "python_bin") # e.g. python/python_2.7.10/bin/ 
python_bin="${tools_folder}/${python_bin}" 
PATH="${python_bin}:${PATH}" # for updated version of matplotlib library for plot-vcfstats

r_folder=$(get_parameter "r_folder") # e.g. r/R-3.2.0/bin
r_folder="${tools_folder}/${r_folder}"
PATH="${r_folder}:${PATH}" # for GATK plots

r_bin_folder=$(get_parameter "r_bin_folder") # e.g. r/R-3.2.2/bin/
r_bin_folder="${tools_folder}/${r_bin_folder}" # for Rmarkdown reports

r_lib_folder=$(get_parameter "r_lib_folder") # e.g. r/R-3.2.2/lib64/R/library
r_lib_folder="${tools_folder}/${r_lib_folder}" # for Rmarkdown reports

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

nextera_targets_bed=$(get_parameter "nextera_targets_bed") # e.g. nexterarapidcapture_exome_targetedregions_v1.2.b37.bed
nextera_targets_bed="${nextera_folder}/${nextera_targets_bed}"

# ----------- Working sub-folders ---------- #

project_folder="${working_folder}/${project}" # e.g. CCLG

filtered_vcf_folder="${dataset_name}_${filter_name}_vcf" # e.g. set1_filter1_vcf
filtered_vcf_folder="${project_folder}/${filtered_vcf_folder}"

logs_folder=$(get_parameter "logs_folder") # e.g. logs
logs_folder="${filtered_vcf_folder}/${logs_folder}" 

histograms_folder=$(get_parameter "histograms_folder") # e.g. histograms
histograms_folder="${filtered_vcf_folder}/${histograms_folder}"

vcfstats_folder=$(get_parameter "vcfstats_folder") # e.g. vcfstats
vcfstats_folder="${filtered_vcf_folder}/${vcfstats_folder}"
all_vcfstats_folder="${vcfstats_folder}/all"
cln_vcfstats_folder="${vcfstats_folder}/cln"