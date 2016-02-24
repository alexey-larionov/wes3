#!/bin/bash

# s01_export_txt.sh
# data export
# Alexey Larionov, 23Feb2016

# Notes:
# Export multi-allelic variants to a separate file
# -AMD allow missed data
# -raw keep filtered (the filtered variants are removed later in R scripts)

# Not used options:
# -M 1000 output the first 1000 variants only (may be used for debugging)
# -SMA split multi-allelic variants

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_export_txt: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a02_read_config.sh"
echo "Read settings"
echo ""

# Make output folders
mkdir -p "${biallelic_folder}"
mkdir -p "${multiallelic_folder}"

# Go to working folder
init_dir="$(pwd)"
cd "${export_folder}"

# --- Copy source vcf to cluster --- #

# Progress report
echo "Started copying source data"

# Source files and folders (on source server)
source_vcf_folder="${dataset}_vep"
source_vcf="${dataset}_vep.vcf"

# Copy source vcf
rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${source_vcf_folder}/${source_vcf}" "${tmp_folder}/"
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

source_vcf="${tmp_folder}/${source_vcf}"

# Progress report
echo "Completed copying source data: $(date +%d%b%Y_%H:%M:%S)"
echo ""

#############################################################
#                                                           #
#                      Export BiAllelic                     #
#                                                           #
#############################################################

# --- Make separate vcf file with biallelic variants --- #

# Progress report
echo "Started making vcf with biallelic variants"

# File names
biallelic_vcf="${biallelic_folder}/${dataset}_biallelic_vep.vcf"
biallelic_vcf_log="${logs_folder}/${dataset}_biallelic_vcf.log"

# Select variants
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${source_vcf}" \
  -o "${biallelic_vcf}" \
  -restrictAllelesTo BIALLELIC \
  -nt 14 &>  "${biallelic_vcf_log}"

# Progress report
echo "Completed making vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export raw VCF-VEP biallelic table --- #

# Progress report
echo "Started exporting biallelic VCF-VEP table"

# File names
VV_ba_raw_txt="${tmp_folder}/${dataset}_VV_ba_raw.txt"
VV_ba_raw_log="${logs_folder}/${dataset}_VV_ba_raw.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${biallelic_vcf}" \
  -F RawVarID -F MultiAllelic -F NDA -F TYPE -F CHROM -F POS -F REF -F ALT -F QUAL -F DP -F VQSLOD -F FILTER -F AC -F AF -F AN \
  -F NEGATIVE_TRAIN_SITE -F POSITIVE_TRAIN_SITE \
  -F ALT_frequency_in_1k_90 -F ALT_frequency_in_1k_95 -F ALT_frequency_in_1k_99 -F ALT_frequency_in_1k_100 \
  -F ANN \
  -o "${VV_ba_raw_txt}" \
  -AMD -raw &>  "${VV_ba_raw_log}"  

# Progress report
echo "Completed exporting VCF-VEP table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Update VCF-VEP biallelic table --- #

# Progress report
echo "Started updating biallelic VCF-VEP table"

# File names
VV_ba_txt="${biallelic_folder}/${dataset}_VV_biallelic.txt"

# Update header line
sed -i "1 s/""ANN""$/"${vep_fields}"/" "${VV_ba_raw_txt}"
echo "Updated header"

# Update table
awk 'BEGIN {OFS="\t"}{gsub(/\|/,"\t",$22); print}' "${VV_ba_raw_txt}" > "${VV_ba_txt}"
echo "Updated VEP fields"

# Progress report
echo "Completed updating biallelic VCF-VEP table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export biallelic GT table --- #

# Progress report
echo "Started exporting biallelic GT table"

# File names
GT_ba_txt="${biallelic_folder}/${dataset}_GT_biallelic.txt"
GT_ba_log="${logs_folder}/${dataset}_GT_ba.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${biallelic_vcf}" \
  -F RawVarID -GF GT \
  -o "${GT_ba_txt}" \
  -AMD -raw &>  "${GT_ba_log}"  

# Progress report
echo "Completed exporting biallelic GT table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Translate biallelic GTs from alphabetic to numeric notations --- #

# Progress report
echo "Translate biallelic GTs from alphabetic to numeric notations"

# File names
translate_html="${logs_folder}/${dataset}_biallelic_gt2num.html"
translate_log="${logs_folder}/${dataset}_biallelic_gt2num.log"

# Paremeters for R script
data_type="biallelic"
VV="biallelic/"$(basename "${VV_ba_txt}") 
GT="biallelic/"$(basename "${GT_ba_txt}")

# Prepare R script for translation with html report
translate_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r01_gt_html.Rmd', params=list(dataset='"${dataset}"', working_folder='"${export_folder}"', data_type='"${data_type}"', vv_file='"${VV}"', gt_file='"${GT}"', file_out_base='"${GT%.txt}"'), output_file='"${translate_html}"')"

# Execute R script for html report
echo "-------------- Preparing html report -------------- " > "${translate_log}"
echo "" >> "${translate_log}"
"${r_bin_folder}/R" -e "${translate_script}" &>> "${translate_log}"
echo "" >> "${translate_log}"

# Names of created files 
#(hardwired within r01_recode_gt.Rmd script used for translation above)
GT_ba_add="${GT%.txt}_add.txt"
GT_ba_dom="${GT%.txt}_dom.txt"
GT_ba_rec="${GT%.txt}_rec.txt"

# Progress report
echo "Completed translating GTs to numeric notations: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export biallelic DP table --- #

# Progress report
echo "Started exporting biallelic DP table"

# File names
DP_ba_txt="${biallelic_folder}/${dataset}_DP_biallelic.txt"
DP_ba_log="${logs_folder}/${dataset}_DP_ba.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${biallelic_vcf}" \
  -F RawVarID -GF DP \
  -o "${DP_ba_txt}" \
  -AMD -raw &>  "${DP_ba_log}"  

# Progress report
echo "Completed exporting biallelic DP table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export biallelic AD table --- #

# Progress report
echo "Started exporting biallelic AD table"

# File names
AD_ba_txt="${biallelic_folder}/${dataset}_AD_biallelic.txt"
AD_ba_log="${logs_folder}/${dataset}_AD_ba.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${biallelic_vcf}" \
  -F RawVarID -GF AD \
  -o "${AD_ba_txt}" \
  -AMD -raw &>  "${AD_ba_log}"  

# Progress report
echo "Completed exporting biallelic AD table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export biallelic GQ table --- #

# Progress report
echo "Started exporting biallelic GQ table"

# File names
GQ_ba_txt="${biallelic_folder}/${dataset}_GQ_biallelic.txt"
GQ_ba_log="${logs_folder}/${dataset}_GQ_ba.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${biallelic_vcf}" \
  -F RawVarID -GF GQ \
  -o "${GQ_ba_txt}" \
  -AMD -raw &>  "${GQ_ba_log}"  

# Progress report
echo "Completed exporting biallelic GQ table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export biallelic PL table --- #

# Progress report
echo "Started exporting biallelic PL table"

# File names
PL_ba_txt="${biallelic_folder}/${dataset}_PL_biallelic.txt"
PL_ba_log="${logs_folder}/${dataset}_PL_ba.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${biallelic_vcf}" \
  -F RawVarID -GF PL \
  -o "${PL_ba_txt}" \
  -AMD -raw &>  "${PL_ba_log}"  

# Progress report
echo "Completed exporting biallelic PL table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Check biallelic tables --- #

# Progress report
echo "Preparing report to check exported biallelic tables"

# File names
check_html="${biallelic_folder}/${dataset}_biallelic.html"
check_pdf="${biallelic_folder}/${dataset}_biallelic.pdf"
check_log="${logs_folder}/${dataset}_check_biallelic.log"

# Paremeters for Rmarkdown scripts
data_type="biallelic"
VV="biallelic/"$(basename "${VV_ba_txt}") 
GT="biallelic/"$(basename "${GT_ba_txt}")
GT_add="biallelic/"$(basename "${GT_ba_add}")
GT_dom="biallelic/"$(basename "${GT_ba_dom}")
GT_rec="biallelic/"$(basename "${GT_ba_rec}")
DP="biallelic/"$(basename "${DP_ba_txt}")
AD="biallelic/"$(basename "${AD_ba_txt}")
GQ="biallelic/"$(basename "${GQ_ba_txt}")
PL="biallelic/"$(basename "${PL_ba_txt}")

# Prepare script for html report
html_script="library('rmarkdown', lib='"${r_lib_folder}/"'); render('"${scripts_folder}"/r02_ba_html.Rmd', params=list(dataset='"${dataset}"', working_folder='"${export_folder}"', data_type='"${data_type}"', vv_file='"${VV}"', gt_file='"${GT}"', gt_add_file='"${GT_add}"', gt_dom_file='"${GT_dom}"', gt_rec_file='"${GT_rec}"', dp_file='"${DP}"', ad_file='"${AD}"', gq_file='"${GQ}"', pl_file='"${PL}"'), output_file='"${check_html}"')"

# Execute R script for html report
echo "-------------- Preparing html report -------------- " > "${check_log}"
echo "" >> "${check_log}"
"${r_bin_folder}/R" -e "${html_script}" &>> "${check_log}"
echo "" >> "${check_log}"

# Prepare R script for pdf report
latex_dataset_name="${dataset//_/-}" # Underscores have special meaning in LaTex, 

pdf_script="library('rmarkdown', lib='"${r_lib_folder}/"'); render('"${scripts_folder}"/r03_ba_pdf.Rmd', params=list(dataset='"${latex_dataset_name}"', working_folder='"${export_folder}"', data_type='"${data_type}"', vv_file='"${VV}"', gt_file='"${GT}"', gt_add_file='"${GT_add}"', gt_dom_file='"${GT_dom}"', gt_rec_file='"${GT_rec}"', dp_file='"${DP}"', ad_file='"${AD}"', gq_file='"${GQ}"', pl_file='"${PL}"'), output_file='"${check_pdf}"')"

# Execute R script for pdf report
echo "-------------- Preparing pdf report -------------- " >> "${check_log}"
echo "" >> "${check_log}"
"${r_bin_folder}/R" -e "${pdf_script}" &>> "${check_log}"
echo "" >> "${check_log}"

# Progress report
echo "Completed report for biallelic tables: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make md5 sum for all biallelic tables --- #

# Progress report
echo "Started making md5 sums for biallelic tables"

# File names
biallelic_md5="${biallelic_folder}/${dataset}_biallelic_txt.md5"

cd "${biallelic_folder}"
 
md5sum \
  $(basename "${biallelic_vcf}") \
  $(basename "${biallelic_vcf}")".idx" \
  $(basename "${VV_ba_txt}") \
  $(basename "${GT_ba_txt}") \
  $(basename "${GT_ba_add}") \
  $(basename "${GT_ba_dom}") \
  $(basename "${GT_ba_rec}") \
  $(basename "${DP_ba_txt}") \
  $(basename "${AD_ba_txt}") \
  $(basename "${GQ_ba_txt}") \
  $(basename "${PL_ba_txt}") \
  $(basename "${check_html}") \
  > "${biallelic_md5}"
  
cd "${export_folder}"

# Progress report
echo "Completed making md5 sums: $(date +%d%b%Y_%H:%M:%S)"
echo ""

#############################################################
#                                                           #
#                    Export MultiAllelic                    #
#                                                           #
#############################################################

# --- Make separate vcf file with multiallelic variants --- #

# Progress report
echo "Started making vcf with biallelic variants"

# File names
multiallelic_vcf="${multiallelic_folder}/${dataset}_multiallelic_vep.vcf"
multiallelic_vcf_log="${logs_folder}/${dataset}_multiallelic_vcf.log"

# Select variants
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${source_vcf}" \
  -o "${multiallelic_vcf}" \
  -restrictAllelesTo MULTIALLELIC \
  -nt 14 &>  "${multiallelic_vcf_log}"

# Progress report
echo "Completed making vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export VCF-VEP multiallelic table --- #

# Progress report
echo "Started exporting inline multiallelic VCF-VEP table"

# File names
VV_ma_txt="${multiallelic_folder}/${dataset}_VV_multiallelic.txt"
VV_ma_log="${logs_folder}/${dataset}_VV_multiallelic.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${multiallelic_vcf}" \
  -F RawVarID -F MultiAllelic -F NDA -F TYPE -F CHROM -F POS -F REF -F ALT -F QUAL -F DP -F VQSLOD -F FILTER -F AC -F AF -F AN -F NEGATIVE_TRAIN_SITE -F POSITIVE_TRAIN_SITE -F ANN \
  -o "${VV_ma_txt}" \
  -AMD -raw &>  "${VV_ma_log}"  

# Progress report
echo "Completed exporting VCF-VEP table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export multiallelic GT table --- #

# Progress report
echo "Started exporting multiallelic GT table"

# File names
GT_ma_txt="${multiallelic_folder}/${dataset}_GT_multiallelic.txt"
GT_ma_log="${logs_folder}/${dataset}_GT_ma.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${multiallelic_vcf}" \
  -F RawVarID -GF GT \
  -o "${GT_ma_txt}" \
  -AMD -raw &>  "${GT_ma_log}"  

# Progress report
echo "Completed exporting multiallelic GT table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export multiallelic DP table --- #

# Progress report
echo "Started exporting multiallelic DP table"

# File names
DP_ma_txt="${multiallelic_folder}/${dataset}_DP_multiallelic.txt"
DP_ma_log="${logs_folder}/${dataset}_DP_ma.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${multiallelic_vcf}" \
  -F RawVarID -GF DP \
  -o "${DP_ma_txt}" \
  -AMD -raw &>  "${DP_ma_log}"  

# Progress report
echo "Completed exporting multiallelic DP table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export multiallelic AD table --- #

# Progress report
echo "Started exporting multiallelic AD table"

# File names
AD_ma_txt="${multiallelic_folder}/${dataset}_AD_multiallelic.txt"
AD_ma_log="${logs_folder}/${dataset}_AD_ma.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${multiallelic_vcf}" \
  -F RawVarID -GF AD \
  -o "${AD_ma_txt}" \
  -AMD -raw &>  "${AD_ma_log}"  

# Progress report
echo "Completed exporting multiallelic AD table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export multiallelic GQ table --- #

# Progress report
echo "Started exporting multiallelic GQ table"

# File names
GQ_ma_txt="${multiallelic_folder}/${dataset}_GQ_multiallelic.txt"
GQ_ma_log="${logs_folder}/${dataset}_GQ_ma.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${multiallelic_vcf}" \
  -F RawVarID -GF GQ \
  -o "${GQ_ma_txt}" \
  -AMD -raw &>  "${GQ_ma_log}"  

# Progress report
echo "Completed exporting multiallelic GQ table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Export multiallelic PL table --- #

# Progress report
echo "Started exporting multiallelic PL table"

# File names
PL_ma_txt="${multiallelic_folder}/${dataset}_PL_multiallelic.txt"
PL_ma_log="${logs_folder}/${dataset}_PL_ma.log"

# Export table
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${multiallelic_vcf}" \
  -F RawVarID -GF PL \
  -o "${PL_ma_txt}" \
  -AMD -raw &>  "${PL_ma_log}"  

# Progress report
echo "Completed exporting multiallelic PL table: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Check multiallelic tables --- #

# Progress report
echo "Preparing report to check multiallelic tables"

# File names
check_html="${multiallelic_folder}/${dataset}_multiallelic.html"
check_pdf="${multiallelic_folder}/${dataset}_multiallelic.pdf"
check_log="${logs_folder}/${dataset}_check_multiallelic.log"

# Paremeters for R script
data_type="multiallelic"
VV="multiallelic/"$(basename "${VV_ma_txt}") 
GT="multiallelic/"$(basename "${GT_ma_txt}")
DP="multiallelic/"$(basename "${DP_ma_txt}")
AD="multiallelic/"$(basename "${AD_ma_txt}")
GQ="multiallelic/"$(basename "${GQ_ma_txt}")
PL="multiallelic/"$(basename "${PL_ma_txt}")

# Prepare R script for html report
html_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r04_ma_html.Rmd', params=list(dataset='"${dataset}"', working_folder='"${export_folder}"', data_type='"${data_type}"', vv_file='"${VV}"', gt_file='"${GT}"', dp_file='"${DP}"', ad_file='"${AD}"', gq_file='"${GQ}"', pl_file='"${PL}"'), output_file='"${check_html}"')"

# Execute R script for html report
echo "-------------- Preparing html report -------------- " > "${check_log}"
echo "" >> "${check_log}"
"${r_bin_folder}/R" -e "${html_script}" &>> "${check_log}"
echo "" >> "${check_log}"

# Prepare R script for pdf report
latex_dataset_name="${dataset//_/-}" # Underscores have special meaning in LaTex, 

pdf_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r05_ma_pdf.Rmd', params=list(dataset='"${latex_dataset_name}"', working_folder='"${export_folder}"', data_type='"${data_type}"', vv_file='"${VV}"', gt_file='"${GT}"', dp_file='"${DP}"', ad_file='"${AD}"', gq_file='"${GQ}"', pl_file='"${PL}"'), output_file='"${check_pdf}"')"

# Execute R script for pdf report
echo "-------------- Preparing pdf report -------------- " >> "${check_log}"
echo "" >> "${check_log}"
"${r_bin_folder}/R" -e "${pdf_script}" &>> "${check_log}"
echo "" >> "${check_log}"

# Progress report
echo "Completed report for multiallelic tables: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make md5 sum for all multiallelic tables --- #

# Progress report
echo "Started making md5 sums for multiallelic tables"

# File names
multiallelic_md5="${multiallelic_folder}/${dataset}_multiallelic_txt.md5"

cd "${multiallelic_folder}"

md5sum \
  $(basename "${multiallelic_vcf}") \
  $(basename "${multiallelic_vcf}")".idx" \
  $(basename "${VV_ma_txt}") \
  $(basename "${GT_ma_txt}") \
  $(basename "${DP_ma_txt}") \
  $(basename "${AD_ma_txt}") \
  $(basename "${GQ_ma_txt}") \
  $(basename "${PL_ma_txt}") \
  $(basename "${check_html}") \
  > "${multiallelic_md5}"

cd "${export_folder}"

# Progress report
echo "Completed making md5 sums: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Copy results to NAS --- #

# Progress report
echo "Started copying results to NAS"

# Remove temporary data
rm -fr "${tmp_folder}"

# Copy files to NAS
rsync -thrqe "ssh -x" "${export_folder}" "${data_server}:${project_location}/${project}/" 
exit_code="${?}"

# Stop if copying failed
if [ "${exit_code}" != "0" ]  
then
  echo ""
  echo "Failed copying results to NAS"
  echo "Script terminated"
  echo ""
  exit
fi

# Change ownership on nas (to allow user manipulating files later w/o administrative privileges)
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}/${dataset}_txt"
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}" # just in case...
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}" # just in case...

# Progress report to log on nas
log_on_nas="${project_location}/${project}/${dataset}_txt/logs/${dataset}_export_txt.log"
timestamp="$(date +%d%b%Y_%H:%M:%S)"
ssh -x "${data_server}" "echo \"Completed copying results to NAS: ${timestamp}\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Remove results from cluster
#rm -fr "${logs_folder}"
rm -fr "${multiallelic_folder}"
rm -fr "${biallelic_folder}"

echo $(ssh -x "${data_server}" "echo \"Removed results from cluster\" >> ${log_on_nas}")
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Return to the initial folder
cd "${init_dir}"

# Remove project folder from cluster
if [ "${remove_project_folder}" == "yes" ] || [ "${remove_project_folder}" == "Yes" ] 
then 
  rm -fr "${project_folder}"
  ssh -x "${data_server}" "echo \"Removed project folder from cluster\" >> ${log_on_nas}"
else
  ssh -x "${data_server}" "echo \"Project folder is not removed from cluster\" >> ${log_on_nas}"
fi 
