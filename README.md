# Elfos-ripples

This is a demo for 1861 PIXIE video to run under Elf/OS, displaying zooming concentric circles in 64x32 resolution.

I wrote this to see if it was possible to get reasonable speed on the 1802 and 1861 for a graphic effect like this. Each frame is drawn on-the-fly. Besides code optimization, the only trickery that is used is a PIXIE interrupt service routine that mirrors the display vertically so that only half the pixels need to be drawn. There is a compiled-in table of squares of the first 32 integers but everything else is calculated in real time.

This should run on most PIXIE machines, it uses INP 1 to enable video and both OUT 1 and INP 2 to disable it. This should work on VIP-like machines and Super-Elf like machines.

