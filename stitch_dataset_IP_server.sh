#!/bin/bash
set -euo pipefail

# =============================================================================
# BigStitcher-Spark Pipeline with Interest Point Refinement
# Optimized for NETWORK STORAGE (1 Gbps connection)
#
# Uses _spark_optimized_server wrappers with:
#   - 85g heap + 15g off-heap for I/O steps (maximizes network caching)
#   - local[8] for I/O steps (fills 1 Gbps pipe with TCP stream aggregation)
#   - 256x256x128 blocks (16 MB each, amortizes network latency)
#
# Run bandwidth_test.sh first to verify your actual network throughput.
#
# Usage: ./stitch_dataset_IP_server.sh /path/to/file.czi xml_name
# =============================================================================

# --- CONFIGURATION ---
BIGSTITCHER_DIR="/~/BigStitcher-Spark/BigStitcher-Spark_Keck_optimized"
FIJI_BIN="/~/BigStitcher-Spark/FIJI/Fiji.app/ImageJ-linux64"
MACRO_PATH="/~/load_dataset.ijm"


RUN_IP_REGISTRATION=false
# Interest point detection parameters (tune these for your data)
IP_LABEL="beads"
IP_SIGMA=1.5
IP_THRESHOLD=0.03
IP_MIN_INTENSITY=0
IP_MAX_INTENSITY=4096
IP_DOWNSAMPLE_XY=2
IP_DOWNSAMPLE_Z=1
IP_MAX_SPOTS=10000

# Block parameters (optimized for 1 Gbps network + 2:1 XY:Z anisotropy)
# 256x256x128 = 16 MB/block: large enough to amortize network latency
RESAVE_BLOCK_SIZE="256,256,128"
RESAVE_BLOCK_SCALE="2,2,1"
FUSION_BLOCK_SIZE="256,256,128"
FUSION_BLOCK_SCALE="2,2,1"

# --- INPUT ---
if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
    echo "Usage: $0 [path_to_dataset_folder] [xml_filename_without_extension]"
    exit 1
fi

CZI_FILE=$1
XML_NAME=$2

DATASET_PATH=$(dirname "$CZI_FILE")
XML_PATH="${DATASET_PATH}/${XML_NAME}.xml"
OUTPUT_ZARR="${DATASET_PATH}/${XML_NAME}_fused.N5"

echo "------------------------------------------------"
echo "STEP 1: Defining Dataset via ImageJ Macro..."
echo "------------------------------------------------"

# Run Fiji headless
$FIJI_BIN --headless --console -macro "$MACRO_PATH" "$CZI_FILE $XML_NAME"

echo "==========================================="
echo " BigStitcher Pipeline (Server): $XML_PATH"
echo "==========================================="

# Step 1: Resave to N5
echo ""
echo "[$(date +%H:%M:%S)] Step 1/8: Resaving to N5..."
"$BIGSTITCHER_DIR"/resave_spark_optimized_server \
    -x "$XML_PATH" -xo "$XML_PATH" \
    --blockSize="${RESAVE_BLOCK_SIZE}" --blockScale="${RESAVE_BLOCK_SCALE}" --N5

# Step 2: Pairwise stitching (phase correlation, translation only)
echo ""
echo "[$(date +%H:%M:%S)] Step 2/8: Pairwise stitching..."
"$BIGSTITCHER_DIR"/stitching_spark_optimized_server -x "$XML_PATH"

# Step 3: Solve (translation only, from stitching)
echo ""
echo "[$(date +%H:%M:%S)] Step 3/8: Solving (translation from stitching)..."
"$BIGSTITCHER_DIR"/solver_spark_optimized_server -x "$XML_PATH" -s STITCHING

if $RUN_IP_REGISTRATION; then
	# Step 4: Detect interest points in overlap regions
	echo ""
	echo "[$(date +%H:%M:%S)] Step 4/8: Detecting interest points..."
	"$BIGSTITCHER_DIR"/detect-interestpoints_spark_optimized_server \
		-x "$XML_PATH" \
		-l "$IP_LABEL" \
		-s "$IP_SIGMA" \
		-t "$IP_THRESHOLD" \
		--minIntensity "$IP_MIN_INTENSITY" \
		--maxIntensity "$IP_MAX_INTENSITY" \
		--downsampleXY "$IP_DOWNSAMPLE_XY" \
		--downsampleZ "$IP_DOWNSAMPLE_Z" \
		--overlappingOnly \
		--maxSpots "$IP_MAX_SPOTS"

	# Step 5: Match interest points (with rotation correction)
	echo ""
	echo "[$(date +%H:%M:%S)] Step 5/8: Matching interest points (FAST_ROTATION)..."
	"$BIGSTITCHER_DIR"/match-interestpoints_spark_optimized_server \
		-x "$XML_PATH" \
		-l "$IP_LABEL" \
		-m FAST_ROTATION \
		--clearCorrespondences

	# Step 6: Solve (IP-based, corrects small rotations)
	echo ""
	echo "[$(date +%H:%M:%S)] Step 6/8: Solving (IP-based rotation refinement)..."
	"$BIGSTITCHER_DIR"/solver_spark_optimized_server \
		-x "$XML_PATH" \
		-s IP \
		-l "$IP_LABEL" \
		--method TWO_ROUND_ITERATIVE
fi
# Step 7: Create fusion container
echo ""
echo "[$(date +%H:%M:%S)] Step 7/8: Creating fusion container..."
"$BIGSTITCHER_DIR"/create-fusion-container_spark_optimized_server \
    -x "$XML_PATH" \
    -o "$OUTPUT_ZARR" \
    --preserveAnisotropy --multiRes -d UINT16 \
    --bdv -xo "${DATASET_PATH}/${XML_NAME}_fused.xml" -s N5 \
    --blockSize "${FUSION_BLOCK_SIZE}"

# Step 8: Affine fusion
echo ""
echo "[$(date +%H:%M:%S)] Step 8/8: Affine fusion..."
"$BIGSTITCHER_DIR"/affine-fusion_spark_optimized_server \
    -o "$OUTPUT_ZARR" \
    --blockScale "${FUSION_BLOCK_SCALE}"

echo ""
echo "[$(date +%H:%M:%S)] ==========================================="
echo " Pipeline Complete!"
echo "Total execution time: $SECONDS seconds"
echo "==========================================="
