#!/bin/bash

# s01_genotype_gvcfs.sh
# Genotype gvcfs, add variants IDs, VQSR annotations and multiallelic flag; calculate stats for raw VCFs
# Alexey Larionov, 10Feb2016

# Read parameters
job_file="${1}"
scripts_folder="${2}"

# Update pipeline log
echo "Started s01_genotype_gvcfs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Set parameters
source "${scripts_folder}/a02_read_config.sh"
echo "Read settings"
echo ""

# Make folders
tmp_folder="${raw_vcf_folder}/tmp"
mkdir -p "${tmp_folder}"
mkdir -p "${vqsr_folder}"
mkdir -p "${all_vcfstats_folder}"
mkdir -p "${cln_vcfstats_folder}"
mkdir -p "${histograms_folder}"

# Go to working folder
init_dir="$(pwd)"
cd "${raw_vcf_folder}"

# --- Copy source gvcfs to cluster --- #

# Progress report
echo "Started copying source data"
echo ""

# Initialise file for list of source gvcfs
source_gvcfs="${raw_vcf_folder}/${dataset}.list"
> "${source_gvcfs}"

# For each library
for set in ${sets}
do

  # Copy data
  rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/combined_gvcfs/${set}.g.vcf" "${tmp_folder}/"
  exit_code_1="${?}"

  rsync -thrqe "ssh -x" "${data_server}:${project_location}/${project}/combined_gvcfs/${set}.g.vcf.idx" "${tmp_folder}/"
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

  # Add gvcf file name to the list of source gvcfs
  echo "${tmp_folder}/${set}.g.vcf" >> "${source_gvcfs}"

  # Progress report
  echo "${set}"

done # next set

# Progress report
echo ""
echo "Completed copying source data: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Genotype gvcfs --- #

# Progress report
echo "Started genotyping gvcfs"

# File names
raw_vcf="${tmp_folder}/${dataset}_raw.vcf"
genotyping_log="${logs_folder}/${dataset}_genotyping.log"

# Genotype
"${java7}" -Xmx60g -jar "${gatk}" \
  -T GenotypeGVCFs \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -maxAltAlleles "${maxAltAlleles}" \
  -stand_call_conf "${stand_call_conf}" \
  -stand_emit_conf "${stand_emit_conf}" \
  -nda \
  -V "${source_gvcfs}" \
  -o "${raw_vcf}" \
  -nt 14 &>  "${genotyping_log}"

# Standard call confidence is set to the GATK default (30.0)

# Multiple Alt alleles options:
# the alt alleles are not necesserely given in frequency order
# -nda : show number of discovered alt alleles
# maxAltAlleles : how many of the Alt alleles will be genotyped (default 6)
  

# Progress report
echo "Completed genotyping gvcfs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Trim the variants --- #
# Removes variants and alleles that have not been detected in any genotype

# Progress report
echo "Started trimming variants"

# File names
trim_vcf="${tmp_folder}/${dataset}_trim.vcf"
trim_log="${logs_folder}/${dataset}_trim.log"

"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${raw_vcf}" \
  -o "${trim_vcf}" \
  --excludeNonVariants \
  --removeUnusedAlternates \
  -nt 14 &>  "${trim_log}"

# Note: 
# Somehow this trimming looks excessive in our pipeline
# because it does not change the num of variants: 
echo "Num of variants before trimming: $(grep -v "^#" "${raw_vcf}" | wc -l)"
# 794680
echo "Num of variants after trimming: $(grep -v "^#" "${trim_vcf}" | wc -l)"
# 794680

# Progress report
echo "Completed trimming variants: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add variants IDs to INFO field --- #
# To trace variants during the later steps

# Progress report
echo "Started adding variants IDs to INFO field"

# File name
trim_id_vcf="${tmp_folder}/${dataset}_trim_id.vcf"

# Compile names for temporary files
tmp1=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_tmp1".XXXXXX)
tmp2=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_tmp2".XXXXXX)
tmp3=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_tmp3".XXXXXX)
tmp4=$(mktemp --tmpdir="${tmp_folder}" "${dataset}_tmp4".XXXXXX)

# Prepare data witout header
grep -v "^#" "${trim_vcf}" > "${tmp1}"
awk '{printf("RawVarID=var%09d\t%s\n", NR, $0)}' "${tmp1}" > "${tmp2}"
awk 'BEGIN {OFS="\t"} ; { $9 = $9";"$1 ; print}' "${tmp2}" > "${tmp3}"
cut -f2- "${tmp3}" > "${tmp4}"

# Prepare header
grep "^##" "${trim_vcf}" > "${trim_id_vcf}"
echo '##INFO=<ID=RawVarID,Number=1,Type=String,Description="Raw Variant ID">' >> "${trim_id_vcf}"
grep "^#CHROM" "${trim_vcf}" >> "${trim_id_vcf}"

# Append data to header in the output file
cat "${tmp4}" >> "${trim_id_vcf}"

# Progress report
echo "Completed adding variants IDs to INFO field: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make mask for multiallelic variants --- #

# Progress report
echo "Started making mask for multiallelic variants"

# File names
trim_id_ma_mask_vcf="${tmp_folder}/${dataset}_trim_id_ma_mask.vcf"
trim_id_ma_mask_log="${logs_folder}/${dataset}_trim_id_ma_mask.log"

# Make mask
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${trim_id_vcf}" \
  -o "${trim_id_ma_mask_vcf}" \
  -restrictAllelesTo MULTIALLELIC \
  -nt 14 &>  "${trim_id_ma_mask_log}"

# Progress report
echo "Completed making mask: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add flag for multiallelic variants --- #

# Progress report
echo "Started adding flag for multiallelic variants"

# File names
trim_id_ma_vcf="${tmp_folder}/${dataset}_trim_id_ma.vcf"
trim_id_ma_log="${logs_folder}/${dataset}_trim_id_ma.log"

# Add info
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${trim_id_vcf}" \
  -comp:MultiAllelic "${trim_id_ma_mask_vcf}" \
  -o "${trim_id_ma_vcf}" \
  -nt 14 &>  "${trim_id_ma_log}"

# Progress report
echo "Completed adding flag for multiallelic variants: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Add flags for variants with frequent alt allele in 1k ph3 (b37) --- #

# Progress report
echo "Started adding flags for variants with frequent alt allele in 1k ph3 (b37)"

# File names
trim_id_ma_fa_vcf="${tmp_folder}/${dataset}_trim_id_ma_fa.vcf"
trim_id_ma_fa_log="${logs_folder}/${dataset}_trim_id_ma_fa.log"

# Add info
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantAnnotator \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${trim_id_ma_vcf}" \
  -comp:ALT_frequency_in_1k_90 "${fa_mask_90}" \
  -comp:ALT_frequency_in_1k_95 "${fa_mask_95}" \
  -comp:ALT_frequency_in_1k_99 "${fa_mask_99}" \
  -comp:ALT_frequency_in_1k_100 "${fa_mask_100}" \
  -o "${trim_id_ma_fa_vcf}" \
  -nt 14 &>  "${trim_id_ma_fa_log}"

# Progress report
echo "Completed adding flag: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Train vqsr snp model --- #

# Progress report
echo "Started training vqsr snp model"

# File names
recal_snp="${vqsr_folder}/${dataset}_snp.recal"
plots_snp="${vqsr_folder}/${dataset}_snp_plots.R"
tranches_snp="${vqsr_folder}/${dataset}_snp.tranches"
log_train_snp="${logs_folder}/${dataset}_snp_train.log"

# Train vqsr snp model
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantRecalibrator \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -input "${trim_id_ma_fa_vcf}" \
  -resource:hapmap,known=false,training=true,truth=true,prior=15.0 "${hapmap}" \
  -resource:omni,known=false,training=true,truth=true,prior=12.0 "${omni}" \
  -resource:1000G,known=false,training=true,truth=false,prior=10.0 "${phase1_1k_hc}" \
  -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 "${dbsnp_138}" \
  -an QD -an MQ -an MQRankSum -an ReadPosRankSum -an FS -an SOR -an InbreedingCoeff \
  -recalFile "${recal_snp}" \
  -tranchesFile "${tranches_snp}" \
  -rscriptFile "${plots_snp}" \
  --target_titv 3.2 \
  -mode SNP \
  -tranche 100.0 -tranche 99.0 -tranche 97.0 -tranche 95.0 -tranche 90.0 \
  -nt 14 &>  "${log_train_snp}"

# Progress report
echo "Completed training vqsr snp model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Apply vqsr snp model --- #

# Progress report
echo "Started applying vqsr snp model"

# File names
vqsr_snp_vcf="${tmp_folder}/${dataset}_snp_vqsr.vcf"
log_apply_snp="${logs_folder}/${dataset}_snp_apply.log"

# Apply vqsr snp model
"${java7}" -Xmx60g -jar "${gatk}" \
  -T ApplyRecalibration \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -input "${trim_id_ma_fa_vcf}" \
  -recalFile "${recal_snp}" \
  -tranchesFile "${tranches_snp}" \
  -o "${vqsr_snp_vcf}" \
  -mode SNP \
  -nt 14 &>  "${log_apply_snp}"  

# Progress report
echo "Completed applying vqsr snp model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Train vqsr indel model --- #

# Progress report
echo "Started training vqsr indel model"

# File names
recal_indel="${vqsr_folder}/${dataset}_indel.recal"
plots_indel="${vqsr_folder}/${dataset}_indel_plots.R"
tranches_indel="${vqsr_folder}/${dataset}_indel.tranches"
log_train_indel="${logs_folder}/${dataset}_indel_train.log"

# Train model
"${java7}" -Xmx60g -jar "${gatk}" \
  -T VariantRecalibrator \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -input "${vqsr_snp_vcf}" \
  -resource:mills,known=false,training=true,truth=true,prior=12.0 "${mills}" \
  -resource:dbsnp,known=true,training=false,truth=false,prior=2.0 "${dbsnp_138}" \
  -an QD -an FS -an SOR -an ReadPosRankSum -an MQRankSum -an InbreedingCoeff \
  -recalFile "${recal_indel}" \
  -tranchesFile "${tranches_indel}" \
  -rscriptFile "${plots_indel}" \
  -tranche 100.0 -tranche 99.0 -tranche 97.0 -tranche 95.0 -tranche 90.0 \
  --maxGaussians 4 \
  -mode INDEL \
  -nt 14 &>  "${log_train_indel}"

# Progress report
echo "Completed training vqsr indel model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Apply vqsr indel model --- #

# Progress report
echo "Started applying vqsr indel model"

# File names
out_vcf="${raw_vcf_folder}/${dataset}_raw.vcf"
out_vcf_md5="${raw_vcf_folder}/${dataset}_raw.md5"
log_apply_indel="${logs_folder}/${dataset}_indel_apply.log"

# Apply vqsr indel model
"${java7}" -Xmx60g -jar "${gatk}" \
  -T ApplyRecalibration \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -input "${vqsr_snp_vcf}" \
  -recalFile "${recal_indel}" \
  -tranchesFile "${tranches_indel}" \
  -o "${out_vcf}" \
  -mode INDEL \
  -nt 14 &>  "${log_apply_indel}"  

# Make md5 file
md5sum $(basename "${out_vcf}") $(basename "${out_vcf}.idx") > "${out_vcf_md5}"

# Progress report
echo "Completed applying vqsr indel model: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Prepare data for histograms --- #

# Progress report
echo "Started preparing data for histograms"

# File names
histograms_data_txt="${histograms_folder}/${dataset}_histograms_data.txt"
histograms_data_log="${logs_folder}/${dataset}_histograms_data.log"

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
# -raw keep filtered

# Progress report
echo "Completed preparing data for histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Generate histograms using R markdown script --- #

# Progress report
echo "Started making histograms"

# File names
histograms_report_pdf="${histograms_folder}/${dataset}_histograms_report.pdf"
histograms_report_html="${histograms_folder}/${dataset}_histograms_report.html"
histograms_plot_log="${logs_folder}/${dataset}_histograms_plot.log"

# Prepare R scripts
latex_dataset="${dataset//_/-}" # Underscores have special meaning in LaTex, so they should be avoided in PDF output

pdf_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r01_make_pdf.Rmd', params=list(dataset='"${latex_dataset}-raw"' , data_file='"${histograms_data_txt}"'), output_file='"${histograms_report_pdf}"')"

html_script="library('rmarkdown', lib='"${r_lib_folder}"'); render('"${scripts_folder}"/r02_make_html.Rmd', params=list(dataset='"${dataset}-raw"' , working_folder='"${histograms_folder}"/' , data_file='"${histograms_data_txt}"'), output_file='"${histograms_report_html}"')"

# Execute R scripts
# Notes:
# Path to R was added to environment and modules required for 
# R with knitr were loaded in s01_genotype_gvcfs.sb.sh:
# module load gcc/5.2.0
# module load boost/1.50.0
# module load texlive/2015
# module load pandoc/1.15.2.1

# Underscore within ${dataset} may cause problem during rendering of pdf report

echo "-------------- Preparing pdf report -------------- " > "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"
"${r_bin_folder}/R" -e "${pdf_script}" &>> "${histograms_plot_log}"

echo "-------------- Preparing html report -------------- " >> "${histograms_plot_log}"
echo "" >> "${histograms_plot_log}"
"${r_bin_folder}/R" -e "${html_script}" &>> "${histograms_plot_log}"

echo "" >> "${histograms_plot_log}"

# Progress report
echo "Completed making histograms: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Calculating vcfstats for full data emitted by HC --- #

# Progress report
echo "Started vcfstats"
echo ""

# File name
vcf_stats="${all_vcfstats_folder}/${dataset}_raw.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${out_vcf}" > "${vcf_stats}" 
#To be done: explore -R option to focus stats on targets:
# -R "${nextera_targets_bed}" ?? 

# Plot the stats
"${plot_vcfstats}" "${vcf_stats}" -p "${all_vcfstats_folder}/"
echo ""

# Progress report
echo "Completed vcfstats: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Make a "clean" copy of vcf without filtered variants --- #

# Progress report
echo "Started making clean vcf vithout HC filtered variants"

# File names
cln_vcf="${raw_vcf_folder}/${dataset}_raw_cln.vcf"
cln_vcf_md5="${raw_vcf_folder}/${dataset}_raw_cln.md5"
cln_vcf_log="${logs_folder}/${dataset}_raw_cln.log"

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

# --- Calculating vcfstats after minimal HC and VQSR filters--- #

# Progress report
echo "Started vcfstats on clean data"
echo ""

# File name
vcf_stats="${cln_vcfstats_folder}/${dataset}_cln.vchk"

# Calculate vcf stats
"${bcftools}" stats -F "${ref_genome}" "${cln_vcf}" > "${vcf_stats}" 
#To be done: explore -R option to focus stats on targets:
# -R "${nextera_targets_bed}" ?? 

# Plot the stats
"${plot_vcfstats}" "${vcf_stats}" -p "${cln_vcfstats_folder}/"
echo ""

# Progress report
echo "Completed vcfstats on clean data: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# --- Copy output back to NAS --- #

# Progress report
echo "Started copying results to NAS"

# Remove temporary files from cluster
rm -fr "${tmp_folder}"

# Copy files to NAS
rsync -thrqe "ssh -x" "${raw_vcf_folder}" "${data_server}:${project_location}/${project}/" 
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
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}/${dataset}_${raw_vcf_folder_suffix}"
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}/${project}" # just in case...
ssh -x "${data_server}" "chown -R ${mgqnap_user}:${mgqnap_group} ${project_location}" # just in case...

# Progress report
log_on_nas="${project_location}/${project}/${dataset}_raw_vcf/logs/${dataset}_genotype_and_assess.log"

ssh -x "${data_server}" "echo \"Completed copying results to NAS: $(date +%d%b%Y_%H:%M:%S)\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Remove results from cluster
#rm -fr "${logs_folder}"
rm -fr "${vqsr_folder}"
rm -fr "${histograms_folder}"
rm -fr "${vcfstats_folder}"

rm -f "${source_gvcfs}"

rm -f "${out_vcf}"
rm -f "${out_vcf}.idx"
rm -f "${out_vcf_md5}"

rm -f "${cln_vcf}"
rm -f "${cln_vcf}.idx"
rm -f "${cln_vcf_md5}"

ssh -x "${data_server}" "echo \"Removed results from cluster\" >> ${log_on_nas}"
ssh -x "${data_server}" "echo \"\" >> ${log_on_nas}"

# Return to the initial folder
cd "${init_dir}"

# Remove project folder (if requested)
if [ "${remove_project_folder}" == "yes" ] || [ "${remove_project_folder}" == "Yes" ] 
then 
  rm -fr "${project_folder}"
  ssh -x "${data_server}" "echo \"Removed working folder from cluster\" >> ${log_on_nas}"
else
  ssh -x "${data_server}" "echo \"Working folder is left on cluster\" >> ${log_on_nas}"
fi 
