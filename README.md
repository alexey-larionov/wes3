This is a pipeline to process whole exome sequencing data from fastq to annotated vcf.  The pipeline is written in Shell.  In general, the pipeline follows GATK's Best Practices, with some modifications adopted in our research group.  Overall, the pipeline includes tens of files and (much) more than 5,000 lines of code. 

The main steps include:
- Source FASTQ import and FastQC
- Alignment against b37 using BWA MEM
- BAM files merging, preprocessing and QC (samtools, picard, GATK, Qualimap etc)
- Variants calling by GATK using GVCF and HC 
- Variants assessment (custom R scripts and samtools vcfstats) 
- Variants filtering by VQSR and a set of hard filters 
- Variants annotation by VEP
- Export of annotated variants to plain text fils for downstream analysis in R.

Code is split into steps (modules), located in folders with self-explanatory names.  It is assumed that after each step the user assess the results (metrics produced by fastQC, picard, qualimap, vqsr, vcfstats, vep etc) before taking analysis to the next step.  The steps are started by the launcher script with a job description file (see folder with the job description templates).  

The pipeline is deployed on a local university cluster.  As usual, most of the scripts deal with data movement, logging, resourse monitoring etc.  The examples of actual bioinformatics code can be found in shell scripts called s*.sh (not *.sb.sh).  In addition there are examples of Rmarkdown scripts used for custom reports.  

This repository is intended for the author's pesonal use.  However, as long as it is kept public, everyone is welcome to have a look.  I will do my best to reply to e-mails addressed to alexey_larionov@hotmail.com (depending on how busy I am at the time :)  