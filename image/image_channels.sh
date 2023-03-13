#!/bin/bash

#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=micah.bowles@postgrad.manchester.ac.uk
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=24
#SBATCH --mem=50G
#SBATCH --job-name=ImgChan
#SBATCH --time=5-00:00:00
#SBATCH --array=0-221
#SBATCH --output=logs/%A_%a.%x.out
#SBATCH --error=logs/%A_%a.%x.err
#SBATCH --exclude=compute-0-1,compute-0-2,compute-0-30

sleep ${SLURM_ARRAY_TASK_ID}s

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
module load openmpi-2.1.1
ulimit -n 16384


echo "Start time:"
date +'%Y-%m-%d %H:%M:%S'
DATE_START=`date +%s`


MS_NAME=$(basename $VIS)

# TEMPORARILY REMOVE ALL FILES IN TMP_DIR
rm -rf $TMP_DIR

# SPLIT DATA ONTO LOCAL SCRATCH DISK
TMP_OUTDIR="${TMP_DIR}/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
echo ">>> ls -lht TMP_OUTDIR ($TMP_OUTDIR)"
ls -lht $TMP_OUTDIR
# echo ">>> du -sh TMP_OUTDIR ($TMP_OUTDIR)"
# du -sh ${TMP_OUTDIR}/*
echo ">>> rm -r TMP_OUTDIR ($TMP_OUTDIR)"
rm -r $TMP_OUTDIR
echo ">>> mkdir --parents TMP_OUTDIR ($TMP_OUTDIR)"
mkdir --parents $TMP_OUTDIR
pwd
cd $TMP_OUTDIR
pwd

echo ">>> Splitting out Channel ${SLURM_ARRAY_TASK_ID}. Running on ${SLURM_JOB_NODELIST} <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python /share/nas2/mbowles/MIGHTEE-POL_imaging/split/split.py \
    --vis="$VIS" \
    --channelwidth=$CHANNEL_WIDTH \
    --outdir=$TMP_OUTDIR \
    --index=$SLURM_ARRAY_TASK_ID

SPLIT_VIS="${TMP_OUTDIR}/$(basename ${VIS%.*ms})_chan_${SLURM_ARRAY_TASK_ID}.ms"
TMP_IMAGE_DIR="${TMP_OUTDIR}/images"
echo ">>> Making image tmp image directory ${TMP_IMAGE_DIR} (TMP_IMAGE_DIR)."
mkdir --parents $TMP_IMAGE_DIR

# IMAGE FOR EACH ROBUST PARAMETER
ROBUST="$1"
echo ">>> Imaging Call of a Channel ${SLURM_ARRAY_TASK_ID} robust ${ROBUST}. Running on ${SLURM_JOB_NODELIST} <<<"
time singularity exec --bind /share,/state/partition1 $CONTAINER \
  python /share/nas2/mbowles/MIGHTEE-POL_imaging/image/image_channels.py \
      --polarisation \
      --robust=$ROBUST \
      --vis=$SPLIT_VIS \
      --outpath=$TMP_IMAGE_DIR

# COPYING DATA OUT
echo ">>> Copying from local disk (${TMP_IMAGE_DIR}/*) to NAS (${OUTDIR}/chan_imgs/${SLURM_ARRAY_TASK_ID}/)"
mkdir --parents $OUTDIR/chan_images/$SLURM_ARRAY_TASK_ID/
cp -r $TMP_IMAGE_DIR/* $OUTDIR/chan_imgs/$SLURM_ARRAY_TASK_ID/
# CLEAN UP SCRATCH DISK
echo ">>> Removing data from scratch
cd $TMP_DIR
rm -r $TMP_OUTDIR

echo "Finishing time:"
date +'%Y-%m-%d %H:%M:%S'

DATE_END=`date +%s`
SECONDS=$((DATE_END-DATE_START))
MINUTES=$((SECONDS/60))
SECONDS=$((SECONDS-60*MINUTES))
HOURS=$((MINUTES/60))
MINUTES=$((MINUTES-60*hours))
echo Total run time : $HOURS Hours $MINUTES Minutes $SECONDS Seconds
