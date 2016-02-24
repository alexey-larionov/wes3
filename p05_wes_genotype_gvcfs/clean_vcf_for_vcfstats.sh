# --- Make a clean copy of vcf for vcfstats --- #

# Progress report
echo "Started making clean copy of vcf for vcfstats"

# File names
clean_vcf="${vcfstats_folder}/${dataset_name}_cln.vcf"
clean_vcf_md5="${vcfstats_folder}/${dataset_name}_cln.md5"
clean_vcf_log="${logs_folder}/${dataset_name}_cln.log"

# Exclude filtered variants
"${java7}" -Xmx60g -jar "${gatk}" \
  -T SelectVariants \
  -R "${ref_genome}" \
  -L "${nextera_targets_intervals}" -ip 100 \
  -V "${out_vcf}" \
  -o "${clean_vcf}" \
  --excludeFiltered \
  -nt 14 &>  "${clean_vcf_log}"

# Make md5 file
cd "${vcfstats_folder}"
md5sum $(basename "${clean_vcf}") $(basename "${clean_vcf}.idx") > "${clean_vcf_md5}"
cd "${raw_vcf_folder}"

# Completion message to log
echo "Completed making clean copy of vcf for vcfstats: $(date +%d%b%Y_%H:%M:%S)"
echo ""
