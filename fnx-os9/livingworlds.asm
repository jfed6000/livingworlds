********************************************************************
* living worlds NOS9 port of the
* 6502 demo port for the f256 Jr. at
* https://github.com/clandrew/livingworlds by @hadyenkale
* This is a color cycling demo based on Mark Ferrari's "Living Worlds"
* found here: http://www.effectgames.com/demos/worlds/.
* This is ported to the Foenix F256 platform for educational purposes.
*
* NOS9 6809 port by John Federico
*
* Edt/Rev  YYYY/MM/DD  Modified by
* Comment
* ------------------------------------------------------------------


                    nam       livingworlds
                    ttl       f256 bitmap-clut test


                    ifp1
                    use       defsfile
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

                    mod       eom,name,tylg,atrv,start,size

currPath            rmb       1         current path for file read
bmblock             rmb       1         bitmap block#
mapaddr             rmb       2         Address for mapped block
currBlk             rmb       2         current mapped in block, (need to read into X)
blkCnt              rmb       1         Counter for block loop
fade_in_index       rmb       1
fade_out_index      rmb       1
fade_key            rmb       1
scene_index         rmb       1
next_scene_index    rmb       1
animation_index     rmb       1
clutheader          rmb       2
clutdata            rmb       2
iter_1              rmb       1
tmpb                rmb       1
tmpg                rmb       1
tmpr                rmb       1
tmpclut             rmb       1024      
                    rmb       250       stack space
size                equ       .

name                fcs       /livingworlds/
                    fcb       edition


start
*                   **** Initialize vars
                    ldx       #0
                    stx       <clutheader
                    stx       <clutdata
                    clr       <fade_in_index
                    clr       <fade_out_index
                    clr       <fade_key
                    clr       <scene_index
                    clr       <animation_index
                    
*                   **** Get a new bitmap 0
                    ldy       #$0                 Bitmap #
                    ldx       #$0                 Screentype = 320x240 (1=320x200)
                    lda       #$0                 Path #
                    ldb       #SS.AScrn           Assign and create bitmap
                    os9       I$SetStt
                    bcc       storeblk            No error, store block#
                    cmpb      #E$WADef            Check if window already defined
                    lbne      error               if other error, then end else continue
storeblk            tfr       x,d
                    stb       <bmblock            Store bitmap block# for later use

setBMClut
*                   **** Assign CLUT0 to BM0
                    ldx       #0                  CLUT #
                    ldy       #0                  Bitmap #
                    lda       #0                  Path #
                    ldb       #SS.Palet           Assign Clut # to Bitmap #
                    os9       I$SetStt

setlayer
*                   **** Assign BM0 to Layer0               
                    ldx       #0                  Layer #
                    ldy       #0                  Bitmap #
                    lda       #0                  Path # 
                    ldb       #SS.PScrn           Position Bitmap # on Layer #
                    os9       I$SetStt

main                lbsr      initializescene     load the pixmap and clut

* In the 6502 code the lock routine checks animation_index, when it
* wraps around to 0, It breaks out of the lock.  animation_index is
* decrement by an IRQ interrupt on the video signal for start of frame
* instead of this, just sleep the process and free the time for other
* processes in the system
lock                ldx       #7               
                    os9       F$Sleep

*                   **** Reset for next frame
UpdateCheck         lda       #$5
                    sta       <animation_index

*                   **** Update fade
                    lda       <fade_in_index        6502 code has a cmp #0, but lda set zero flag
                    bne       ApplyFadeIn

                    lda       <fade_out_index
                    bne       ApplyFadeOut

*                   **** No fade
                    lbsr      updatelut
                    lbsr      clutcopy
                    bra       pollkeyboard

ApplyFadeIn         cmpa      #5
                    bne       fadeit
*                    **** Turn on Graphics
                    ldx       #FX_BM+FX_GRF       Turn on Bitmaps and Graphics
                    ldy       #FT_OMIT            Don't change $FFC1
                    lda       #$00                Path #
                    ldb       #SS.DScrn           Display Screen with new settings 
                    os9       I$SetStt            
                    lbcs      error                 
fadeit              dec       <fade_in_index
                    dec       <fade_key
                    bne       fadein
                    lbsr      clutcopy
                    bra       lock
fadein              lbsr      fadeclut
                    bra       lock

ApplyFadeOut        inc       <fade_out_index
                    inc       <fade_key
                    bne       fadeout
                    lbsr      clutcopy
                    bra       contfadeout@
fadeout             lbsr      fadeclut
contfadeout@        lda       <fade_key
                    cmpa      #7
                    bne       lock
*                   ****      Advance to next scene
*                   **** Turn off bitmap
                    ldx       #FX_GRF            Turn on Bitmaps and Graphics
                    ldy       #FT_OMIT            Don't change $FFC1
                    lda       #$00                Path #
                    ldb       #SS.DScrn           Display Screen with new settings 
                    os9       I$SetStt            
                    lbcs      error
                    
                    clr       <fade_out_index
                    lda       <next_scene_index
                    sta       <scene_index
                    lbsr      unlinkclut
                    lbsr      initializescene
                    lbra      lock
                    
pollkeyboard        lbsr      handlekeyboard
                    cmpa      #113
                    beq       exit

                    lbra      lock

*                   lbsr      Wait4KeyPress

*                   **** Turn off Graphics
exit                ldx       #FX_TXT             Turn on Text, all else off
                    ldy       #FT_OMIT            Don't change $FFC1
                    lda       #$00                Path #
                    ldb       #SS.DScrn           Display Screen with new settings 
                    os9       I$SetStt            
                    lbcs      error

*                   **** Unlink CLUT
                    lbsr      unlinkclut

*                   **** Deallocate Bitmap memory
                    ldy       #$0                 Bitmap 0
                    lda       #$0                 Path #
                    ldb       #SS.FScrn           Free Screen Ram
                    os9       I$SetStt
                    lbcs       error
                    clrb

error               os9       F$Exit

clut0               fcs       /colors13/
clut1               fcs       /colors8/
clut2               fcs       /colors16/
clut3               fcs       /colors17/
clut4               fcs       /colors18/

pixmap0             fcs       !/dd/cmds/pixmap13raw!
pixmap1             fcs       !/dd/cmds/pixmap8raw!
pixmap2             fcs       !/dd/cmds/pixmap16raw!
pixmap3             fcs       !/dd/cmds/pixmap17raw!
pixmap4             fcs       !/dd/cmds/pixmap18raw!

                    fcb       $0D

fstatus             fcc       "fstatus"

CRtn                fcb       C$CR


handlekeyboard      lbsr      INKEY
                    cmpa      #8
                    beq       leftarrow
                    cmpa      #9
                    beq       rightarrow
                    rts

leftarrow           lda       <scene_index
                    sta       <next_scene_index
                    beq       leftarrow_wraparound
                    dec       <next_scene_index
                    bra       leftarrow_initializescene
leftarrow_wraparound                
                    lda       #4
                    sta       <next_scene_index
leftarrow_initializescene
                    lda       #1
                    sta       <fade_out_index
                    sta       <fade_key
                    rts


rightarrow          lda       <scene_index
                    sta       <next_scene_index
                    cmpa      #4
                    beq       rightarrow_wraparound
                    inc       <next_scene_index
                    bra       rightarrow_initializescene
rightarrow_wraparound
                    clr       <next_scene_index
rightarrow_initializescene
                    lda       #1
                    sta       <fade_out_index
                    sta       <fade_key
                    rts


forkfstatus         leax      >fstatus,pcr
                    leau      >CRtn,pcr
                    ldd       #$0100
                    ldy       #$0001
                    os9       F$Fork
                    lbcs      error
                    os9       F$Wait
                    rts

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
                    ldy       #1                  number of char to print
                    tfr       s,x                 point x at 1 char buffer
                    os9       I$Read
                    puls      a,x,y,pc
                    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Clut Load
; extry:  x is address of file path/name
; Loads CLUT from file or link
clutload
*                   **** Try to link CLUT data module
*                   **** If Link fails, then Load the module from default chx
                    pshs      a,b,x,y,u
                    lda       #0                  F$Load a=langauge, 0=any
                    os9       F$Link              Try linking module
                    beq       cont@               Load CLUT if no error, if error, try load
                    os9       F$Load              Load and set Y=entry point of module
                    lbcs      err@
cont@               stu       <clutheader
                    sty       <clutdata
err@                puls      u,y,x,b,a


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Clut copy
; extry:  none
; copies clut from loaded module to CLUT#0
clutcopy            pshs      a,b,y,u
                    ldx       #0
                    ldy       <clutdata
                    lda       #$0                 Path #
                    ldb       #SS.DfPal           Define Palette CLUT#0 with data Y
                    os9       I$SetStt
err@                puls      u,y,a,b,pc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Unlink Clut
; extry:  none
; unlink the current clut module from memory
unlinkclut          pshs      u
                    ldu       <clutheader
                    os9       F$Unlink
                    puls      u,pc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; C to tmp with fade
; copy the c
; this is LutLoop in 6502 code.  Using a tmp buffer
; to avoid addressing hardware directly.
fadeclut            pshs      a,b,x,y
                    ldx       <clutdata
                    leay      tmpclut,u
                    ldb       #0
                    tst       <fade_key
                    beq       nofadeclut
loop@               lda       ,x
                    lbsr      fade
                    sta       ,y
                    lda       1,x
                    lbsr      fade
                    sta       1,y
                    lda       2,x
                    lbsr      fade
                    sta       2,y
                    lda       3,x
                    sta       3,y
                    leax      4,x
                    leay      4,y
                    incb
                    bne       loop@
                    bra       lutdone
nofadeclut          lda       ,x
                    sta       ,y
                    lda       1,x
                    sta       1,y
                    lda       2,x
                    sta       2,y
                    lda       3,x
                    sta       3,y
                    leax      4,x
                    leay      4,y
                    leax      4,x
                    leay      4,y
                    incb
                    bne       nofadeclut
lutdone             leay      tmpclut,u
                    ldx       #0
                    lda       #$0                 Path #
                    ldb       #SS.DfPal           Define Palette CLUT#0 with data Y
                    os9       I$SetStt
                    puls      y,x,b,a,pc                    
                    
                          
                    
                    
                    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Open Pixmap
; entry:  x is address of file path/name
; This loads the image from the file into bitmap 0
pixmapload          pshs      a,u
                    lda       #READ.
                    os9       I$Open
                    lbcs      loaderror
                    sta       <currPath
                    
                    ldb       <bmblock
                    clra
                    std       <currBlk
                    sta       <blkCnt
                              
loadimage           pshs      u
                    ldb       #1
                    ldx       <currBlk
                    os9       F$MapBlk
                    bcc       noerr@
                    puls      u
                    lbra      loaderror
noerr@              stu       <mapaddr
                    puls      u

                    lda       <currPath
                    ldx       <mapaddr
                    ldy       #$2000
                    os9       I$Read
                    bcc       noerr@
                    cmpb      #E$EOF
                    beq       loaddone
                    lbra      loaderror
noerr@              inc       <blkCnt

                    pshs      u
                    ldu       <mapaddr
                    ldb       #1
                    os9       F$ClrBlk
                    puls      u
                    
                    lda       <blkCnt
                    cmpa      #$0A
                    beq       loaddone
                    inc       <currBlk+1
                    bra       loadimage

loaddone            lda       <currPath
                    os9       I$Close
loaderror           puls      a,u,pc


;;; Initialize scene routines
initializescene     lda       #6
                    sta       fade_in_index
                    sta       fade_key

                    lda       scene_index
                    cmpa      #$0
                    lbeq      LInitScene0

                    cmpa      #$1
                    lbeq      LInitScene1

                    cmpa      #$2
                    lbeq      LInitScene2

                    cmpa      #$3
                    lbeq      LInitScene3

                    cmpa      #$4
                    lbeq      LInitScene4

                    rts

LInitScene0         leax      clut0,pcr
                    lbsr      clutload
                    lbsr      clutcopy
                    leax      pixmap0,pcr
                    lbsr      pixmapload
                    rts

LInitScene1         leax      clut1,pcr
                    lbsr      clutload
                    lbsr      clutcopy
                    leax      pixmap1,pcr
                    lbsr      pixmapload
                    rts

LInitScene2         leax      clut2,pcr
                    lbsr      clutload
                    lbsr      clutcopy
                    leax      pixmap2,pcr
                    lbsr      pixmapload
                    rts

LInitScene3         leax      clut3,pcr
                    lbsr      clutload
                    lbsr      clutcopy
                    leax      pixmap3,pcr
                    lbsr      pixmapload
                    rts

LInitScene4         leax      clut4,pcr
                    lbsr      clutload
                    lbsr      clutcopy
                    leax      pixmap4,pcr
                    lbsr      pixmapload
                    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Fade
; Input in A
; Output in A
fade
                    pshs      b
                    ldb       <fade_key
                    cmpb      #0
                    beq       fade0
                    cmpb      #1
                    beq       fade1
                    cmpb      #2
                    beq       fade2
                    cmpb      #3
                    beq       fade3
                    cmpb      #4
                    beq       fade4
                    cmpb      #5
                    beq       fade5

fade6               lsra
fade5               lsra
fade4               lsra
fade3               lsra
fade2               lsra
fade1               lsra
fade0               puls      b,pc


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Cycle Colors
;       a = cycle length
;       x = source pointer
cyclecolors         tfr       a,b
                    lsla
                    lsla
                    suba      #4
                    leax      a,x
                    decb
*                   **** Back up edge of cycle
                    lda       4,x
                    sta       <tmpb
                    lda       5,x
                    sta       <tmpg
                    lda       6,x
                    sta       <tmpr
cyclecolors_loop    lda       ,x
                    sta       4,x
                    lda       1,x
                    sta       5,x
                    lda       2,x
                    sta       6,x
                    leax      -4,x
                    decb
                    bne       cyclecolors_loop
*                   **** put edge at end
                    lda       ,x
                    sta       4,x
                    lda       1,x
                    sta       5,x
                    lda       2,x
                    sta       6,x
                    lda       <tmpb
                    sta       ,x
                    lda       <tmpg
                    sta       1,x
                    lda       <tmpr
                    sta       2,x
                    rts
                    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update LUT
; 
;      
updatelut           lda       <scene_index
                    cmpa      #0
                    lbeq      updatelutscene0
                    cmpa      #1
                    lbeq      updatelutscene1
                    cmpa      #2
                    lbeq      updatelutscene2
                    cmpa      #3
                    lbeq      updatelutscene3
                    cmpa      #4
                    lbeq      updatelutscene4
                    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update LUT Scene 0
; LUT for pixmap8
; from cycle.13.s in 6502 version   
updatelutscene0
*                   ****  32-47 inclusive
                    ldx       <clutdata
                    leax      32*4,x
                    lda       #15
                    lbsr      cyclecolors

*                   ****  48-63 inclusive
                    ldx       <clutdata
                    leax      48*4,x
                    lda       #15
                    lbsr      cyclecolors

*                   ****  64-79 inclusive
                    ldx       <clutdata
                    leax      64*4,x
                    lda       #15
                    lbsr      cyclecolors
                    
*                   ****  80-95 inclusive
                    ldx       <clutdata
                    leax      80*4,x
                    lda       #15
                    lbsr      cyclecolors 

*                   ****  96-103 inclusive
                    ldx       <clutdata
                    leax      96*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  128-143 inclusive
                    ldx       <clutdata
                    leax      128*4,x
                    lda       #15
                    lbsr      cyclecolors

*                   ****  22-31 inclusive
                    ldx       <clutdata
                    leax      22*4,x
                    lda       #9
                    lbsr      cyclecolors
                    
                    rts
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update LUT Scene 1
; LUT for pixmap8
; from cycle.8s in 6502 version   
updatelutscene1
*                   ****  202-207 inclusive
                    ldx       <clutdata
                    leax      202*4,x
                    lda       #5
                    lbsr      cyclecolors

*                   ****  196-201 inclusive
                    ldx       <clutdata
                    leax      196*4,x
                    lda       #5
                    lbsr      cyclecolors

*                   ****  208-215 inclusive
                    ldx       <clutdata
                    leax      208*4,x
                    lda       #7
                    lbsr      cyclecolors
                    
*                   ****  216-223 inclusive
                    ldx       <clutdata
                    leax      216*4,x
                    lda       #7
                    lbsr      cyclecolors                   

                    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update LUT Scene 2
; LUT for pixmap16
; from cycle.16.s in 6502 version   
updatelutscene2
*                   ****  141-145 inclusive
                    ldx       <clutdata
                    leax      141*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  146-150 inclusive
                    ldx       <clutdata
                    leax      146*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  151-155 inclusive
                    ldx       <clutdata
                    leax      151*4,x
                    lda       #4
                    lbsr      cyclecolors
                    
*                   ****  156-160 inclusive
                    ldx       <clutdata
                    leax      156*4,x
                    lda       #4
                    lbsr      cyclecolors 

*                   ****  161-165 inclusive
                    ldx       <clutdata
                    leax      161*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  166-170 inclusive
                    ldx       <clutdata
                    leax      166*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  171-175 inclusive
                    ldx       <clutdata
                    leax      171*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  190-194 inclusive
                    ldx       <clutdata
                    leax      190*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  195-199 inclusive
                    ldx       <clutdata
                    leax      195*4,x
                    lda       #4
                    lbsr      cyclecolors
                    
*                   ****  200-204 inclusive
                    ldx       <clutdata
                    leax      200*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  205-209 inclusive
                    ldx       <clutdata
                    leax      205*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  210-214 inclusive
                    ldx       <clutdata
                    leax      210*4,x
                    lda       #4
                    lbsr      cyclecolors

*                   ****  215-219 inclusive
                    ldx       <clutdata
                    leax      215*4,x
                    lda       #4
                    lbsr      cyclecolors
                    
                    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update LUT Scene 3
; LUT for pixmap17
; from cycle.17.s in 6502 version   
updatelutscene3
*                   ****  104-111 inclusive
                    ldx       <clutdata
                    leax      104*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  92-97 inclusive
                    ldx       <clutdata
                    leax      92*4,x
                    lda       #5
                    lbsr      cyclecolors

*                   ****  98-103 inclusive
                    ldx       <clutdata
                    leax      98*4,x
                    lda       #5
                    lbsr      cyclecolors
                    
*                   ****  112-119 inclusive
                    ldx       <clutdata
                    leax      112*4,x
                    lda       #7
                    lbsr      cyclecolors 

*                   ****  120-127 inclusive
                    ldx       <clutdata
                    leax      128*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  128-135 inclusive
                    ldx       <clutdata
                    leax      128*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  136-143 inclusive
                    ldx       <clutdata
                    leax      136*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  144-151 inclusive
                    ldx       <clutdata
                    leax      144*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  152-159 inclusive
                    ldx       <clutdata
                    leax      152*4,x
                    lda       #7
                    lbsr      cyclecolors
                    
*                   ****  192-199 inclusive
                    ldx       <clutdata
                    leax      192*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  200-207 inclusive
                    ldx       <clutdata
                    leax      200*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  208-215 inclusive
                    ldx       <clutdata
                    leax      210*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  216-223 inclusive
                    ldx       <clutdata
                    leax      216*4,x
                    lda       #7
                    lbsr      cyclecolors
                    
                    rts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Update LUT Scene 4
; LUT for pixmap18
; from cycle.18.s in 6502 version   
updatelutscene4
*                   ****  135-143 inclusive
                    ldx       <clutdata
                    leax      135*4,x
                    lda       #8
                    lbsr      cyclecolors

*                   ****  127-134 inclusive
                    ldx       <clutdata
                    leax      127*4,x
                    lda       #7
                    lbsr      cyclecolors

*                   ****  119-126 inclusive
                    ldx       <clutdata
                    leax      119*4,x
                    lda       #7
                    lbsr      cyclecolors
                    
*                   ****  217-223 inclusive
                    ldx       <clutdata
                    leax      217*4,x
                    lda       #6
                    lbsr      cyclecolors 

*                   ****  210-216 inclusive
                    ldx       <clutdata
                    leax      210*4,x
                    lda       #6
                    lbsr      cyclecolors

*                   ****  203-209 inclusive
                    ldx       <clutdata
                    leax      203*4,x
                    lda       #6
                    lbsr      cyclecolors

*                   ****  196-202 inclusive
                    ldx       <clutdata
                    leax      196*4,x
                    lda       #6
                    lbsr      cyclecolors

*                   ****  189-195 inclusive
                    ldx       <clutdata
                    leax      189*4,x
                    lda       #6
                    lbsr      cyclecolors

*                   ****  182-188 inclusive
                    ldx       <clutdata
                    leax      182*4,x
                    lda       #6
                    lbsr      cyclecolors
                    
*                   ****  175-181 inclusive
                    ldx       <clutdata
                    leax      175*4,x
                    lda       #6
                    lbsr      cyclecolors

                    rts

                    emod
eom                 equ       *
                    end
