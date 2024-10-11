
;  Copyright 2024, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


            #include include/bios.inc
            #include include/kernel.inc

          ; Executable program header

            org   2000h-6
            dw    start
            dw    end-start
            dw    start

start:      br    entry


          ; Build information

            db    10+80h                ; month
            db    10                    ; day
            dw    2024                  ; year
            dw    1                     ; build

            db    'See github.com/dmadole/Elfos-ripples for more info',0


          ; Blank a display buffer to initially display so that there isn't
          ; garbage on-screen before the first drawn frame is ready.

entry:      ldi   127+display.0         ; initialize to end of second page
            plo   r0
            ldi   1+display.1
            phi   r0

            phi   rf                    ; displyay the second page first

            sex   r0                    ; make this barely faster

blank:      ldi   0                     ; fill downward with zeroes
            stxd
            glo   r0
            bnz   blank

            str   r0                    ; and the last byte also


          ; Set interrupt pointer to the service routing and make sure that
          ; interrupts are enabled on the processor.

            ldi   intserv.1             ; set interrupt service routine
            phi   r1
            ldi   intserv.0
            plo   r1

            sex   r3                    ; enable interrupts
            ret
            db    23h


          ; When the 1861 is enabled, DMA could start happening right away,
          ; even before the first interrupt to set it up properly. To avoid
          ; having this flash garbage on the screen, we'll continuously reset
          ; the DMA pointer long enough to cover an entire frame if needed.

            ldi   64                    ; 128 lines unrolled twice
            plo   r7

            inp   1                     ; enable 1861 video output

loop:       ldi   display.0             ; reset r0 and count down
            plo   r0
            dec   r7

            plo   r0                    ; reset r0 and loop until done
            glo   r7
            bnz   loop


          ; Initialze table and display pointer MSBs that will not change.

            ldi   squares.1
            phi   ra
            phi   rb

            ldi   display.1
            phi   rc
            phi   rd


          ; Initialize registers for the start of each frame of display.

restart:    ldi   128-4                 ; address of middle of screen
            plo   rc
            plo   rd

            ldi   squares.0             ; get pointer to table for lines
            plo   rb

            ldi   16                    ; set number of lines to draw
            phi   r7


          ; Initialized registers for the start of each line of display.

nextrow:    ldi   squares.0             ; get pointer to table for pixels
            plo   ra

            ldi   4                     ; number of bytes of pixels to draw
            plo   r7


          ; Get Y^2+T portion of the value once per line since it doesn't
          ; change. T is the top of the stack and then we push Y^2+T on
          ; top of that so that R2 points to it for arithmetic.

            lda   rb                    ; get square of y and double it
            shl

            add                         ; add time t from stack and push
            dec   r2
            str   r2


          ; Draw a row of 64 pixels as 8 bits in 8 bytes. We use the left-side
          ; byte to count the bit loops by presetting a stop bit in it.

setmask:    dec   rc                    ; pre-decrement left pointer

            ldi   128                   ; set stop bit into left-side byte
            str   rc


          ; For each byte, we calculate mirror-image values for each side of
          ; the screen by shifting in opposite directions. These are stored
          ; directly in the buffer since we are composing off-screen.

nextpix:    lda   ra                    ; get square of x and add to y+t
            add

            adi   96                    ; white pixel for values over 160

            ldn   rd                    ; shift pixel into right-side byte
            shlc
            str   rd

            shrc                        ; shift same into left-side byte
            ldn   rc
            shrc
            str   rc

            bnf   nextpix               ; repeat until stop bit emerges

            inc   rd                    ; increment right pointer

            dec   r7                    ; repeat until four bytes drawn
            glo   r7
            bnz   setmask


          ; At the end of each line, start the setup for the next line and
          ; then loop back if not done with the whole frame.

            inc   r2                    ; discard y+t value for this line

            glo   rc                    ; move pointers to previous row
            smi   4
            plo   rc
            plo   rd
 
            dec   r7                    ; repeat until 32 lines drawn
            ghi   r7
            bnz   nextrow
   

          ; A whole frame is complete now. Increment the time and swap the
          ; pages being displayed and drawn into.

            ldn   r2                    ; update time t value on stack
            smi   13
            str   r2

            ghi   rc                    ; change display to just-drawn page
            phi   rf

            sdi   1+2*display.1         ; swap page we are drawing into
            phi   rc
            phi   rd


          ; Loop until INPUT button is pressed, then disable video and exit.

            bn4   restart               ; repeat until input switch pressed

            dec   r2                    ; disable video on vip-type machine
            out   1

            inp   2                     ; dispable on super elf-type machine

            sep   sret                  ; exit program


          ; The 1861 interrupt service routine is unique in that only the top
          ; half of the display is mapped to memory, and the bottom is merely
          ; displayed as a mirror image of the top half by displaying the same
          ; lines again, just backwards. This increases the speed slightly
          ; since only half the display needs to actually be drawn.

intmain:    dec   r2                    ; preserve x, p register designations
            sav

            dec   r2                    ; preserve d register content
            str   r2

            dec   r2                    ; preserve df flag by shifting to d
            shlc
            str   r2

            ghi   rf                    ; start address of current page
            phi   r0
            ldi   display.0
            plo   r0


          ; Display top half of the screen fairly conventionally, repeating
          ; each raster line four times, then testing if at the midway point.

forward:    glo   r0                    ; get address of current line
            glo   r0

            plo   r0                    ; repeat same line again
            plo   r0
            plo   r0

            plo   r0                    ; repeat same line again
            plo   r0
            plo   r0

            plo   r0                    ; repeat again, check if halfway
            smi   120
            glo   r0

            bnf   forward               ; if not halfway then next line


          ; Once we get to the halfway point, we then display the same lines
          ; again, four times each, but in backwards order to mirrow them.

reverse:    plo   r0                    ; set address of next line
            plo   r0

            plo   r0                    ; repeat same line again
            plo   r0
            plo   r0

            plo   r0                    ; repeat same line again
            plo   r0
            plo   r0

            plo   r0                    ; repeat again, check if at end
            plo   r0
            smi   8

            bdf   reverse               ; if not at end then next line

            lda   r2                    ; restore df flag from stack
            shrc

            lda   r2                    ; restore d, x, p and return
            ret

intserv:    lbr   intmain               ; three-cycle jump for timing



          ; Table of pre-calculated squares from 0 to 31. We only need the
          ; LSB of these since we just use a modulo of the result.

squares:    db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)
            db    ($-squares)*($-squares)


            org   (($-1)|255)+1

          ; Two page-aligned video buffers in static memory after the program.
          ; Defining them here with DS will include them in the load size so
          ; space is reserved for them, but they will not actually be included.

display:    ds    512

end:        end   begin

