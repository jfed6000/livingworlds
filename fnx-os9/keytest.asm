********************************************************************
* keytest
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------


                    nam       keytest
                    ttl       inkeykeytest


                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

                    mod       eom,name,tylg,atrv,start,size

bufstrt             rmb       2
bufcur              rmb       2
linebuf             rmb       80
size                equ       .

name                fcs       /keytest/
                    fcb       edition


start               leax      linebuf,u           get line buffer address
                    stx       <bufstrt            and store it away
                    stx       <bufcur             current output position output buffer
		    lda	      #65
		    lbsr      bufchr
                    lbsr      wrbuf               print CR
Wait4KeyPress       bsr       INKEY
                    tsta
                    beq       Wait4KeyPress

		    
		    lbsr      bufval
		    lbsr      wrbuf
		    bra	      Wait4KeyPress



error               os9       F$Exit



INKEY               clra                          std in
                    ldb       #SS.Ready
                    os9       I$GetStt            see if key ready
                    bcc       getit
                    cmpb      #E$NotRdy           no keys ready=no error
                    bne       exit@               other error, report it
                    clra                          no error
                    bra       exit@
getit               lbsr      FGETC               go get the key
                    tsta
exit@               rts

FGETC               pshs      a,x,y
		    clra
                    ldy       #1                  number of char to print
                    tfr       s,x                 point x at 1 char buffer
                    os9       I$Read
                    puls      a,x,y,pc


* convert value in A to ASCII hex (2 chars). Append to output buffer.
bufval              pshs      a                   preserve original value
                    lsra                          shift 4 bits
                    lsra                          to get high 4 bits
                    lsra
                    lsra
                    bsr       L014F               do high 4 bits then rts and do low 4
                    puls      a                   pull original value for low 4 bits
L014F               anda      #$0F                mask high bit and process low 4 bits

* FALL THROUGH
* Convert digit to ASCII with leading spaces, add to output buffer
* A is a 0-9 or A-F or $F0.
* Add $30 converts 0-9 to ASCII "0" - "9"), $F0 to ASCII "SPACE"
* leaves A-F >$3A so a further 7 is added so $3A->$41 etc. (ASCII "A" - "F")
L015C               adda      #$30
                    cmpa      #$3A
                    bcs       bufchr
                    adda      #$07

* FALL THROUGH
* Store A at next position in output buffer.
bufchr              pshs      x
                    ldx       <bufcur
                    sta       ,x+
                    stx       <bufcur
                    puls      pc,x

* Append CR to the output buffer then print the output buffer
wrbuf               pshs      y,x,a
                    lda       #C$CR
                    bsr       bufchr
                    ldx       <bufstrt            address of data to write
                    stx       <bufcur             reset output buffer pointer, ready for next line.
                    ldy       #80                 maximum # of bytes - otherwise, stop at CR
                    lda       #$01                to STDOUT
                    os9       I$WritLn
                    puls      pc,y,x,a


                    emod
eom                 equ       *
                    end