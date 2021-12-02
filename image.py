import os, sys
import shutil
import argparse
import logging
from casatasks import tclean

from casatools import msmetadata
import casampi

logfile=casalog.logfile()
casalog.setlogfile('logs/{SLURM_JOB_NAME}-{SLURM_JOB_ID}.casa'.format(**os.environ))
msmd = msmetadata()

logging.Formatter.converter = gmtime
logger = logging.getLogger(__name__)
logging.basicConfig(format="%(asctime)-15s %(levelname)s: %(message)s")

def parse_args(THIS_PROG):
    """
    Parse in command line arguments.
    """
    THIS_PROG = os.path.realpath(__file__)
    SCRIPT_DIR = os.path.dirname(THIS_PROG)

    parser = argparse.ArgumentParser(
        prog=THIS_PROG,
        description="MIGHTEE-POL Imaging: github.com/mb010/MIGHTEE-POL_imaging."
    )

    parser.add_argument("-M", "--vis", type=str, required=False, default="/share/nas/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms", help="Measurement set to be imaged (default: '/share/nas/mbowles/dev/processing/1538856059_sdp_l0.J0217-0449.mms').")
    parser.add_argument("-o", "--outpath", type=str, required=False, default = "/share/nas/mbowles/images/", help="Full directory path where the images are to be saved (default: '/share/nas/mbowles/images/').")
    parser.add_argument("--copy", type=bool, required=False, default=False, help="Enables copying of visibility to scratch disk during processing to allow for multiple imaging steps to occur from a single visibility set. (default: False).")

    parser.add_argument("-P", "--polarisation", type=bool, required=False, default=False, help="Enables production of IQUV images (default: False).")
    parser.add_argument("-r", "--robust", type=float, required=False, default=-0.5, help="Robust parameter used for imaging (default: -0.5).")
    praser.add_argument("--clean", type=int, default=100000, required=False, help="Cleans iterations used. Set to 0 for quick dirty images (default: 100000).")
    parser.add_argument("--spectral", type=float, required=False, default=0, help="Sets spectral imaging width of cube (MHz). Uses MFS if set to 0 (default: 0).")
    parser.add_argument("--RM", type=bool, required=False, default=False, help="Produces Faraday spectra cubes (default: False).")
    parser.add_argument("--cellsize", type=float, default=1.5, required=False, help="Cell size paramter in arcsec (default: 1.0).")

    parser.add_argument("-v", "--verbose", type=bool, default=False, required=False, help="Verbose output.")
    parser.add_argument("-f", "--force", type=bool, default=False, required=False, help="Forces overwrite of output (default: False).")

    args, unknown = parser.parse_known_args()

    return args

def main():
    #--------------------------- edit these parameters -------------------------
    threshold   = '0.04mJy'
    imsize      = [6144, 6144]
    wprojplanes = 768
    datacolumn  = 'data' # Not 'corrected'?
    gridder     = 'wproject'
    cell        = '1.5arcsec'
    pol         = 'IQUV'
    uvrange     = '>0.25klambda'
    phasecenter = ""
    reffreq     = ""

    #------------------------------- running clean -----------------------------
    args = parse_args()

    # For details see: https://casa.nrao.edu/docs/taskref/tclean-task.html
    # Using CLI to generate appropriate parameters
    niter = args.clean
    cell = str(args.cellsize)+"arcsec"

    specmode = "cube" if (args.RM or abs(args.spectral)>0) else "mfs"
    width = str(args.spectral)+"MHz" if specmode=="cube" else ""
    deconvolver = "multiscale" if specmode=="cube" else "mtmfs"

    if not args.polarisation:
        stokes = ["I"]
    else:
        if specmode == "cube":
            stokes = ["I", "Q", "U", "V"]
        else:
            stokes = ["IQUV"]

    # Scales: Approximate width of largest scale object easily seen is ~2arcmin
    scales = [] if deconvolver=="mtfs" else [0, 3, 10 , 30, 80, 120]

    # Copy visibility to scratch disk if requested
    vis = args.vis
    if copy:
        TMP_DIR  = "/state/partition1/tmp_bowles/"
        os.makedirs(TMP_DIR, exist_ok=True)
        LOCAL_PATH = os.getcwd()
        os.chdir(TMP_DIR)
        logger.info(str(args.vis.split('/')[-1]))
        LOCAL_COPY = TMP_DIR + args.vis.split('/')[-1]
        shutil.copytree(vis, LOCAL_COPY)
        vis = LOCAL_COPY
    else:
        logger.warn(f"Not copying over files. This can cause a memory lock when multiple tasks are trying to access the same visibility set.")


    for stokes_ in stokes:
        # Generate unique image name
        imagename = f"{args.outpath}{args.vis.split('/')[-1]}_{specmode}_{stokes_}_{briggs_weighting}_{imsize[0]}"
        if os.path.exists(imagename) and not args.force:
            logger.error(f"An image already exists under this name, use --force to overwrite (received output path: {imagename}).")

        print(">>> Starting image: " imagename)
        tclean(
            vis=vis,selectdata=False,field="",spw="",timerange="",
            uvrange=uvrange,antenna="",scan="",observation="",intent="",
            datacolumn=datacolumn,imagename=imagename,
            imsize=imsize,cell=cell,phasecenter=phasecenter,
            stokes=stokes_,projection="SIN",startmodel="",specmode=specmode,reffreq=reffreq,
            nchan=-1,start=start,width=width,outframe="LSRK",veltype="radio",
            restfreq=[],interpolation="linear",perchanweightdensity=True,gridder=gridder,facets=1,
            psfphasecenter="",chanchunks=1,wprojplanes=wprojplanes,vptable="",mosweight=True,
            aterm=True,psterm=False,wbawp=True,conjbeams=False,cfcache="",
            usepointing=False,computepastep=360.0,rotatepastep=360.0,pointingoffsetsigdev=0.0,pblimit=0.2,
            normtype="flatnoise",deconvolver=deconvolver,scales=scales,smallscalebias=0.0,
            restoration=True,restoringbeam=[],pbcor=False,outlierfile="",weighting="briggs",
            robust=args.robust,noise="1.0Jy",npixels=0,uvtaper=[],niter=niter,
            gain=0.1,threshold=threshold,nsigma=0.0,cycleniter=-1,cyclefactor=1.0,
            minpsffraction=0.05,maxpsffraction=0.8,interactive=False,usemask="user",mask="",
            pbmask=0.0,sidelobethreshold=3.0,noisethreshold=5.0,lownoisethreshold=1.5,negativethreshold=0.0,
            smoothfactor=1.0,minbeamfrac=0.3,cutthreshold=0.01,growiterations=75,dogrowprune=True,
            minpercentchange=-1.0,verbose=args.verbose,fastnoise=True,restart=True,savemodel="none",
            calcres=True,calcpsf=True,parallel=True
        )
    # Remove temporary folder
    if copy:
        os.chdir(local)
        shutil.rmtree(vis)

if __name__=="__main__":
    main()
