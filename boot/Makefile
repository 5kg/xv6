include ../Makefile.inc

CFLAGS += -I../include

boot.img: bootblock
	# 8M disk image
	dd if=/dev/zero of=boot.img count=16384 bs=512
	dd if=bootblock of=boot.img conv=notrunc

bootblock: bootasm.S bootmain.c
	$(CC) $(CFLAGS) -fno-pic -O -nostdinc -c bootmain.c
	$(CC) $(CFLAGS) -fno-pic -nostdinc -c bootasm.S
	$(LD) $(LDFLAGS) -N -e start -Ttext 0x7C00 -o bootblock.o bootasm.o bootmain.o
	$(OBJCOPY) -S -O binary -j .text bootblock.o bootblock
	../scripts/sign.pl bootblock

bochs: boot.img
	if [ ! -e .bochsrc ]; then ln -s ../extra/dot-bochsrc-boot .bochsrc; fi
	bochs -q

clean: 
	rm -f *.o *.d bootblock bochs.log

.PHONY: clean bochs
