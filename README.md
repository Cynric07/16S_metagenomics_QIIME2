---
editor_options: 
  markdown: 
    wrap: 72
---

# 16S rRNA Amplicon Metagenomics Pipeline

### BINF6310 Group Project \| QIIME2 2024.10

A complete, reproducible pipeline for 16S rRNA amplicon sequencing
analysis using QIIME2.\
34 samples across 4 conditions: **Control Start (CS)**, **Control End
(CE)**, **Treatment Start (TS)**, **Treatment End (TE)**.

------------------------------------------------------------------------

## 📁 Repository Structure

```         
16S_metagenomics_QIIME2/
│
├── README.md
├── scripts/
│   ├── download_and_qiime2_pipeline.sh   ← Download SRA data + full QIIME2 pipeline
│   ├── reformat_rdp_output.py            ← Reformat RDP taxonomy for QIIME2
│   ├── diversity_analysis.sh             ← Alpha + beta diversity analysis
│   └── taxonomy_barplots.sh              ← Taxonomy classification + bar plots
│
├── data/
│   ├── SRA_reads
|
├── qiime2_outputs/
│   ├── manifest.tsv                         ← Sample file paths (auto-generated)
│   ├── metadata.tsv                         ← Sample metadata (condition labels)
│   └── updated_metadata.tsv                 ← Grouped condition metadata
│
├── docs/
│   └── BINF6310_Group_Project_Documentation.pdf
│
└── .gitignore
```

------------------------------------------------------------------------

## 🧬 Data

Raw reads are publicly available on **NCBI SRA**:\
🔗
[SRP259666](https://trace.ncbi.nlm.nih.gov/Traces/study/?acc=SRP259666)

34 paired-end samples (SRR11671841 – SRR11671874)

> ⚠️ Raw FASTQ files are **not included** in this repo due to size.
> Script 01 will download them automatically.

------------------------------------------------------------------------

## ⚙️ Requirements

| Tool              | Version | Install                                    |
|-------------------|---------|--------------------------------------------|
| Docker            | Latest  | [docker.com](https://www.docker.com)       |
| QIIME2 (amplicon) | 2024.10 | Via Docker (see below)                     |
| sra-tools         | Latest  | `brew install sra-tools`                   |
| RDP Classifier    | 2.14    | [rdp.cme.msu.edu](https://rdp.cme.msu.edu) |
| Python            | 3.x     | Pre-installed on Mac                       |
| Java              | 8+      | `brew install openjdk`                     |

### Pull the QIIME2 Docker image (one-time setup):

``` bash
docker pull quay.io/qiime2/amplicon:2024.10
```

------------------------------------------------------------------------

## 🚀 How to Run — Step by Step

### Step 1 — Download data & run QIIME2 pipeline

``` bash
bash scripts/download_and_qiime2_pipeline.sh
```

**What it does:** - Downloads all 34 FASTQ files from NCBI SRA -
Auto-generates `manifest.tsv` - Imports reads into QIIME2 - Runs quality
visualization (`reads.qzv`) - Denoises with Deblur (trim length:
240bp) - Builds phylogenetic tree (MAFFT → FastTree → midpoint root) -
Exports rep sequences for RDP classification

**Outputs:** `reads.qza`, `reads.qzv`, `rep_seqs.qza`, `table.qza`,
`rooted_tree.qza`, `exported_rep_seqs/`

------------------------------------------------------------------------

### Step 2 — Classify taxonomy with RDP (run outside Docker)

``` bash
# Run RDP classifier
java -Xmx2g -jar rdp_classifier_2.14/dist/classifier.jar \
    -c 0.8 \
    -o ~/metagenomics_project/qiime2_outputs/taxonomy_output.txt \
    ~/metagenomics_project/qiime2_outputs/exported_rep_seqs/dna-sequences.fasta

# Reformat for QIIME2
python3 scripts/reformat_rdp_output.py \
    ~/metagenomics_project/qiime2_outputs/taxonomy_output.txt \
    ~/metagenomics_project/qiime2_outputs/reformatted_taxonomy.txt \
    0.8
```

**What it does:** - Classifies ASVs against the RDP database at 0.8
confidence threshold - Reformats the output into QIIME2-compatible
`HeaderlessTSVTaxonomyFormat`

**Outputs:** `taxonomy_output.txt`, `reformatted_taxonomy.txt`

------------------------------------------------------------------------

### Step 3 — Diversity analysis

``` bash
bash scripts/diversity_analysis.sh
```

**What it does:** - Runs core phylogenetic diversity metrics (Faith's
PD, Shannon, UniFrac, Bray-Curtis) - Tests alpha diversity group
significance by condition - Generates alpha rarefaction curves - Runs
PERMANOVA beta diversity tests (pairwise by condition)

**Outputs (in `core_metrics_results/`):** -
`faith_pd_group_significance.qzv` - `shannon_group_significance.qzv` -
`observed_features_significance.qzv` - `alpha_rarefaction.qzv` -
`unweighted_unifrac_condition_significance.qzv` -
`weighted_unifrac_condition_significance.qzv` -
`bray_curtis_condition_significance.qzv`

------------------------------------------------------------------------

### Step 4 — Taxonomy bar plots

``` bash
bash scripts/taxonomy_barplots.sh
```

**What it does:** - Imports RDP taxonomy into QIIME2 - Generates
per-sample taxa bar plots - Filters features below 1% total frequency -
Groups samples by condition (CS, CE, TS, TE) - Generates grouped taxa
bar plots

**Outputs:** `taxa_bar_plots.qzv`, `grouped_taxa_bar_plots.qzv`,
`rdp_taxonomy_summary.qzv`

------------------------------------------------------------------------

## 👁️ Visualizing Results

Upload any `.qzv` file to **QIIME2 View**:\
🔗 <https://view.qiime2.org/>

**Tips for taxa bar plots:** - Change **taxonomic level** (Level 2 =
Phylum, Level 6 = Genus) - Sort samples by **condition** column - Use
`grouped_taxa_bar_plots.qzv` for clean CS/CE/TS/TE comparisons

------------------------------------------------------------------------

## 🔬 Pipeline Overview

```         
SRA Download (sra-tools)
        ↓
QIIME2 Import (manifest.tsv)
        ↓
Quality Visualization (demux summarize)
        ↓
Denoising — Deblur (trim: 240bp)
        ↓
Phylogenetic Tree (MAFFT → FastTree → midpoint root)
        ↓
   ┌────┴────┐
   ↓         ↓
Diversity  Taxonomy
Analysis   (RDP 0.8)
   ↓         ↓
Faith's PD  Taxa Bar Plots
Shannon     (per-sample + grouped)
UniFrac
PERMANOVA
```

------------------------------------------------------------------------

## 📊 Sample Metadata

| Condition Code | Description     |
|----------------|-----------------|
| CS             | Control Start   |
| CE             | Control End     |
| TS             | Treatment Start |
| TE             | Treatment End   |

------------------------------------------------------------------------

## 📝 Notes & Limitations

-   **Deblur vs DADA2:** Deblur was used for denoising. It trims to a
    fixed length and uses the forward reads only. DADA2 with paired-end
    merging may yield longer, more accurate ASVs and is worth
    considering for future work.
-   **RDP Classifier** was run outside of Docker due to Java
    requirements. The reformatted output is then re-imported into
    QIIME2.
-   **Sampling depth** of 10,000 was chosen to retain all 34 samples.
    Verify this is appropriate by checking where diversity plateaus in
    `alpha_rarefaction.qzv`.
