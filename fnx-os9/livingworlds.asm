********************************************************************
* living worlds NOS9 port of the
* 6502 demo port for the f256 Jr. at
* https://github.com/clandrew/livingworlds by @hadyenkale
* This is a color cycling demo based on Mark Ferrari's "Living Worlds"
* found here: http://www.effectgames.com/demos/worlds/.
* This is ported to the Foenix F256 platform for educational purposes.
*
* NOS9 port by John Federico
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

currPath	    rmb	      1	        current path for file read
bmblock		    rmb	      1		bitmap block#
mapaddr		    rmb	      2		Address for mapped block
currBlk		    rmb	      2		current mapped in block, (need to read into X)
blkCnt		    rmb	      1		Counter for block loop
bufstrt             rmb       2
bufcur              rmb       2
linebuf             rmb       80
                    rmb       250       stack space
size                equ       .

name                fcs       /livingworlds/
                    fcb       edition


start
*                   **** Get a new bitmap 0
                    ldy       #$0                 Bitmap #
                    ldx       #$0                 Screentype = 320x240 (1=320x200)
                    lda       #$0                 Path #
                    ldb       #SS.AScrn           Assign and create bitmap
                    os9       I$SetStt
                    bcc       storeblk		  No error, store block#
		    cmpb      #E$WADef		  Check if window already defined
		    lbne      error		  if other error, then end else continue
storeblk 	    tfr       x,d
                    stb       <bmblock            Store bitmap block# for later use
clutload
*                   **** Try to link CLUT data module
*                   **** If Link fails, then Load the module from default chx
                    leax      clutname,pcr        F$Load x=address of path
                    lda       #0                  F$Load a=langauge, 0=any
                    os9       F$Link              Try linking module
                    beq       cont@               Load CLUT if no error, if error, try load
                    os9       F$Load              Load and set Y=entry point of module
                    lbcs      error
cont@               ldx       #$0                 CLUT #
                    lda       #$0                 Path #
                    ldb       #SS.DfPal           Define Palette CLUT#0 with data Y
                    os9       I$SetStt
                    lbcs      error

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

gfxon
*                    **** Turn on Graphics
		    ldx       #FX_BM+FX_GRF       Turn on Bitmaps and Graphics
                    ldy       #FT_OMIT            Don't change $FFC1
                    lda       #$00                Path #
                    ldb       #SS.DScrn           Display Screen with new settings 
                    os9       I$SetStt            
                    lbcs      error

*		    **** Open Pixmap
		    lda	      #READ.
		    leax      pixmap8,pcr
		    os9	      I$Open
		    lbcs      error
		    sta	      <currPath

		    
		    ldb	      <bmblock
		    clra
		    std	      <currBlk
		    sta       <blkCnt
		    	      
loadimage           pshs      u
		    ldb	      #1
		    ldx	      <currBlk
		    os9	      F$MapBlk
		    bcc	      noerr@
		    puls      u
		    lbra      error
noerr@		    stu	      <mapaddr
		    puls      u

		    lda	      <currPath
		    ldx	      <mapaddr
		    ldy	      #$2000
		    os9	      I$Read
		    bcc	      noerr@
		    cmpb      #E$EOF
		    beq	      loaddone
		    lbra      error
noerr@		    inc	      <blkCnt

		    pshs      u
		    ldu	      <mapaddr
		    ldb	      #1
		    os9	      F$ClrBlk
		    puls      u
		    
		    lda	      <blkCnt
		    cmpa      #$0A
		    beq	      loaddone
		    inc	      <currBlk+1
		    bra	      loadimage

loaddone	    lda	      <currPath
		    os9	      I$Close
		    lbcs      error


		    lbsr      Wait4KeyPress

*		    **** Turn off Graphics
                    ldx       #FX_TXT             Turn on Text, all else off
                    ldy       #FT_OMIT            Don't change $FFC1
                    lda       #$00                Path #
                    ldb       #SS.DScrn           Display Screen with new settings 
                    os9       I$SetStt            
                    lbcs      error


*		    **** Deallocate Bitmap memory
		    ldy	      #$0		  Bitmap 0
		    lda	      #$0		  Path #
		    ldb	      #SS.FScrn		  Free Screen Ram
		    os9	      I$SetStt
		    lbcs       error
		    clrb

error               os9       F$Exit

clutname	    fcs	      /colors8/

pixmap8		    fcs	      !/dd/cmds/pixmap8raw!
		    fcb	      $0D

fstatus		    fcc	      "fstatus"

CRtn		    fcb	      C$CR

forkfstatus	    leax      >fstatus,pcr
		    leau      >CRtn,pcr
		    ldd	      #$0100
		    ldy	      #$0001
		    os9	      F$Fork
		    lbcs      error
		    os9	      F$Wait
		    rts

Wait4KeyPress	    bsr	      INKEY
		    tsta
		    beq	      Wait4KeyPress

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
exit@		    rts

FGETC               pshs      a,x,y
                    ldy       #1                  number of char to print
                    tfr       s,x                 point x at 1 char buffer
                    os9       I$Read
                    puls      a,x,y,pc


                    emod
eom                 equ       *
                    end
