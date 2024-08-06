PORT = f256
MACHINE = F256
CPU = 6809
LEVEL = 2
TELNET_PORT = 6809
HTTPD_PORT = 8809

include $(NITROS9DIR)/rules.mak


# NitrOS-9
H6309		= $(AFLAGS) -DH6309=1
# Non-NitrOS-9
M6809		= $(AFLAGS)

DEPENDS		= ./makefile

#SOURCEFILES = inout.bf helloworld.bf donothing.bf
SOURCEFILES = $(shell echo *.bf)
TEXTFILES	= ReadMe $(SOURCEFILES)
OBJS		= livingworlds keytest pixmap8raw colors8 colors13 pixmap13raw colors16 pixmap16raw colors17 pixmap17raw colors18 pixmap18raw
ALLOBJS		= $(OBJS)

all:	banner $(ALLOBJS) $(DEPENDS)

banner:
	@$(ECHO) "**************************************************"
	@$(ECHO) "*                                                *"
	@$(ECHO) "*                Living Worlds                   *"
	@$(ECHO) "*                                                *"
	@$(ECHO) "**************************************************"

livingworlds: livingworlds.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

keytest: keytest.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

colors8: colors8.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

pixmap8raw: pixmap8-raw.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

colors13: colors13.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

pixmap13raw: pixmap13-raw.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

colors16: colors16.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

pixmap16raw: pixmap16-raw.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

colors17: colors17.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

pixmap17raw: pixmap17-raw.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

colors18: colors18.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

pixmap18raw: pixmap18-raw.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

clean: 
	$(RM) $(ALLOBJS)

#dsk: $(DSK)

#$(DSK): all
#	$(RM) $@
#	$(OS9FORMAT_SS35) $@ -n"brainfuck"
#	$(MAKDIR) $@,CMDS
#	$(OS9COPY) $(ALLOBJS) $@,CMDS
#	$(OS9ATTR_EXEC) $(foreach file,$(ALLOBJS),$@,CMDS/$(file))
#	$(CPL) $(TEXTFILES) $@,.
#	$(OS9ATTR_TEXT) $(foreach file,$(TEXTFILES),$@,$(file))

#dskcopy: $(DSK)
#	$(CP) $(DSK) $(DSKDIR)

#dskclean:
#	$(RM) $(DSK)

# Only $(CMDS) are shown here
showobjs:
	@$(ECHO) bf

# Only $(CMDS) are shown here
showfiles:
	@$(ECHO) $(SOURCEFILES)

info:
	@$(ECHO) "*** living worlds  ***"
#	@$(ECHO) $(DSK)
