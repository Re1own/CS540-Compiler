#!/bin/sh
#
# run.sh
# A simple script to compile a .tog test with toyger compiler, then run the generated .s code in MARS.
#
# Usage:
#   - Ensure you have the executable 'toyger' in the current directory or in PATH
#   - Place your .tog test files in INPUTDIR
#   - This script will produce .s in OUTPUTDIR
#   - Then it runs MARS (MAINFILE + the newly generated .s)
#   - Finally, it can compare with expected output if needed
#
# Example:
#   ./run.sh test0

# -------------------- Configuration --------------------
INPUTDIR="./mips_tests/input"             # Where your .tog inputs are
OUTPUTDIR="./my_output"              # Where the .s outputs go
EXPECTEDDIR="./mips_tests/output_expected"  # (Optional) If you compare with expected results
MARS="./Mars4_5.jar"          # Path to MARS jar
MAINFILE="./mips_tests/main.s"        # A main driver .s, if needed

# -------------------- Usage Check --------------------
if [ $# -lt 1 ]; then
  echo "Usage: $0 TEST_CASE_NAME"
  echo "  e.g. $0 test0"
  exit 1
fi

TESTNAME="$1"
INPUTFILE="$INPUTDIR/$TESTNAME.tog"
OUTPUTFILE="$OUTPUTDIR/$TESTNAME.s"

# -------------------- Basic Checks --------------------
if [ ! -f "$INPUTFILE" ]; then
  echo "Error: Input file '$INPUTFILE' not found."
  exit 1
fi

if [ ! -x "./toyger" ] && ! command -v toyger >/dev/null 2>&1; then
  echo "Error: Compiler 'toyger' not found or not executable."
  echo "Please place 'toyger' in current directory or ensure it's in PATH."
  exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUTDIR"

# -------------------- Compilation Step --------------------
echo "Test with $TESTNAME.tog:"
echo "-------------------------------------------------------------"
echo " - Use your compiler (toyger) to generate MIPS translation: $TESTNAME.s"
echo "-------------------------------------------------------------"

# If toyger is in current directory:
#   ./toyger <"$INPUTFILE" >"$OUTPUTFILE"
# or if toyger is in PATH:
./toyger <"$INPUTFILE" >"$OUTPUTFILE"

# -------------------- MARS Assembly & Run --------------------
echo ""
echo "-------------------------------------------------------------"
echo " - Verify generated MIPS assembles and runs under MARS"
echo "-------------------------------------------------------------"
echo "Running MIPS code your compiler generated ($OUTPUTFILE):"
echo ""

java -jar "$MARS" "$MAINFILE" "$OUTPUTFILE"

# If you want to remove the .s file after running, uncomment below:
# rm -f "$OUTPUTFILE"




echo ""
echo "Done."
