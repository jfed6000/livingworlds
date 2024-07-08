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
OBJS		= livingworlds pixmap8raw colors8
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

colors8: colors8.asm
	$(AS) $(ASOUT)$@ $< $(AFLAGS)

pixmap8raw: pixmap8-raw.asm
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
