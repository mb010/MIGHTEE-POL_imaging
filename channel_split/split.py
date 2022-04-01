import os, sys
import shutil
import argparse
import logging
from time import gmtime

import casatasks
from casatools import msmetadata

def parse_args():
    """
    Parse in command line arguments.
    """
    THIS_PROG = os.path.realpath(__file__)
    SCRIPT_DIR = os.path.dirname(THIS_PROG)

    parser = argparse.ArgumentParser(
        prog=THIS_PROG,
        description="MIGHTEE-POL Imaging: github.com/mb010/MIGHTEE-POL_imaging."
    )

    parser.add_argument("-M", "--vis", type=str, required=False, default="/share/nas2/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms", help="Measurement set to be imaged (default: '/share/nas/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms').")
    parser.add_argument("-o", "--outpath", type=str, required=False, default = "/share/nas2/mbowles/tmp", help="Full directory path where the split data are to be saved (default: '/share/nas2/mbowles/tmp').")
    parser.add_argument("-v", "--verbose", action="store_true", default=False, required=False, help="Verbose output.")
    parser.add_argument("-f", "--force", action="store_true", default=False, required=False, help="Forces overwrite of output (default: False).")

    args, unknown = parser.parse_known_args()
    return args

class Split():
    def __init__(
        self,
        vis,
        datacolumn,
        chan_width,
        force,
        outdir,
        freq_range = "880-1680"
        ):
        # Read in parameters
        self.vis = vis
        self.outdir = outdir
        self.datacolumn = datacolumn # Should maybe be 'corrected'
        self.freq_range = [int(f)*1e6 for f in frequency_range.split('-')]
        self.chan_width = int(chan_width * 1e6)
        self.filebase = self.vis.rstrip('.mms').split('/')[-1]
        self.force = force

        # Will be changed as each split is made
        self.start_freq = self.freq_range[0]
        self.out_files = []

        self.split()

    def split(self):
        while (self.start_freq <= self.freq_range[1]):
            self.start_freq = self.start_freq + self.chan_width
            self.stop_freq  = self.start_freq + self.chan_width
            self.spw = f"*:{self.start_freq}~{self.stop_freq}Hz"
            # Decided on filename formatting. Index should be easier with slurm jobs
            #filename = f"{self.outdir}{self.filebase}.{self.spw}.ms"
            filename = f"{self.outdir}/{self.filebase}{len(self.out_files)}.ms"

            if ~os.path.isdir(filename) or self.force:
                try:
                    casatasks.split(
                        vis = self.vis,
                        outputvis=filename,
                        keepmms=False,
                        width=1,
                        datacolumn=self.datacolumn
                    )
                    self.out_files.append(f"{self.outdir}/{filename}")
                except:
                    logger.warn(f"Split for range {self.spw} failed. Not including in list to be imaged")
            else:
                logger.info(f"Folder already exists at output: {filename}. Not including in list to be imaged.")
        logger.info(f"Split {len(self.out_files)} out of a total possible {(self.freq_range[1]-self.freq_range[0])//self.chan_width} channel splits.")

def main():
    args = parse_args()
    split = Split(
        vis=args['vis'],
        datacolumn='data',
        chan_width=2.5078,
        force=args['force'],
        outdir=args['outpath']
    )
    files = split.out_files
    with open(f"{split.outdir}/{split.filebase}_split.txt", 'w') as f:
        for item in my_list:
            f.write("%s\n" % item)
    # TODO: Write to txt for reading in future sbatch submission

if __name__=="__main__":
    main()
