#!/bin/bash

## s01_filter_vcf.sb.sh
## Wes library: filtering vcf by DP, QUAL and VQSLOD
## SLURM submission script
## Alexey Larionov, 18Jan2016

## Name of the job:
#SBATCH -J filter_vcf

## How much wallclock time will be required?
#SBATCH --time=00:30:00

## Which project should be charged:
#SBATCH -A TISCHKOWITZ-SL3

## What resources should be allocated?
#SBATCH --nodes=1
#SBATCH --exclusive

## What types of email messages do you wish to receive?
#SBATCH --mail-type=ALL

## Do not resubmit if interrupted by node failure or system downtime
#SBATCH --no-requeue

## Partition (do not change)
#SBATCH -p sandybridge

## Modules section (required, do not remove)
## Can be modified to set the environment seen by the application
## (note that SLURM reproduces the environment at submission irrespective of ~/.bashrc):
. /etc/profile.d/modules.sh                # Enables the module command
module purge                               # Removes all loaded modules
module load default-impi                   # Loads the basic environment (later may be changed to a MedGen specific one)

# Additional modules for knitr-rmarkdown (used for histograms)
module load gcc/5.2.0
module load boost/1.50.0
module load texlive/2015
module load pandoc/1.15.2.1

## Set initial working folder
cd "${SLURM_SUBMIT_DIR}"

## Report settings and run the job
echo ""
echo "Job name: ${SLURM_JOB_NAME}"
echo "Allocated node: $(hostname)"
echo ""
echo "Initial working folder:"
echo "${SLURM_SUBMIT_DIR}"
echo ""
echo " ------------------ Output ------------------ "
echo ""

## Read parameters
job_file="${1}"
dataset_name="${2}"
filter_name="${3}"
scripts_folder="${4}"
logs_folder="${5}"
log="${6}"

## Start resources monitoring on the background
"${scripts_folder}/a01_resources_monitor.sh" 1 "${logs_folder}/${dataset_name}_${filter_name}.res" &
resources_monitor_pid="${!}" # Take note of the resources monitor PID
echo "Started resources monitoring: $(date +%d%b%Y_%H:%M:%S)"
echo ""

## Do the job
"${scripts_folder}/s01_filter_vcf.sh" \
         "${job_file}" \
         "${scripts_folder}" &>> "${log}"

## Detach monitoring process from the shell instance 
## to avoid shell warning message when killing the process
disown "${resources_monitor_pid}" 

## Stop resources monitoring
kill -9 "${resources_monitor_pid}"
echo "Stopped resources monitoring: $(date +%d%b%Y_%H:%M:%S)"
echo ""

## Pause to let orderly completion of the killed process
sleep 60 

## When slurm closes the node immediately after killing a process it may generate an error like 
## (like "slurmstepd .. rmdir( .. ) failed Device or resource busy")
## It is a bug-like feature, similar to what was described, for instance, here:
## https://groups.google.com/forum/#!topic/slurm-devel/va1LXYFdTkc
## Giving some time for the node to run after killing the process allows to avoid the eror message.