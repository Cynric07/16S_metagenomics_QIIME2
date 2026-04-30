#!/bin/bash
# =============================================================================
# download_and_qiime2_pipeline.sh
# Full QIIME2 16S rRNA Amplicon Pipeline
# Includes: SRA download, import, quality check, denoising, phylogenetic tree
#
# Requirements:
#   - sra-tools installed (brew install sra-tools)
#   - Docker installed and running
#   - QIIME2 amplicon:2024.10 Docker image pulled
#
# Usage:
#   bash download_and_qiime2_pipeline.sh
# =============================================================================

set -e  # Exit immediately if any command fails

# =============================================================================
# CONFIGURATION — Edit these paths to match your setup
# =============================================================================

PROJECT_DIR="$HOME/16S_metagenomics_QIIME2"   # Root project directory
DATA_DIR="$PROJECT_DIR/data/SRA_reads"     # Where FASTQ files will be saved
QIIME_DIR="$PROJECT_DIR/qiime2_outputs"   # Where QIIME2 outputs will be saved

# SRA Accession numbers for the 34 samples (SRP259666)
ACCESSIONS=(
    SRR11671841 SRR11671842 SRR11671843 SRR11671844
    SRR11671845 SRR11671846 SRR11671847 SRR11671848
    SRR11671849 SRR11671850 SRR11671851 SRR11671852
    SRR11671853 SRR11671854 SRR11671855 SRR11671856
    SRR11671857 SRR11671858 SRR11671859 SRR11671860
    SRR11671861 SRR11671862 SRR11671863 SRR11671864
    SRR11671865 SRR11671866 SRR11671867 SRR11671868
    SRR11671869 SRR11671870 SRR11671871 SRR11671872
    SRR11671873 SRR11671874
)

# =============================================================================
# STEP 0 — Create directory structure
# =============================================================================

echo "=========================================="
echo " Setting up project directories..."
echo "=========================================="

mkdir -p "$DATA_DIR"
mkdir -p "$QIIME_DIR"

echo "✅ Directories created."

# =============================================================================
# STEP 1 — Download SRA reads
# =============================================================================

echo ""
echo "=========================================="
echo " STEP 1: Downloading reads from SRA..."
echo "=========================================="

# Check that sra-tools is installed
if ! command -v fastq-dump &> /dev/null; then
    echo "❌ ERROR: sra-tools is not installed."
    echo "   Install it with: brew install sra-tools"
    exit 1
fi

for ACC in "${ACCESSIONS[@]}"; do
    if [ -f "$DATA_DIR/${ACC}_1.fastq" ] && [ -f "$DATA_DIR/${ACC}_2.fastq" ]; then
        echo "  ⏩ Skipping $ACC (already downloaded)"
    else
        echo "  ⬇️  Downloading $ACC..."
        fastq-dump --split-files --outdir "$DATA_DIR" "$ACC"
        echo "  ✅ Done: $ACC"
    fi
done

echo "✅ All reads downloaded to: $DATA_DIR"

# =============================================================================
# STEP 2 — Generate manifest.tsv automatically
# =============================================================================

echo ""
echo "=========================================="
echo " STEP 2: Generating manifest.tsv..."
echo "=========================================="

MANIFEST="$QIIME_DIR/manifest.tsv"

# Write header
echo -e "sample-id\tforward-absolute-filepath\treverse-absolute-filepath" > "$MANIFEST"

# Write one row per sample
SAMPLE_NUM=1
for ACC in "${ACCESSIONS[@]}"; do
    echo -e "sample${SAMPLE_NUM}\t/data/${ACC}_1.fastq\t/data/${ACC}_2.fastq" >> "$MANIFEST"
    SAMPLE_NUM=$((SAMPLE_NUM + 1))
done

echo "✅ manifest.tsv created at: $MANIFEST"

# =============================================================================
# STEP 3 — Create metadata.tsv
# =============================================================================

echo ""
echo "=========================================="
echo " STEP 3: Creating metadata.tsv..."
echo "=========================================="

METADATA="$QIIME_DIR/metadata.tsv"

cat > "$METADATA" << 'META'
sample-id	condition	sample-number
#q2:types	categorical	numeric
sample1	Control_Start	5
sample2	Treatment_Start	5
sample3	Treatment_Start	4
sample4	Treatment_Start	3
sample5	Control_Start	4
sample6	Control_Start	3
sample7	Control_End	8
sample8	Control_End	7
sample9	Control_End	6
sample10	Treatment_End	9
sample11	Treatment_Start	2
sample12	Treatment_End	8
sample13	Treatment_End	7
sample14	Control_End	5
sample15	Treatment_End	6
sample16	Treatment_End	5
sample17	Treatment_End	4
sample18	Treatment_End	3
sample19	Control_End	4
sample20	Control_End	3
sample21	Control_End	2
sample22	Control_Start	2
sample23	Treatment_End	2
sample24	Treatment_End	1
sample25	Control_End	1
sample26	Control_Start	8
sample27	Control_Start	7
sample28	Control_Start	6
sample29	Treatment_Start	9
sample30	Treatment_Start	8
sample31	Treatment_Start	7
sample32	Treatment_Start	6
sample33	Treatment_Start	1
sample34	Control_Start	1
META

echo "✅ metadata.tsv created at: $METADATA"

# =============================================================================
# STEP 3 — Pre-flight checks
# =============================================================================

echo ""
echo "=========================================="
echo " STEP 3: Running pre-flight checks..."
echo "=========================================="

if ! docker info > /dev/null 2>&1; then
    echo "❌ ERROR: Docker is not running."
    exit 1
fi

FASTQ_COUNT=$(ls "$DATA_DIR"/*.fastq 2>/dev/null | wc -l)
if [ "$FASTQ_COUNT" -eq 0 ]; then
    echo "❌ ERROR: No .fastq files found in $DATA_DIR"
    exit 1
fi

echo "✅ Found $FASTQ_COUNT FASTQ files."
echo "✅ Docker is running."

# =============================================================================
# STEP 4 — Run QIIME2 pipeline inside Docker
# =============================================================================

echo ""
echo "=========================================="
echo " STEP 4: Running QIIME2 pipeline in Docker..."
echo "=========================================="

docker run --rm --platform linux/amd64 \
    -v "$DATA_DIR":/data \
    -v "$QIIME_DIR":/qiime2 \
    quay.io/qiime2/amplicon:2024.10 \
    /bin/bash -c "
set -e
cd /qiime2

echo ''
echo '--- [1/6] Importing reads ---'
qiime tools import \
    --input-path manifest.tsv \
    --output-path reads.qza \
    --type 'SampleData[PairedEndSequencesWithQuality]' \
    --input-format PairedEndFastqManifestPhred33V2

echo '✅ Import done.'

echo ''
echo '--- [2/6] Summarizing reads (quality check) ---'
qiime demux summarize \
    --i-data reads.qza \
    --o-visualization reads.qzv

echo '✅ Quality summary done → reads.qzv'

echo ''
echo '--- [3/6] Denoising with Deblur (trim at 240bp) ---'
qiime deblur denoise-16S \
    --i-demultiplexed-seqs reads.qza \
    --p-trim-length 240 \
    --p-sample-stats \
    --o-representative-sequences rep_seqs.qza \
    --o-table table.qza \
    --o-stats deblur_stats.qza

qiime deblur visualize-stats \
    --i-deblur-stats deblur_stats.qza \
    --o-visualization deblur_stats.qzv

echo '✅ Denoising done → rep_seqs.qza, table.qza, deblur_stats.qzv'

echo ''
echo '--- [4/6] Building phylogenetic tree ---'
qiime alignment mafft \
    --i-sequences rep_seqs.qza \
    --o-alignment aligned_rep_seqs.qza

qiime alignment mask \
    --i-alignment aligned_rep_seqs.qza \
    --o-masked-alignment masked_aligned_rep_seqs.qza

qiime phylogeny fasttree \
    --i-alignment masked_aligned_rep_seqs.qza \
    --o-tree unrooted_tree.qza

qiime phylogeny midpoint-root \
    --i-tree unrooted_tree.qza \
    --o-rooted-tree rooted_tree.qza

echo '✅ Phylogenetic tree done → rooted_tree.qza'

echo ''
echo '--- [5/6] Summarizing feature table ---'
qiime feature-table summarize \
    --i-table table.qza \
    --o-visualization table_summary.qzv \
    --m-sample-metadata-file metadata.tsv

echo '✅ Feature table summary done → table_summary.qzv'

echo ''
echo '--- [6/6] Exporting representative sequences ---'
qiime tools export \
    --input-path rep_seqs.qza \
    --output-path exported_rep_seqs

echo '✅ Rep seqs exported → exported_rep_seqs/dna-sequences.fasta'

echo ''
echo '=========================================='
echo ' QIIME2 pipeline complete!'
echo '=========================================='
"

echo ""
echo "✅ All done! Outputs saved to: $QIIME_DIR"