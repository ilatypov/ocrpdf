#! /bin/bash

set -e
density=300

function usage() {
    echo "Usage: $0 INPUT.pdf OUTPUT.pdf" >&2
    exit 1
}

if (( $# == 2 )) && ! [[ "$1" == -* ]]; then
    input="$1"
else
    usage
fi

if ! [[ -r "${input}" ]]; then
    echo "Cannot read input file ${input}." >&2
    exit 1
fi

output="$2"
if [[ -e "${output}" ]]; then
    echo "Output file ${output} already exists." >&2
    exit 1
fi

# Redact the PDF by clicking the pen icon and selecting the "ab" text icon and
# pasting the unicode full block character 0x2588.

# To flatten the redacted PDF, print it to a Postscript.  This rasterizes the
# graphics as some unfortunate side effect.

# Print the PDF to a Postscript printer such as Microsoft PS Class Driver
# attached to a FILE: port with a Print Processor set to "winprint/RAW".
# Let's say the redacted multi-page image is stored in redacted.ps.

# Split the resulting Postscript file redacted.ps into images suitable for
# tesseract-ocr (PNG) using imagemagick.

# Then OCR the PNGs to PDF pages and merge the pages using Ghostscript.

echo "Converting ${input} to raster pages ..."
rm -f output-page*.png
numpages=0
while read -r line ; do
    echo "${line}"
    if [[ "${line}" =~ ^Page\ ([0-9]+)$ ]]; then
        numpages="${BASH_REMATCH[1]}"
    fi
done < <(gs -dNOPAUSE -dBATCH -sDEVICE=png16m -sOutputFile=output-page-%03d.png \
    -r${density} -dTextAlphaBits=4 -dGraphicsAlphaBits=4 "${input}" 2>&1)

if ! (( numpages )); then
    echo "No pages found." >&2
    exit 1
fi

# echo "Identifying the number of pages ..."
# maxpage=0
# while read -r line; do
#     # echo "${line}"
#     if [[ "${line}" =~ \[([0-9]+)\] ]] ; then
#         # echo "${BASH_REMATCH[1]}"
#         maxpage="${BASH_REMATCH[1]}"
#     fi
# done < <(identify output.ps)

# echo "Splitting into rasterized pages ..."
# convert -density ${density} -units PixelsPerInch "output.ps[0-$((numpages-1))]" "output-page.png"

rm -f output-page*.pdf
for ((i=1;i<=numpages;i++)); do
    p="$(printf "%03d" $i)"
    echo "OCR of page ${p}"
    tesseract "output-page-${p}.png" "output-page-${p}" -l eng pdf
done

echo "Merging all ${numpages} OCRed PDF pages to output-flat.pdf ..."
allp=$(for ((i=1;i<=numpages;i++)); do printf "output-page-%03d.pdf\n" $i; done)
rm -f output-flat.pdf
gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite \
    -r${density} \
    -sOutputFile=output-flat.pdf ${allp}

rm -f output-page*
echo -n "Creating ${output} ..."
cp -a output-flat.pdf "${output}"
rm -f output-flat.pdf
echo " done."

