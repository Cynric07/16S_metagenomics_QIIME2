#!/bin/bash
# =============================================================================
# diversity_analysis.sh
# QIIME2 Diversity Analysis Pipeline
# Runs alpha diversity, beta diversity, and rarefaction analysis
#
# Requirements:
#   - Docker installed and running
#   - QIIME2 amplicon:2024.10 Docker image
#   - Outputs from download_and_qiime2_pipeline.sh must exist
#     (rooted_tree.qza, table.qza, metadata.tsv)
#
# Usage:
#   bash diversity_analysis.sh
# =============================================================================

set -e

# =============================================================================
# CONFIGURATION — Edit these to match your setup
# =============================================================================

PROJECT_DIR="$HOME/16S_metagenomics_QIIME2"
QIIME_DIR="$PROJECT_DIR/qiime2_outputs"

# Sampling depth — based on your data's minimum read count per sample.
# From your quality report, minimum was ~42,975. We use 10,000 to retain
# all samples while still capturing diversity. Adjust if needed.
SAMPLING_DEPTH=10000

# Max depth for rarefaction curve
MAX_RAREFACTION_DEPTH=10000

# =============================================================================
# PRE-FLIGHT CHECK
# =============================================================================

echo "=========================================="
echo " Pre-flight check..."
echo "=========================================="

for FILE in "$QIIME_DIR/rooted_tree.qza" "$QIIME_DIR/table.qza" "$QIIME_DIR/metadata.tsv"; do
    if [ ! -f "$FILE" ]; then
        echo "❌ ERROR: Required file not found: $FILE"
        echo "   Make sure you ran download_and_qiime2_pipeline.sh first."
        exit 1
    fi
done

echo "✅ All required files found. Starting diversity analysis..."

# =============================================================================
# RUN DIVERSITY ANALYSIS INSIDE DOCKER
# =============================================================================

docker run --rm --platform linux/amd64 \
    -v "$QIIME_DIR":/qiime2 \
    quay.io/qiime2/amplicon:2024.10 \
    /bin/bash -c "
set -e
cd /qiime2

# Create output subdirectory for diversity results
rm -rf core_metrics_results

echo ''
echo '=========================================='
echo ' STEP 1: Core phylogenetic diversity metrics'
echo '=========================================='
echo '  Sampling depth: $SAMPLING_DEPTH'

qiime diversity core-metrics-phylogenetic \
    --i-phylogeny rooted_tree.qza \
    --i-table table.qza \
    --p-sampling-depth $SAMPLING_DEPTH \
    --m-metadata-file metadata.tsv \
    --output-dir core_metrics_results

echo '✅ Core metrics done → core_metrics_results/'
echo '   Outputs include:'
echo '   - faith_pd_vector.qza     (alpha: phylogenetic diversity)'
echo '   - evenness_vector.qza     (alpha: Pielou''s evenness)'
echo '   - observed_features_vector.qza (alpha: observed ASVs)'
echo '   - shannon_vector.qza      (alpha: Shannon entropy)'
echo '   - unweighted_unifrac_distance_matrix.qza (beta)'
echo '   - weighted_unifrac_distance_matrix.qza   (beta)'
echo '   - bray_curtis_distance_matrix.qza        (beta)'

echo ''
echo '=========================================='
echo ' STEP 2: Alpha diversity — Faith''s PD'
echo '=========================================='

qiime diversity alpha-group-significance \
    --i-alpha-diversity core_metrics_results/faith_pd_vector.qza \
    --m-metadata-file metadata.tsv \
    --o-visualization core_metrics_results/faith_pd_group_significance.qzv

echo '✅ Faith''s PD significance → faith_pd_group_significance.qzv'

echo ''
echo '=========================================='
echo ' STEP 3: Alpha diversity — Shannon entropy'
echo '=========================================='

qiime diversity alpha-group-significance \
    --i-alpha-diversity core_metrics_results/shannon_vector.qza \
    --m-metadata-file metadata.tsv \
    --o-visualization core_metrics_results/shannon_group_significance.qzv

echo '✅ Shannon significance → shannon_group_significance.qzv'

echo ''
echo '=========================================='
echo ' STEP 4: Alpha diversity — Observed features'
echo '=========================================='

qiime diversity alpha-group-significance \
    --i-alpha-diversity core_metrics_results/observed_features_vector.qza \
    --m-metadata-file metadata.tsv \
    --o-visualization core_metrics_results/observed_features_significance.qzv

echo '✅ Observed features significance → observed_features_significance.qzv'

echo ''
echo '=========================================='
echo ' STEP 5: Alpha rarefaction curve'
echo '=========================================='

qiime diversity alpha-rarefaction \
    --i-table core_metrics_results/rarefied_table.qza \
    --p-max-depth $MAX_RAREFACTION_DEPTH \
    --m-metadata-file metadata.tsv \
    --p-steps 25 \
    --o-visualization alpha_rarefaction.qzv

echo '✅ Alpha rarefaction → alpha_rarefaction.qzv'

echo ''
echo '=========================================='
echo ' STEP 6: Beta diversity — PERMANOVA tests'
echo '=========================================='

qiime diversity beta-group-significance \
    --i-distance-matrix core_metrics_results/unweighted_unifrac_distance_matrix.qza \
    --m-metadata-file metadata.tsv \
    --m-metadata-column condition \
    --o-visualization core_metrics_results/unweighted_unifrac_condition_significance.qzv \
    --p-pairwise

echo '✅ Unweighted UniFrac PERMANOVA → unweighted_unifrac_condition_significance.qzv'

qiime diversity beta-group-significance \
    --i-distance-matrix core_metrics_results/weighted_unifrac_distance_matrix.qza \
    --m-metadata-file metadata.tsv \
    --m-metadata-column condition \
    --o-visualization core_metrics_results/weighted_unifrac_condition_significance.qzv \
    --p-pairwise

echo '✅ Weighted UniFrac PERMANOVA → weighted_unifrac_condition_significance.qzv'

qiime diversity beta-group-significance \
    --i-distance-matrix core_metrics_results/bray_curtis_distance_matrix.qza \
    --m-metadata-file metadata.tsv \
    --m-metadata-column condition \
    --o-visualization core_metrics_results/bray_curtis_condition_significance.qzv \
    --p-pairwise

echo '✅ Bray-Curtis PERMANOVA → bray_curtis_condition_significance.qzv'

echo ''
echo '=========================================='
echo ' All diversity analyses complete!'
echo '=========================================='
echo ''
echo ' Summary of outputs in core_metrics_results/:'
echo '   ✅ faith_pd_group_significance.qzv'
echo '   ✅ shannon_group_significance.qzv'
echo '   ✅ observed_features_significance.qzv'
echo '   ✅ alpha_rarefaction.qzv'
echo '   ✅ unweighted_unifrac_condition_significance.qzv'
echo '   ✅ weighted_unifrac_condition_significance.qzv'
echo '   ✅ bray_curtis_condition_significance.qzv'
"

echo ''
echo '✅ Diversity analysis complete!'
echo '   Next: Run taxonomy_barplots.sh'