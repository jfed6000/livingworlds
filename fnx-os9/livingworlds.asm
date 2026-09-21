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

* TinyVicky II DMA Registers (Junior 2 architecture)
DMA_BASE_ADDR       equ       $FEC0
DMA_CTRL            equ       DMA_BASE_ADDR+0     * Control register (b0=En, b2=Fill, b7=Start)
DMA_STATUS          equ       DMA_BASE_ADDR+1     * Read: b7=Busy (TRF_IP)
DMA_FILL_VAL        equ       DMA_BASE_ADDR+1     * Write: 8-bit fill byte
DMA_DST_H           equ       DMA_BASE_ADDR+9     * Destination address bits 23:16 ($FEC9)
DMA_DST_M           equ       DMA_BASE_ADDR+10    * Destination address bits 15:8  ($FECA)
DMA_DST_L           equ       DMA_BASE_ADDR+11    * Destination address bits 7:0   ($FECB)
DMA_SZ_1D_H         equ       DMA_BASE_ADDR+15    * 1D size bits 23:16 ($FECF)
DMA_SZ_1D_M         equ       DMA_BASE_ADDR+12    * 1D size bits 15:8  ($FECC)
DMA_SZ_1D_L         equ       DMA_BASE_ADDR+13    * 1D size bits 7:0   ($FECD)
FADE_DELAY          equ       4         Ticks per fade step (4 ticks @ 60Hz = 15 Hz step rate, ~0.53s total fade)

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
fade_state          rmb       1         0 = normal, 1 = fade out, 2 = fade in
fade_tick           rmb       1         tick counter for fade delay
fade_key            rmb       1         fade brightness level (0 = 100%, 8 = black)
scene_index         rmb       1
next_scene_index    rmb       1
animation_index     rmb       1
clutheader          rmb       2
clutdata            rmb       2
iter_1              rmb       1
tmpb                rmb       1
tmpg                rmb       1
tmpr                rmb       1
anim_speed          rmb       1
tick_count          rmb       1
paused              rmb       1
saved_eko           rmb       1
popts               rmb       32
tmpclut             rmb       1024      
                    rmb       250       stack space
size                equ       .

name                fcs       /livingworlds/
                    fcb       edition


start
*                   **** Setup signal intercept
                    leax      sig_handler,pcr
                    os9       F$Icpt

*                   **** Turn off keyboard echo so typing doesn't write to text screen
                    lbsr      keyechooff

*                   **** Initialize vars
                    ldx       #0
                    stx       <clutheader
                    stx       <clutdata
                    clr       <fade_state
                    clr       <fade_tick
                    clr       <fade_key
                    clr       <scene_index
                    clr       <animation_index
                    clr       <tick_count
                    clr       <paused
                    lda       #5                  Default animation delay: 5 ticks (12 fps, locked to 60Hz VSYNC)
                    sta       <anim_speed
                    
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

*                   **** Clear hardware CLUT #0 to black for initial fade-in
                    lda       #8
                    sta       <fade_key
                    lbsr      fadeclut

*                   **** Turn on Graphics
                    ldx       #FX_BM+FX_GRF       Turn on Bitmaps and Graphics
                    ldy       #FT_OMIT            Don't change $FFC1
                    lda       #$00                Path #
                    ldb       #SS.DScrn           Display Screen with new settings 
                    os9       I$SetStt            
                    lbcs      error                 

*                   **** Start with smooth fade-in from black
                    lda       #2                  STATE_FADE_IN
                    sta       <fade_state
                    lda       #8                  Start at black
                    sta       <fade_key
                    clr       <fade_tick

animloop            ldx       #2                  Real 1-tick timed sleep (16.6ms / 60Hz VSYNC)
                    os9       F$Sleep

                    lbsr      handlekeyboard
                    tsta
                    bne       checkexit

continue_anim       tst       <fade_state
                    bne       process_fade

*                   **** Normal animation state (fade_state == 0)
                    tst       <paused
                    bne       animloop

                    inc       <tick_count
                    lda       <tick_count
                    cmpa      <anim_speed
                    blo       animloop
                    clr       <tick_count

                    lbsr      updatelut
                    lbsr      clutcopy
                    bra       animloop

*                   **** Fade state processing (fade_state != 0)
process_fade        inc       <fade_tick
                    lda       <fade_tick
                    cmpa      #FADE_DELAY         Advance fade every FADE_DELAY ticks (~0.53s total fade)
                    blo       animloop
                    clr       <fade_tick

                    lda       <fade_state
                    cmpa      #1                  State 1 = Fading OUT
                    beq       do_fade_out
                    cmpa      #2                  State 2 = Fading IN
                    beq       do_fade_in
                    clr       <fade_state
                    bra       animloop

do_fade_out         inc       <fade_key
                    lda       <fade_key
                    cmpa      #8
                    bhi       fade_out_done
                    lbsr      updatelut           Animate colors while fading
                    lbsr      fadeclut            Upload dimmed palette
                    bra       animloop

fade_out_done       * Fade out complete (screen is black)
                    * Switch to next scene
                    lbsr      unlinkclut
                    lda       <next_scene_index
                    sta       <scene_index
                    lbsr      initializescene

                    * Begin fade-in
                    lda       #2                  STATE_FADE_IN
                    sta       <fade_state
                    lda       #8                  Start at black
                    sta       <fade_key
                    clr       <fade_tick
                    bra       animloop

do_fade_in          dec       <fade_key
                    beq       fade_in_done
                    lbsr      updatelut           Animate colors while fading in
                    lbsr      fadeclut            Upload brightening palette
                    bra       animloop

fade_in_done        lbsr      clutcopy            Restore 100% bright original palette
                    clr       <fade_state         Back to normal running
                    clr       <tick_count
                    bra       animloop

checkexit           cmpa      #'q'
                    lbeq      exit
                    cmpa      #'Q'
                    lbeq      exit
                    cmpa      #5                  Ctrl-E / ESC from PS/2
                    lbeq      exit
                    cmpa      #27                 ASCII ESC
                    lbeq      exit
                    cmpa      #3                  Ctrl-C
                    lbeq      exit
                    lbra      continue_anim

sig_handler         lbra      exit

*                   **** Turn off Graphics
exit                ldx       #FX_TXT             Turn on Text, all else off
                    ldy       #FT_OMIT            Don't change $FFC1
                    lda       #$00                Path #
                    ldb       #SS.DScrn           Display Screen with new settings 
                    os9       I$SetStt            

*                   **** Restore terminal echo
                    lbsr      keyechoon

*                   **** Unlink CLUT
                    lbsr      unlinkclut

*                   **** Deallocate Bitmap memory
                    ldy       #$0                 Bitmap 0
                    lda       #$0                 Path #
                    ldb       #SS.FScrn           Free Screen Ram
                    os9       I$SetStt

                    clrb
error               os9       F$Exit

keyechooff          pshs      a,b,x
                    clra
                    ldb       #SS.Opt
                    leax      popts,u
                    os9       I$GetStt
                    bcs       keo_exit@
                    lda       4,x
                    sta       saved_eko,u
                    clr       4,x
                    clra
                    ldb       #SS.Opt
                    os9       I$SetStt
keo_exit@           puls      a,b,x,pc

keyechoon           pshs      a,b,x
                    clra
                    ldb       #SS.Opt
                    leax      popts,u
                    os9       I$GetStt
                    bcs       ken_exit@
                    lda       saved_eko,u
                    sta       4,x
                    clra
                    ldb       #SS.Opt
                    os9       I$SetStt
ken_exit@           puls      a,b,x,pc


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
                    tsta
                    lbeq      hk_done

* Next scene keys
                    cmpa      #9                  Tab / Right arrow
                    lbeq      rightarrow
                    cmpa      #$0E                Alt right arrow
                    lbeq      rightarrow
                    cmpa      #']'
                    lbeq      rightarrow
                    cmpa      #'d'
                    lbeq      rightarrow
                    cmpa      #'D'
                    lbeq      rightarrow
                    cmpa      #' '                Spacebar
                    lbeq      rightarrow

* Previous scene keys
                    cmpa      #8                  Backspace / Left arrow
                    lbeq      leftarrow
                    cmpa      #'['
                    lbeq      leftarrow
                    cmpa      #'a'
                    lbeq      leftarrow
                    cmpa      #'A'
                    lbeq      leftarrow

* Speed adjustment keys
                    cmpa      #'+'
                    beq       speed_up
                    cmpa      #'='
                    beq       speed_up
                    cmpa      #'-'
                    beq       speed_down
                    cmpa      #'_'
                    beq       speed_down

* Pause keys
                    cmpa      #'p'
                    beq       toggle_pause
                    cmpa      #'P'
                    beq       toggle_pause

* Number keys '1'..'9' for direct speed (1 = fastest, 9 = slow)
                    cmpa      #'1'
                    blo       hk_unhandled
                    cmpa      #'9'
                    bhi       hk_unhandled
                    suba      #'0'
                    sta       <anim_speed
                    clra
                    rts

speed_up            lda       <anim_speed
                    cmpa      #1
                    bls       su_done@
                    deca
                    sta       <anim_speed
su_done@            clra
                    rts

speed_down          lda       <anim_speed
                    cmpa      #30
                    bhs       sd_done@
                    inca
                    sta       <anim_speed
sd_done@            clra
                    rts

toggle_pause        lda       <paused
                    eora      #1
                    sta       <paused
                    clra
                    rts

hk_done             clra
hk_unhandled        rts

leftarrow           tst       <fade_state
                    bne       hk_done             Ignore if already fading
                    lda       <scene_index
                    beq       la_wrap@
                    deca
                    bra       la_switch@
la_wrap@            lda       #4
la_switch@          sta       <next_scene_index
                    lda       #1                  STATE_FADE_OUT
                    sta       <fade_state
                    clr       <fade_key
                    clr       <fade_tick
                    clra
                    rts

rightarrow          tst       <fade_state
                    bne       hk_done             Ignore if already fading
                    lda       <scene_index
                    cmpa      #4
                    beq       ra_wrap@
                    inca
                    bra       ra_switch@
ra_wrap@            clra
ra_switch@          sta       <next_scene_index
                    lda       #1                  STATE_FADE_OUT
                    sta       <fade_state
                    clr       <fade_key
                    clr       <fade_tick
                    clra
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
                    ldy       #1                  number of char to read
                    tfr       s,x                 point x at 1 char buffer
                    clra                          path 0 (stdin)
                    os9       I$Read
                    puls      a,x,y,pc
                    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Clut Load
; entry:  x is address of file path/name
; Loads CLUT from file or link
clutload            pshs      a,b,x,y,u
                    lda       #0                  any module type
                    os9       F$Link              Try linking module
                    bcc       linkok@             If linked ok, proceed
                    ldx       2,s                 Restore module name pointer from stack
                    lda       #0                  any type
                    os9       F$Load              Load from execution dir
                    bcs       load_err@           If error, exit
linkok@             stu       <clutheader
                    sty       <clutdata
load_err@           puls      a,b,x,y,u,pc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Clut copy
; entry:  none
; copies clut from loaded module to CLUT#0
clutcopy            pshs      a,b,x,y,u
                    ldx       #0                  CLUT #0
                    ldy       <clutdata
                    beq       cc_err@             skip if no clut
                    lda       #$0                 Path #
                    ldb       #SS.DfPal           Define Palette CLUT#0 with data Y
                    os9       I$SetStt
cc_err@             puls      a,b,x,y,u,pc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Unlink Clut
; entry:  none
; unlink the current clut module from memory
unlinkclut          pshs      u
                    ldu       <clutheader
                    beq       nounlink@
                    os9       F$Unlink
                    ldu       #0
                    stu       <clutheader
                    stu       <clutdata
nounlink@           puls      u,pc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DmaClearScreen
; 1D Linear DMA Fill: Clear 76,800 bytes ($012C00) of BM0 to color 0
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DmaClearScreen      pshs      a,b
                    ldb       <bmblock
                    tfr       b,a
                    lsra
                    lsra
                    lsra
                    sta       >DMA_DST_H
                    tfr       b,a
                    asla
                    asla
                    asla
                    asla
                    asla
                    sta       >DMA_DST_M
                    clr       >DMA_DST_L

                    lda       #$01                76,800 bytes = $012C00
                    sta       >DMA_SZ_1D_H
                    lda       #$2C
                    sta       >DMA_SZ_1D_M
                    clr       >DMA_SZ_1D_L

                    clr       >DMA_FILL_VAL       Clear to black ($00)
                    lda       #$85                DMA_CTRL_Enable + DMA_CTRL_Start_Trf + DMA_CTRL_Fill
                    sta       >DMA_CTRL
dma_wait@           lda       >DMA_STATUS
                    bmi       dma_wait@           b7 = Busy
                    puls      a,b,pc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; C to tmp with fade
fadeclut            pshs      a,b,x,y,u
                    ldx       <clutdata
                    beq       lutexit@
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
                    incb
                    bne       nofadeclut
lutdone             leay      tmpclut,u
                    ldx       #0
                    lda       #$0                 Path #
                    ldb       #SS.DfPal           Define Palette CLUT#0 with data Y
                    os9       I$SetStt
lutexit@            puls      a,b,x,y,u,pc
                    
                    
                          
                    
                    
                    

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
initializescene     pshs      a,x
                    lbsr      DmaClearScreen
                    lda       <scene_index
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
initdone            puls      a,x,pc

LInitScene0         leax      clut0,pcr
                    lbsr      clutload
                    leax      pixmap0,pcr
                    lbsr      pixmapload
                    lbra      initdone

LInitScene1         leax      clut1,pcr
                    lbsr      clutload
                    leax      pixmap1,pcr
                    lbsr      pixmapload
                    lbra      initdone

LInitScene2         leax      clut2,pcr
                    lbsr      clutload
                    leax      pixmap2,pcr
                    lbsr      pixmapload
                    lbra      initdone

LInitScene3         leax      clut3,pcr
                    lbsr      clutload
                    leax      pixmap3,pcr
                    lbsr      pixmapload
                    lbra      initdone

LInitScene4         leax      clut4,pcr
                    lbsr      clutload
                    leax      pixmap4,pcr
                    lbsr      pixmapload
                    lbra      initdone



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Fade
; Input in A
; Output in A
fade                pshs      b
                    ldb       <fade_key
                    beq       fade_done@
                    cmpb      #8
                    bhs       fade_black@
fade_loop@          lsra
                    decb
                    bne       fade_loop@
                    puls      b,pc
fade_black@         clra
fade_done@          puls      b,pc


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
updatelut           ldx       <clutdata
                    beq       upd_done@
                    lda       <scene_index
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
upd_done@           rts


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
