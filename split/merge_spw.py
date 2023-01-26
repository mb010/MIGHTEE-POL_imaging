import os, sys
import shutil
import argparse
import logging
from time import gmtime

import casatasks
from casatools import msmetadata

msmd = msmetadata()

logging.Formatter.converter = gmtime
logger = logging.getLogger(__name__)
logging.basicConfig(format="%(asctime)-15s %(levelname)s: %(message)s")
loglevel = logging.DEBUG# if verbose else logging.INFO
logger.setLevel(loglevel)

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
    parser.add_argument("-O", "--outdir", type=str, required=False, default="/share/nas2/mbowles/dev/", help="Measurement set to be imaged (default: '/share/nas/mbowles/dev/processing/).")
    parser.add_argument("-v", "--verbose", action="store_true", default=False, required=False, help="Verbose output.")
    parser.add_argument("-f", "--force", action="store_true", default=False, required=False, help="Forces overwrite of output (default: False).")
    args, unknown = parser.parse_known_args()
    return args

class Merge():
    def __init__(
        self,
        vis,
        force,
        outdir,
        ):
        # Read in parameters
        self.vis = vis
        self.outdir = outdir
        self.filebase = self.vis.rstrip('.mms').split('/')[-1]
        self.force = force
        self.merge()

    def merge(self):
        filename = f"{self.outdir}{self.filebase}_merged.ms"
        logger.info(f"Merging about to begin with vis={self.vis} and outputvis={filename}")
        casatasks.mstransform(
            vis = self.vis,
            outputvis=filename,
            combinespws=True,
            separationaxis="scan"
        )
        logger.info(f"Merged SPW and saved to: {filename}")
        return

def main():
    args = parse_args()

    merge = Merge(
        vis=args.vis,
        force=args.force,
        outdir=args.outdir
    )

if __name__=="__main__":
    main()
