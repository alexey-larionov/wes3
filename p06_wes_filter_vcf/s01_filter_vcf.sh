#!/bin/bash

# s01_filter_vcf.sh
# Filtering vcf
# Alexey Larionov, 10Feb2016

# Selected Refs:
# http://gatkforums.broadinstitute.org/gatk/discussion/2806/howto-apply-hard-filters-to-a-call-set
# http://gatkforums.broadinstitute.org/gatk/discussion/53/combining-variants-from-different-files-into-one

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_filter_vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a02_read_config.sh"
echo "Read settings"
echo ""

# Go to working folder
init_dir="$(pwd)"
cd "${filtered_vcf_folder}"

# --- Copy source gvcfs to cluster --- #

# Progress report
echo "Started copying source data"

# Source files and folders (on source server)
source_vcf_folder="${dataset_name}_raw_vcf"
source_vcf="${dataset_name}_raw.vcf"

# Intermediate files and folders on HPC
tmp_folder="${filtered_vcf_folder}/tmp"
mkdir -p "${tmp_folder}"
mkdir -p "${histograms_folder}"
mkdir -p "${all_vcfstats_folder}"
mkdir -p "${cln_vcfstats_folder}"

# Copy data
rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${source_vcf_folder}/${source_vcf}" "${tmp_folder}/"
exit_code_1="${?}"

rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/${source_vcf_folder}/${source_vcf}.idx" "${tmp_folder}/"
exit_code_2="${?}"

# Stop if copying failed
if [ "${exit_code_1}" != "0" ] || [ "${exit_code_2}" != "0" ]  
then
  echo ""
  echo "Failed getting source data from NAS"
  echo "Script terminated"
  echo ""
  exit
fi

# Progress report
echo "Completed copying source data: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Select SNPs --- #

# Progress report
echo "Started selecting SNPs"

# File names
raw_input_vcf="${tmp_folder}/${dataset_name}_raw.vcf"
raw_snp_vcf="${tmp_folder}/${dataset_name}_snp_raw.vcf"
select_snp_log="${logs_folder}/${dataset_name}_snp_select.log"

# Selecting SNPs
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${raw_input_vcf}" \
  -o "${raw_snp_vcf}" \
  -selectType SNP \
  -nt 14 &>  "${select_snp_log}"

# Progress report
echo "Completed selecting SNPs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Select INDELs --- #

# Progress report
echo "Started selecting INDELs"

# File names
raw_indel_vcf="${tmp_folder}/${dataset_name}_indel_raw.vcf"
select_indel_log="${logs_folder}/${dataset_name}_indel_select.log"

# Selecting INDELs
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${raw_input_vcf}" \
  -o "${raw_indel_vcf}" \
  -selectType INDEL \
  -nt 14 &>  "${select_indel_log}"

# Progress report
echo "Completed selecting INDELs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Select MIXEDs --- #

# Progress report
echo "Started selecting MIXEDs"

# File names
raw_mixed_vcf="${tmp_folder}/${dataset_name}_mixed_raw.vcf"
select_mixed_log="${logs_folder}/${dataset_name}_mixed_select.log"

# Selecting MIXEDs
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${raw_input_vcf}" \
  -o "${raw_mixed_vcf}" \
  --selectTypeToExclude SNP \
  --selectTypeToExclude INDEL \
  -nt 14 &>  "${select_mixed_log}"

# An alterantive way:
# --selectType MIXED \
# did not work

# Progress report
echo "Completed selecting MIXEDs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Filter SNPs --- #

# Progress report
echo "Started filtering SNPs"

# File names
filt_snp_vcf="${tmp_folder}/${dataset_name}_snp_filt.vcf"
filt_snp_log="${logs_folder}/${dataset_name}_snp_filt.log"

# Filtering SNPs
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantFiltration \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${raw_snp_vcf}" \
  -o "${filt_snp_vcf}" \
  --filterName "SNP_DP_LESS_THAN_${MIN_SNP_DP}" \
  --filterExpression "DP < ${MIN_SNP_DP}" \
  --filterName "SNP_QUAL_LESS_THAN_${MIN_SNP_QUAL}" \
  --filterExpression "QUAL < ${MIN_SNP_QUAL}" \
  --filterName "SNP_VQSR_Tranche_${SNP_TS}+" \
  --filterExpression "VQSLOD < ${MIN_SNP_VQSLOD}" \
  &>  "${filt_snp_log}"

# Progress report
echo "Completed filtering SNPs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Filter INDELs --- #

# Progress report
echo "Started filtering INDELs"

# File names
filt_indel_vcf="${tmp_folder}/${dataset_name}_indel_filt.vcf"
filt_indel_log="${logs_folder}/${dataset_name}_indel_filt.log"

# Filtering INDELs
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantFiltration \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${raw_indel_vcf}" \
  -o "${filt_indel_vcf}" \
  --filterName "INDEL_DP_LESS_THAN_${MIN_INDEL_DP}" \
  --filterExpression "DP < ${MIN_INDEL_DP}" \
  --filterName "INDEL_QUAL_LESS_THAN_${MIN_INDEL_QUAL}" \
  --filterExpression "QUAL < ${MIN_INDEL_QUAL}" \
  --filterName "INDEL_VQSR_Tranche_${INDEL_TS}+" \
  --filterExpression "VQSLOD < ${MIN_INDEL_VQSLOD}" \
  &>  "${filt_indel_log}"

# Progress report
echo "Completed filtering INDELs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Filter MIXEDs --- #

# Progress report
echo "Started filtering MIXEDs"

# File names
filt_mixed_vcf="${tmp_folder}/${dataset_name}_mixed_filt.vcf"
filt_mixed_log="${logs_folder}/${dataset_name}_mixed_filt.log"

# Filtering MIXEDs
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantFiltration \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${raw_mixed_vcf}" \
  -o "${filt_mixed_vcf}" \
  --filterName "MIXED_DP_LESS_THAN_${MIN_MIXED_DP}" \
  --filterExpression "DP < ${MIN_MIXED_DP}" \
  --filterName "MIXED_QUAL_LESS_THAN_${MIN_MIXED_QUAL}" \
  --filterExpression "QUAL < ${MIN_MIXED_QUAL}" \
  --filterName "MIXED_VQSLOD_LESS_THAN_${MIN_MIXED_VQSLOD}" \
  --filterExpression "VQSLOD < ${MIN_MIXED_VQSLOD}" \
  &>  "${filt_mixed_log}"

# Progress report
echo "Completed filtering MIXEDs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Combine split files --- #

# Progress report
echo "Started combining vcfs"

# File name
combined_vcf="${tmp_folder}/${dataset_name}_${filter_name}_cmb.vcf"
combining_log="${logs_folder}/${dataset_name}_${filter_name}_cmb.log"

# Combining vcfs
"${java7}" -Xmx60g -jar "${gatk}" \
  -T CombineVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  --variant:snp "${filt_snp_vcf}" \
  --variant:indel "${filt_indel_vcf}" \
  --variant:mixed "${filt_mixed_vcf}" \
  -o "${combined_vcf}" \
  -genotypeMergeOptions PRIORITIZE \
  -priority snp,indel,mixed \
  &>  "${combining_log}"

# Note:
# The variants do not overlap, so the order of priorities is not important
# (just in case the priorities are set according the expected qulity of calls)  

# Progress report
echo "Completed combining vcfs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make mask for padding --- #

# Progress report
echo "Started making padding mask"

# File names
targeted_vcf="${tmp_folder}/${dataset_name}_${filter_name}_tgt.vcf"
select_targeted_log="${logs_folder}/${dataset_name}_${filter_name}_tgt_select.log"

# Selecting variants on targets with required padding
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip "${padding}" \
  -V "${combined_vcf}" \
  -o "${targeted_vcf}" \
  -nt 14 &>  "${select_targeted_log}"

# Progress report
echo "Completed making padding mask: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Apply mask for padding --- #

# Progress report
echo "Started applying padding mask"

# File names
padded_vcf="${tmp_folder}/${dataset_name}_${filter_name}_pad.vcf"
mask_padding_log="${logs_folder}/${dataset_name}_${filter_name}_pad.log"

# Mask variants outside of the targets selected above
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantFiltration \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${combined_vcf}" \
  -o "${padded_vcf}" \
  --mask "${targeted_vcf}" \
  --filterNotInMask \
  --maskName "NotOnTargets" \
  &>  "${mask_padding_log}"

# An alterantive way of combining
# --mask targets.bed
# --maskExtension 10
# --filterNotInMask
# did not work (it was reducing the num of variants comparatively to full removal of padding)

# Progress report
echo "Completed applying padding mask: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Filter MultiAllelic --- #

# File names
filt_ma_vcf="${tmp_folder}/${dataset_name}_${filter_name}_ma.vcf"
filt_ma_log="${logs_folder}/${dataset_name}_${filter_name}_ma.log"

# If the filtering was requested
if [ "${ExcludeMultiAllelic}" == "yes" ] || [ "${ExcludeMultiAllelic}" == "Yes" ]  
then

  # Progress report
  echo "Started filtering MultiAllelic variants"

  # Filtering MultiAllelic
  "${java7}" -Xmx60g -jar "${gatk}" \
    -T VariantFiltration \
    -R "${ref_genome}" \
    -L "${nextera_targets_intervals}" -ip 100 \
    -V "${padded_vcf}" \
    -o "${filt_ma_vcf}" \
    --filterName "MultiAllelic" \
    --filterExpression "MultiAllelic" \
    &>  "${filt_ma_log}"

  # Progress report
  echo "Completed filtering MultiAllelic: $(date +%d%b%Y_%H:%M:%S)"
  echo ""

else

  cp -f "${padded_vcf}" "${filt_ma_vcf}"
  cp -f "${padded_vcf}.idx" "${filt_ma_vcf}.idx"

  echo "MultiAllelic sites are not filtered out"
  echo ""
fi 

# --- Filter variants by frequency in 1k --- # 

# File names
out_vcf="${filtered_vcf_folder}/${dataset_name}_${filter_name}.vcf"
filt_fa_log="${logs_folder}/${dataset_name}_${filter_name}_fa.log"

# If the filtering was not requested
if [ "${fa_threshold}" == "no" ] || [ "${fa_threshold}" == "No" ] 
then

  cp -f "${filt_ma_vcf}" "${out_vcf}"
  cp -f "${filt_ma_vcf}.idx" "${out_vcf}.idx"
  
  echo "Sites with high frequency in 1k are not filtered out"
  echo ""

else

  # Progress report
  echo "Started filtering variants by frequency in 1k"
  
  # Set filter
  fa_filter="ALT_frequency_in_1k_${fa_threshold}"

  # Filtering MultiAllelic
  "${java7}" -Xmx60g -jar "${gatk}" \
    -T VariantFiltration \
    -R "${ref_genome}" \
    -L "${nextera_targets_intervals}" -ip 100 \
    -V "${filt_ma_vcf}" \
    -o "${out_vcf}" \
    --filterName "${fa_filter}" \
    --filterExpression "${fa_filter}" \
    &>  "${filt_fa_log}"

  # Progress report
  echo "Completed filtering variants by frequency in 1k: $(date +%d%b%Y_%H:%M:%S)"
  echo ""

fi 

# --- Make md5 file --- #

out_vcf_md5="${filtered_vcf_folder}/${dataset_name}_${filter_name}.md5"
md5sum $(basename "${out_vcf}") $(basename "${out_vcf}.idx") > "${out_vcf_md5}"

# --- Prepare data for histograms --- #

# Progress report
echo "Started preparing data for histograms"

# File names
histograms_data_txt="${histograms_folder}/${dataset_name}_${filter_name}_hist_data.txt"
histograms_data_log="${logs_folder}/${dataset_name}_${filter_name}_hist_data.log"

# Prepare data
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantsToTable \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${out_vcf}" \
  -F RawVarID -F FILTER -F TYPE -F MultiAllelic \
  -F ALT_frequency_in_1k_90 -F ALT_frequency_in_1k_95 -F ALT_frequency_in_1k_99 -F ALT_frequency_in_1k_100 \
  -F CHROM -F POS -F REF -F ALT -F DP -F QUAL -F VQSLOD \
  -o "${histograms_data_txt}" \
  -AMD -raw &>  "${histograms_data_log}"  

# -AMD allow missed data
# -raw keep filtered (the filtered variants are removed later in R scripts)

# Progress report
echo "Completed preparing data for histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Generate histograms using R markdown script --- #

# Progress report
echo "Started making histograms"

# File names
histograms_report_pdf="${histograms_folder}/${dataset_name}_${filter_name}_hist.pdf"
histograms_report_html="${histograms_folder}/${dataset_name}_${filter_name}_hist.html"
histograms_plot_log="${logs_folder}/${dataset_name}_${filter_name}_hist_plot.log"

# Prepare R script for pdf report
latex_dataset_name="${dataset_name//_/-}" # Underscores have special meaning in LaTex, 
latex_filter_name="${filter_name//_/-}"   # so they should be avoided in PDF output

pdf_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r01_make_pdf.Rmd', params=list(dataset='"${latex_dataset_name}-${latex_filter_name}"' , data_file='"${histograms_data_txt}"'), output_file='"${histograms_report_pdf}"')"

# Prepare R script for html report
html_dataset_filter_name="${dataset_name} ${filter_name}"

html_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r02_make_html.Rmd', params=list(dataset='"${html_dataset_filter_name}"' , working_folder='"${histograms_folder}"/' , data_file='"${histograms_data_txt}"'), output_file='"${histograms_report_html}"')"

# Execute R script for pdf report
echo "-------------- Preparing pdf report -------------- " > "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"
"${r_bin_folder}/R" -e "${pdf_script}" &>> "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"

# Execute R script for html report
echo "-------------- Preparing html report -------------- " >> "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"
"${r_bin_folder}/R" -e "${html_script}" &>> "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"

# Progress report
echo "Completed making histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- vcfstats for all variants --- #

# Progress report
echo "Started calculating vcfstats and making plots for all variants"
echo ""

# File names
all_vcf_stats="${all_vcfstats_folder}/${dataset_name}_${filter_name}_all.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${out_vcf}" > "${all_vcf_stats}" 

# Plot the stats
"${plot_vcfstats}" "${all_vcf_stats}" -p "${all_vcfstats_folder}/"
echo ""

# Completion message to log
echo "Completed calculating vcf stats: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make a "clean" copy of vcf without filtered variants --- #

# Progress report
echo "Started making clean vcf vithout filtered variants"

# File names
cln_vcf="${filtered_vcf_folder}/${dataset_name}_${filter_name}_cln.vcf"
cln_vcf_md5="${filtered_vcf_folder}/${dataset_name}_${filter_name}_cln.md5"
cln_vcf_log="${logs_folder}/${dataset_name}_${filter_name}_cln.log"

# Exclude filtered variants
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${out_vcf}" \
  -o "${cln_vcf}" \
  --excludeFiltered \
  -nt 14 &>  "${cln_vcf_log}"

# Make md5 file
md5sum $(basename "${cln_vcf}") $(basename "${cln_vcf}.idx") > "${cln_vcf_md5}"

# Completion message to log
echo "Completed making clean vcf: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- vcfstats for clean data --- #

# Progress report
echo "Started calculating vcfstats and making plots for clean variants"
echo ""

# File names
cln_vcf_stats="${cln_vcfstats_folder}/${dataset_name}_${filter_name}_cln.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${cln_vcf}" > "${cln_vcf_stats}" 

# Plot the stats
"${plot_vcfstats}" "${cln_vcf_stats}" -p "${cln_vcfstats_folder}/"
echo ""

# Completion message to log
echo "Completed calculating vcf stats: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Copy results to NAS --- #

# Progress report
echo "Started copying results to NAS"

# Remove temporary data
rm -fr "${tmp_folder}"

# Copy files to NAS
rsync -thrqe "ssh -x" "${filtered_vcf_folder}" "${data_server}:${project_location}/${project}/" 
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
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}/${dataset_name}_${filter_name}_vcf"
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}" # just in case...
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}" # just in case...

# Progress report to log on nas
log_on_nas="${project_location}/${project}/${dataset_name}_${filter_name}_vcf/logs/${dataset_name}_${filter_name}.log"
timestamp="$(date +%d%b%Y_%H:%M:%S)"
ssh -x "${data_server}" "echo \"Completed copying results to NAS: ${timestamp}\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Remove results from cluster
rm -f "${out_vcf}"
rm -f "${out_vcf}.idx"
rm -f "${out_vcf_md5}"

rm -f "${cln_vcf}"
rm -f "${cln_vcf}.idx"
rm -f "${cln_vcf_md5}"

#rm -fr "${logs_folder}"
rm -fr "${histograms_folder}"
rm -fr "${vcfstats_folder}"

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
