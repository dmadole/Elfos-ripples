
all: ripples.asm
	asm02 -L -b ripples.asm
	@rm ripples.build

clean:
	@rm -f mbios.bin mbios.lst

