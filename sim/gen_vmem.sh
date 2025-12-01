
filename=$(basename $1)
outdir=$2

temp_file=$1.data

riscv-none-elf-objcopy -O binary -j .text.init -j .tohost -j .text -j .data -j .bss $1 $temp_file
srec_cat $temp_file -binary -fill 0x00 -within $temp_file -binary -range-padding 4 -byte-swap 4 -o $outdir/$filename.vmem -vmem 32 -disable=header -obs=4

#cleanup
rm $temp_file