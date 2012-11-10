# $FreeBSD: stable/8/usr.sbin/sysinstall/Makefile 211154 2010-08-10 19:50:51Z gabor $

.if ${MACHINE_ARCH} != "ia64"
_wizard=	wizard.c
.endif

PROG=	sysinstall
MAN=	sysinstall.8
SRCS=	anonFTP.c cdrom.c command.c config.c devices.c dhcp.c \
	disks.c dispatch.c dist.c dmenu.c doc.c dos.c floppy.c \
	ftp.c globals.c http.c index.c install.c installUpgrade.c keymap.c \
	label.c main.c makedevs.c media.c menus.c misc.c modules.c \
	mouse.c msg.c network.c nfs.c options.c package.c rsync.c \
	system.c tcpip.c termcap.c ttys.c ufs.c usb.c user.c \
	variable.c ${_wizard} keymap.h countries.h

CFLAGS+= -DUSE_GZIP=1
.if ${MACHINE} == "pc98"
CFLAGS+= -DPC98
.endif
CFLAGS+= -I${.CURDIR}/../../gnu/lib/libdialog -I.

DPADD=	${LIBDIALOG} ${LIBNCURSES} ${LIBUTIL} ${LIBDISK} ${LIBFTPIO}
LDADD=	-ldialog -lncurses -lutil -ldisk -lftpio

#
# When distributions have both UP and SMP kernels sysinstall
# will probe for the number of cpus on the target machine and
# automatically select which is appropriate.  This can be overridden
# through the menus or both kernels can be installed (with the
# most "appropriate" one setup as /boot/kernel).  For now this
# is done for i386 and amd64; for other systems support must be
# added to identify the cpu count if acpi and MPTable probing
# is insufficient.
#
# The unmber of cpus probed is passed through the environment in
# VAR_NCPUS ("ncpus") to scripts.
#
# Note that WITH_SMP is a compile time option that enables the
# builtin menus for the SMP kernel configuration.  If this kernel
# is not built (see release/Makefile) then this should not be
# enabled as sysinstall may try to select an SMP kernel config
# where none is available.  This option should not be needed--we
# should probe for an SMP kernel in the distribution but doing
# that is painful because of media changes and the structure of
# sysinstall so for now it's a priori.
#
.if ${MACHINE} == "i386" || ${MACHINE_ARCH} == "amd64"
SRCS+=	acpi.c biosmptable.c
.if exists(${.CURDIR}/../../sys/${MACHINE}/conf/SMP)
CFLAGS+=-DWITH_SMP	
.endif
DPADD+=	${LIBDEVINFO}
LDADD+=	-ldevinfo
.endif

CLEANFILES=	makedevs.c rtermcap
CLEANFILES+=	keymap.tmp keymap.h countries.tmp countries.h

.if exists(${.CURDIR}/../../share/termcap/termcap.src)
RTERMCAP=	TERMCAP=${.CURDIR}/../../share/termcap/termcap.src ./rtermcap
.else
RTERMCAP=	./rtermcap
.endif

makedevs.c:	Makefile rtermcap
	echo '#include <sys/types.h>' > makedevs.c
	${RTERMCAP} ansi | \
		file2c 'const char termcap_ansi[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} cons25w | \
		file2c 'const char termcap_cons25w[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} cons25 | \
		file2c 'const char termcap_cons25[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} cons25-m | \
		file2c 'const char termcap_cons25_m[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} cons25r | \
		file2c 'const char termcap_cons25r[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} cons25r-m | \
		file2c 'const char termcap_cons25r_m[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} cons25l1 | \
		file2c 'const char termcap_cons25l1[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} cons25l1-m | \
		file2c 'const char termcap_cons25l1_m[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} vt100 | \
		file2c 'const char termcap_vt100[] = {' ',0};' \
		>> makedevs.c
	${RTERMCAP} xterm | \
		file2c 'const char termcap_xterm[] = {' ',0};' \
		>> makedevs.c

build-tools:	rtermcap

rtermcap:	rtermcap.c
	${CC} -o ${.TARGET} ${.ALLSRC} -ltermcap

.if ${MACHINE} == "pc98"
KEYMAPS= jp.pc98 jp.pc98.iso
.else
KEYMAPS= be.iso bg.bds.ctrlcaps bg.phonetic.ctrlcaps br275.iso \
	ce.iso2 cs.latin2.qwertz danish.iso el.iso07 \
	estonian.cp850 estonian.iso estonian.iso15 finnish.iso fr.iso \
	german.iso gr.elot.acc gr.us101.acc  hr.iso hu.iso2.101keys \
	it.iso icelandic.iso jp.106 latinamerican latinamerican.iso.acc \
	norwegian.iso pl_PL.ISO8859-2 \
	pt.iso ru.koi8-r si.iso sk.iso2 spanish.iso spanish.iso.acc swedish.iso \
	swissfrench.iso \
	swissgerman.iso ua.koi8-u ua.koi8-u.shift.alt uk.iso us.dvorak \
	us.iso us.pc-ctrl us.unix
.endif

keymap.h:
	rm -f keymap.tmp
	for map in ${KEYMAPS} ; do \
		KEYMAP_PATH=${.CURDIR}/../../share/syscons/keymaps \
			kbdcontrol -L $$map | \
			sed -e '/^static accentmap_t/,$$d' >> keymap.tmp ; \
	done
	echo "static struct keymapInfo keymapInfos[] = {" >> keymap.tmp
	for map in ${KEYMAPS} ; do \
		echo -n '	{ "'$$map'", ' >> keymap.tmp ; \
		echo "&keymap_$$map }," | tr '[-.]' '_' >> keymap.tmp ; \
	done
	( echo "	{ NULL, NULL }"; echo "};" ; echo "" ) >> keymap.tmp
	mv keymap.tmp keymap.h

countries.h: ${.CURDIR}/../../share/misc/iso3166
	rm -f countries.tmp
	awk 'BEGIN { \
	    FS = "\t"; \
	    num = 1; \
	    print "DMenu MenuCountry = {"; \
	    print "    DMENU_NORMAL_TYPE | DMENU_SELECTION_RETURNS,"; \
	    print "    \"Country Selection\","; \
	    print "    \"Please choose a country, region, or group.\\n\""; \
	    print "    \"Select an item using [SPACE] or [ENTER].\","; \
	    printf "    NULL,\n    NULL,\n    { "; \
	} \
	/^[[:space:]]*#/ {next;} \
	{if (num > 1) {printf "      ";} \
	    print "{ \"" num "\", \"" $$4 "\"" \
	    ", dmenuVarCheck, dmenuSetCountryVariable" \
	    ", NULL, VAR_COUNTRY \"=" tolower($$1) "\" },"; \
	    ++num;} \
	END {print "      { NULL } }\n};\n";}' < ${.ALLSRC} > countries.tmp
	mv countries.tmp ${.TARGET}

.include <bsd.prog.mk>
