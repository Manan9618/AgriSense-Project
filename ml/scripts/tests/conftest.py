import sys
from pathlib import Path

# Scripts under ml/scripts/ are flat modules (not a package) run with CWD
# implicitly on sys.path — matches how they import each other (e.g.
# prepare_dataset.py's `from class_map import CLASS_MAP`). Tests need the
# same thing set up explicitly since pytest doesn't run from that directory.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
