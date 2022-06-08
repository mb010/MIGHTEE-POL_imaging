#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=1500G
#SBATCH --job-name=ImageMFS
#SBATCH --time=14-00:00:00
#SBATCH --output=./logs/%x.%j.out
#SBATCH --error=./logs/%x.%j.err
#SBATCH --exclude=compute-0-8

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
module load openmpi-2.1.1
ulimit -n 16384
VIS_TMP=$VIS
ROBUST="$1"

# IO Lock
IO_LOCK_FILE="/share/nas2/mbowles/nas2.lock"
while [ -f "$IO_LOCK_FILE" ]
do
  sleep 1m
done
printf "VIS: ${VIS_TMP}\nRunning on ${SLURM_JOB_NODELIST}\nLogs at: ${SLURM_JOB_NODELIST}\n" >> $IO_LOCK_FILE
echo ">>> File lock check passed ${IO_LOCK_FILE} activated."

# COPY DATA ONTO LOCAL SCRATCH DISK
TMP_OUTDIR="${TMP_DIR}/$(basename ${VIS_TMP%.*ms})"
echo ">>> ls of TMP_OUTDIR"
ls -lht $TMP_OUTDIR
du -sh $TMP_OUTDIR*
rm -r $TMP_OUTDIR
mkdir --parents $TMP_OUTDIR
pwd
cd $TMP_OUTDIR
pwd
cp -r $VIS_TMP ./
VIS_TMP="${TMP_OUTDIR}/$(basename ${VIS_TMP})"

# Break file Lock
echo ">>> Breaking lock on ${IO_LOCK_FILE}"
rm $IO_LOCK_FILE

CONTAINER=/share/nas2/mbowles/dev/casa-6_v2.simg
echo ">>> MFS Imaging Call. CPUS==${OMP_NUM_THREADS} on ${SLURM_JOB_NODELIST}<<<"
echo ">>> Running on VIS=${VIS_TMP} with robust ${ROBUST}"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python /share/nas2/mbowles/MIGHTEE-POL_imaging/image/image_mfs.py \
      --polarisation \
      --robust=$ROBUST \
      --vis="$VIS_TMP" \
      --outpath=$TMP_OUTDIR

# COPYING DATA OUT
echo ">>> Copying from local disk (${TMP_OUTDIR}) to NFS ("${OUTDIR}/mfs_${ROBUST}/")"
mkdir --parents "${OUTDIR}/mfs_${ROBUST}/"
cp -r "${TMP_OUTDIR}"* "${OUTDIR}/mfs_${ROBUST}/"
# CLEAN UP SCRATCH DISK
echo ">>> Removing data from scratch <<<"
cd ../
rm -r $TMP_OUTDIR
