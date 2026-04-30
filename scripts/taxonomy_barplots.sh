#!/bin/bash
# =============================================================================
# taxonomy_barplots.sh
# QIIME2 Taxonomy Classification & Bar Plot Pipeline
# Imports RDP taxonomy, generates individual and grouped taxa bar plots
#
# Requirements:
#   - Docker installed and running
#   - QIIME2 amplicon:2024.10 Docker image
#   - reformatted_taxonomy.txt (from 02_reformat_rdp_output.py)
#   - table.qza and metadata.tsv (from 01_download_and_qiime2_pipeline.sh)
#
# Usage:
#   bash taxonomy_barplots.sh
# =============================================================================

set -e

# =============================================================================
# CONFIGURATION — Edit these to match your setup
# =============================================================================

PROJECT_DIR="$HOME/16S_metagenomics_QIIME2"
QIIME_DIR="$PROJECT_DIR/qiime2_outputs"

# Minimum frequency filter (1% of total frequency)
# From your data: total frequency ~1,122,400 → 1% = ~11,224
# This value will be auto-calculated from table_summary if possible,
# otherwise the default below is used
MIN_FREQUENCY=11224

# =============================================================================
# PRE-FLIGHT CHECK
# =============================================================================

echo "=========================================="
echo " Pre-flight check..."
echo "=========================================="

for FILE in \
    "$QIIME_DIR/reformatted_taxonomy.txt" \
    "$QIIME_DIR/table.qza" \
    "$QIIME_DIR/metadata.tsv"; do
    if [ ! -f "$FILE" ]; then
        echo "❌ ERROR: Required file not found: $FILE"
        echo ""
        echo "   Checklist:"
        echo "   - reformatted_taxonomy.txt → run reformat_rdp_output.py first"
        echo "   - table.qza               → run download_and_qiime2_pipeline.sh first"
        echo "   - metadata.tsv            → should be in your qiime2_outputs folder"
        exit 1
    fi
done

echo "✅ All required files found."

# =============================================================================
# CREATE updated_metadata.tsv (grouped conditions)
# =============================================================================

echo ""
echo "=========================================="
echo " Creating updated_metadata.tsv..."
echo "=========================================="

cat > "$QIIME_DIR/updated_metadata.tsv" << 'METADATA'
sample-id	condition
#q2:types	categorical
Control_End	CE
Control_Start	CS
Treatment_End	TE
Treatment_Start	TS
METADATA

echo "✅ updated_metadata.tsv created."

# =============================================================================
# RUN TAXONOMY PIPELINE INSIDE DOCKER
# =============================================================================

docker run --rm --platform linux/amd64 \
    -v "$QIIME_DIR":/qiime2 \
    quay.io/qiime2/amplicon:2024.10 \
    /bin/bash -c "
set -e
cd /qiime2

rm -f rdp_taxonomy.qza taxa_bar_plots.qzv filtered_table.qza grouped_table.qza grouped_taxa_bar_plots.qzv
rm -rf exported_taxonomy

echo ''
echo '=========================================='
echo ' STEP 1: Import RDP taxonomy into QIIME2'
echo '=========================================='

qiime tools import \
    --type 'FeatureData[Taxonomy]' \
    --input-path reformatted_taxonomy.txt \
    --output-path rdp_taxonomy.qza \
    --input-format HeaderlessTSVTaxonomyFormat

echo '✅ Taxonomy imported → rdp_taxonomy.qza'

echo ''
echo '=========================================='
echo ' STEP 2: Taxonomy bar plots (per sample)'
echo '=========================================='

qiime taxa barplot \
    --i-table table.qza \
    --i-taxonomy rdp_taxonomy.qza \
    --m-metadata-file metadata.tsv \
    --o-visualization taxa_bar_plots.qzv

echo '✅ Per-sample bar plots → taxa_bar_plots.qzv'

echo ''
echo '=========================================='
echo ' STEP 3: Filter table to 1%+ frequency features'
echo '=========================================='

qiime feature-table filter-features \
    --i-table table.qza \
    --p-min-frequency $MIN_FREQUENCY \
    --o-filtered-table filtered_table.qza

echo '✅ Filtered table → filtered_table.qza'
echo '   (Removed features with < $MIN_FREQUENCY total reads across all samples)'

echo ''
echo '=========================================='
echo ' STEP 4: Group samples by condition'
echo '=========================================='

qiime feature-table group \
    --i-table filtered_table.qza \
    --p-axis sample \
    --m-metadata-file metadata.tsv \
    --m-metadata-column condition \
    --p-mode sum \
    --o-grouped-table grouped_table.qza

echo '✅ Grouped table → grouped_table.qza'
echo '   (Samples merged by: CS, CE, TS, TE)'

echo ''
echo '=========================================='
echo ' STEP 5: Grouped taxa bar plots'
echo '=========================================='

qiime taxa barplot \
    --i-table grouped_table.qza \
    --i-taxonomy rdp_taxonomy.qza \
    --m-metadata-file updated_metadata.tsv \
    --o-visualization grouped_taxa_bar_plots.qzv

echo '✅ Grouped bar plots → grouped_taxa_bar_plots.qzv'

echo ''
echo '=========================================='
echo ' STEP 6: Export taxonomy table'
echo '=========================================='

qiime tools export \
    --input-path rdp_taxonomy.qza \
    --output-path exported_taxonomy

echo '✅ Taxonomy exported → exported_taxonomy/taxonomy.tsv'

echo ''
echo '=========================================='
echo ' All taxonomy steps complete!'
echo '=========================================='
"