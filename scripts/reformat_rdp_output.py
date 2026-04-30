#!/usr/bin/env python3
"""
reformat_rdp_output.py
Reformats RDP Classifier output into QIIME2-compatible taxonomy format.

The RDP classifier outputs a tab-separated file where each line contains:
  - sequence ID
  - taxonomy hierarchy with confidence scores

This script:
  1. Parses each line of the RDP output
  2. Extracts the taxonomic ranks: domain, phylum, class, order, family, genus
  3. Filters by confidence threshold (default: 0.8)
  4. Outputs a QIIME2-compatible HeaderlessTSVTaxonomyFormat file

Usage:
    python3 reformat_rdp_output.py <rdp_output.txt> <reformatted_taxonomy.txt> [confidence_threshold]

Example:
    python3 reformat_rdp_output.py taxonomy_output.txt reformatted_taxonomy.txt 0.8

Requirements:
    - Python 3 (no extra packages needed)

How to run the RDP classifier first (outside Docker):
    java -Xmx2g -jar rdp_classifier_2.14/dist/classifier.jar \
        -c 0.8 \
        -o taxonomy_output.txt \
        exported_rep_seqs/dna-sequences.fasta
"""

import sys
import os

# =============================================================================
# CONFIGURATION
# =============================================================================

# Taxonomic ranks to extract (in order)
RANKS = ["domain", "phylum", "class", "order", "family", "genus"]

# QIIME2 prefix map for each rank
RANK_PREFIXES = {
    "domain":  "d__",
    "phylum":  "p__",
    "class":   "c__",
    "order":   "o__",
    "family":  "f__",
    "genus":   "g__"
}

# =============================================================================
# FUNCTIONS
# =============================================================================

def parse_rdp_line(line, confidence_threshold=0.8):
    """
    Parse a single line from RDP classifier output.

    RDP output format per line:
    seqID \t seqID \t orientation \t domain \t domain \t rank \t confidence \t ...

    Returns:
        (seq_id, taxonomy_string) or None if parsing fails
    """
    parts = line.strip().split("\t")

    if len(parts) < 4:
        return None

    seq_id = parts[0].strip()
    taxonomy_parts = []

    # RDP output has groups of 3 fields after the first 3 columns:
    # [taxon_name, taxon_rank, confidence]
    i = 3
    rank_values = {}

    while i + 2 < len(parts):
        taxon_name = parts[i].strip()
        taxon_rank = parts[i + 1].strip().lower()
        try:
            confidence = float(parts[i + 2].strip())
        except ValueError:
            i += 3
            continue

        if taxon_rank in RANKS:
            if confidence >= confidence_threshold:
                rank_values[taxon_rank] = taxon_name
            else:
                # Below confidence threshold — use "unclassified"
                rank_values[taxon_rank] = "unclassified"

        i += 3

    # Build QIIME2 taxonomy string
    taxonomy_list = []
    for rank in RANKS:
        if rank in rank_values:
            name = rank_values[rank]
            prefix = RANK_PREFIXES[rank]
            taxonomy_list.append(f"{prefix}{name}")
        else:
            prefix = RANK_PREFIXES[rank]
            taxonomy_list.append(f"{prefix}unclassified")

    taxonomy_string = "; ".join(taxonomy_list)
    return seq_id, taxonomy_string


def reformat_rdp_output(input_file, output_file, confidence_threshold=0.8):
    """
    Main function: reads RDP output, reformats, and writes QIIME2 taxonomy file.
    """

    if not os.path.exists(input_file):
        print(f"❌ ERROR: Input file not found: {input_file}")
        sys.exit(1)

    print(f"📂 Reading RDP output from: {input_file}")
    print(f"🎯 Confidence threshold: {confidence_threshold}")

    success_count = 0
    fail_count = 0

    with open(input_file, "r") as infile, open(output_file, "w") as outfile:

        # Write QIIME2 header
        outfile.write("Feature ID\tTaxon\n")

        for line_num, line in enumerate(infile, start=1):
            line = line.strip()

            # Skip empty lines or comment lines
            if not line or line.startswith("#"):
                continue

            result = parse_rdp_line(line, confidence_threshold)

            if result is None:
                print(f"  ⚠️  Warning: Could not parse line {line_num}, skipping.")
                fail_count += 1
                continue

            seq_id, taxonomy_string = result
            outfile.write(f"{seq_id}\t{taxonomy_string}\n")
            success_count += 1

    print(f"\n✅ Done! Reformatted taxonomy written to: {output_file}")
    print(f"   Sequences processed:  {success_count}")
    if fail_count > 0:
        print(f"   Lines skipped:        {fail_count}")
    print(f"\n📌 Next step — import into QIIME2:")
    print(f"   qiime tools import \\")
    print(f"       --type 'FeatureData[Taxonomy]' \\")
    print(f"       --input-path {output_file} \\")
    print(f"       --output-path rdp_taxonomy.qza \\")
    print(f"       --input-format HeaderlessTSVTaxonomyFormat")


# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":

    if len(sys.argv) < 3:
        print(__doc__)
        print("❌ ERROR: Not enough arguments.")
        print("Usage: python3 reformat_rdp_output.py <input.txt> <output.txt> [confidence]")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    confidence = float(sys.argv[3]) if len(sys.argv) > 3 else 0.8

    reformat_rdp_output(input_path, output_path, confidence)
