#!/bin/bash
set -eu -o pipefail

res=($(xrandr | grep -w connected | grep -o '[0-9]*x[0-9]*' | sed 's/x/ /'))
width_px=${res[0]}
height_px=${res[1]}
diag_px=$(echo "sqrt($width_px^2+$height_px^2)" | bc)

size_mm=($(xrandr | grep -w connected | grep -o '[0-9]*mm x [0-9]*mm' | sed 's/ x / /'))
width_mm=$(echo ${size_mm[0]} | grep -o '[0-9]*')
height_mm=$(echo ${size_mm[1]} | grep -o '[0-9]*')
diag_mm=$(echo "scale=2;sqrt($width_mm^2+$height_mm^2)" | bc)

dpi_factor=96
if [ $width_mm -gt 0 ] && [ $height_mm -gt 0 ]; then
  mm_per_inc="0.0393701"
  dpi=$(echo "$diag_px/($diag_mm*$mm_per_inc)" | bc)
  if [ $dpi -gt $dpi_factor ]; then
    # Round to nearest multiple of $dpi_factor
    #dpi_optimal=$(echo "dpi=$dpi+($dpi_factor/2);dpi-=dpi%$dpi_factor;dpi" | bc)
    # Round down to multiple of $dpi_factor
    dpi_optimal=$(echo "$dpi-$dpi%$dpi_factor" | bc)
  else
    dpi_optimal=$dpi_factor
  fi

else
  dpi=$dpi_factor
  dpi_optimal=$dpi_factor
fi

case "$@" in
  -q)
    echo $dpi_optimal
    ;;
  *)
    printf "res(px):|%s\nsize(mm):|%s\ndiag(px):|%s\ndiag(mm):|%s\ndpi:|%s\nauto-dpi:|%d\n" \
      "${width_px}x${height_px}" \
      "${width_mm}x${height_mm}" \
      "$diag_px" \
      "$diag_mm" \
      "${dpi}" \
      "$dpi_optimal" \
      | column -t -s "|"
    ;;
esac
