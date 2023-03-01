#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=1500G
#SBATCH --exclusive
#SBATCH --job-name=ImageMFS
#SBATCH --time=14-00:00:00
#SBATCH --output=logs/%j.%x.out
#SBATCH --error=logs/%j.%x.err

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
module load openmpi-2.1.1
ulimit -n 16384

VIS_TMP=$VIS
ROBUST="$1"

echo "Start time:"
echo $(date + %F;%H:%M:%S)

# Check IO file lock
while [ -f "$IO_LOCK_FILE" ]
do
  sleep 1m
done
# Activate file lock
printf "VIS: ${VIS_TMP}\nRunning on ${SLURM_JOB_NODELIST}\nLogs at: ${SLURM_JOB_NODELIST}\n" >> $IO_LOCK_FILE
echo ">>> File lock check passed ${IO_LOCK_FILE} activated."
echo $(date + %F;%H:%M:%S)

# Copy data onto local scratch disk
TMP_OUTDIR="${TMP_DIR}/${SLURM_JOB_ID}"
echo ">>> ls -lht TMP_OUTDIR ($TMP_OUTDIR)"
ls -lht $TMP_OUTDIR
echo ">>> du -sh TMP_OUTDIR ($TMP_OUTDIR)"
du -sh "${TMP_OUTDIR}/"*
echo ">>> rm -r TMP_OUTDIR ($TMP_OUTDIR)"
rm -r $TMP_OUTDIR
echo ">>> mkdir --parents TMP_OUTDIR ($TMP_OUTDIR)"
mkdir --parents $TMP_OUTDIR
pwd
cd $TMP_OUTDIR
pwd
cp -r $VIS_TMP "${TMP_OUTDIR}/"
VIS_TMP="${TMP_OUTDIR}/$(basename ${VIS_TMP})"
TMP_IMAGE_DIR="${TMP_OUTDIR}/images"
mkdir --parents $TMP_IMAGE_DIR

# Break file Lock
echo ">>> Breaking lock on ${IO_LOCK_FILE}"
echo $(date + %F;%H:%M:%S)
rm $IO_LOCK_FILE

echo ">>> MFS Imaging Call. CPUS==${OMP_NUM_THREADS} on ${SLURM_JOB_NODELIST}<<<"
echo ">>> Running on VIS=${VIS_TMP} with robust ${ROBUST}"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python /share/nas2/mbowles/MIGHTEE-POL_imaging/image/image_mfs.py \
      --polarisation \
      --robust=$ROBUST \
      --vis="$VIS_TMP" \
      --outpath="$TMP_IMAGE_DIR"

# Copying data back to NAS for storage
echo ">>> Copying from local disk (${TMP_OUTDIR}) to NAS ("${OUTDIR}/mfs_${ROBUST}/")"
mkdir --parents "${OUTDIR}/mfs_${ROBUST}"
cp -r "${TMP_IMAGE_DIR}/"* "${OUTDIR}/mfs_${ROBUST}/"
# Cleaning up scratch disk
echo ">>> Removing data from scratch"
cd $TMP_DIR
rm -r $TMP_OUTDIR

echo "Finishing time:"
echo $(date + %F;%H:%M:%S)
