#!/usr/bin/env bash
set -euo pipefail

pack_row() {
    local row="$1"
    local lo=0
    local hi=0
    for i in {0..7}; do
        v=${row:$i:1}
        b0=$((v & 1))
        b1=$(( (v >> 1) & 1 ))
        lo=$(( lo | (b0 << (7-i)) ))
        hi=$(( hi | (b1 << (7-i)) ))
    done
    printf "%02x %02x\n" "$lo" "$hi"
}

input_file="$1"
basename=$(basename "$input_file")
pic_name="TDATA_${basename%.*}"

while IFS= read -r line; do
    digits=$(printf "%s" "$line")
    pack_row "$digits"
done < "$input_file" | xxd -r -p | xxd -i -n "$pic_name" -C
