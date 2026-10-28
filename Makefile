.POSIX:

NAME = tabbed
VERSION = 0.9

# paths
PREFIX = /usr/local
MANPREFIX = ${PREFIX}/share/man
DOCPREFIX = ${PREFIX}/share/doc/${NAME}

# use system flags.
TABBED_CFLAGS = -I/usr/X11R6/include -I/usr/include/freetype2 ${CFLAGS}
TABBED_LDFLAGS = -L/usr/X11R6/lib -lX11 -lfontconfig -lXft ${LDFLAGS}
TABBED_CPPFLAGS = -DVERSION=\"${VERSION}\" -D_DEFAULT_SOURCE -D_XOPEN_SOURCE=700L

# OpenBSD (uncomment)
#TABBED_CFLAGS = -I/usr/X11R6/include -I/usr/X11R6/include/freetype2 ${CFLAGS}

SRC = tabbed.c xembed.c
OBJ = ${SRC:.c=.o}
BIN = ${OBJ:.o=}
MAN1 = ${BIN:=.1}
HDR = arg.h config.def.h
DOC = LICENSE README PATCHES.md
TEST = tests/tabs.c tests/render.c tests/close.c

all: ${BIN}

check: all
	@check_binary=$$(mktemp); trap 'rm -f "$$check_binary"' EXIT HUP INT TERM; \
	${CC} ${TABBED_CFLAGS} ${TABBED_CPPFLAGS} -g -fsanitize=address,undefined \
	-o "$$check_binary" tests/tabs.c ${TABBED_LDFLAGS} \
	-Wl,--wrap=XSetForeground,--wrap=XFillRectangles,--wrap=XCopyArea,--wrap=XFlush \
	-Wl,--wrap=XftTextExtentsUtf8,--wrap=XftDrawCreate,--wrap=XftDrawStringUtf8,--wrap=XftDrawDestroy && "$$check_binary"
	@check_binary=$$(mktemp); trap 'rm -f "$$check_binary"' EXIT HUP INT TERM; \
	${CC} ${TABBED_CFLAGS} ${TABBED_CPPFLAGS} -g -fsanitize=address,undefined \
	-o "$$check_binary" tests/render.c ${TABBED_LDFLAGS} \
	-Wl,--wrap=XConfigureWindow,--wrap=XSendEvent,--wrap=XGetWindowAttributes && "$$check_binary"
	@check_binary=$$(mktemp); trap 'rm -f "$$check_binary"' EXIT HUP INT TERM; \
	${CC} ${TABBED_CFLAGS} ${TABBED_CPPFLAGS} -g -fsanitize=address,undefined \
	-o "$$check_binary" tests/close.c ${TABBED_LDFLAGS} \
	-Wl,--wrap=XGetWMProtocols,--wrap=XSendEvent,--wrap=XKillClient && "$$check_binary"

.c.o:
	${CC} -o $@ -c $< ${TABBED_CFLAGS} ${TABBED_CPPFLAGS}

${OBJ}: config.h

config.h: config.def.h
	cp config.def.h $@

.o:
	${CC} -o $@ $< ${TABBED_LDFLAGS}

clean:
	rm -f ${BIN} ${OBJ} "${NAME}-${VERSION}.tar.gz"

dist: clean
	mkdir -p "${NAME}-${VERSION}"
	cp -fR Makefile ${MAN1} ${DOC} ${HDR} ${SRC} "${NAME}-${VERSION}"
	mkdir -p "${NAME}-${VERSION}/tests"
	cp -f ${TEST} "${NAME}-${VERSION}/tests"
	tar -cf - "${NAME}-${VERSION}" | gzip -c > "${NAME}-${VERSION}.tar.gz"
	rm -rf ${NAME}-${VERSION}

install: all
	# installing executable files.
	mkdir -p "${DESTDIR}${PREFIX}/bin"
	cp -f ${BIN} "${DESTDIR}${PREFIX}/bin"
	for f in ${BIN}; do chmod 755 "${DESTDIR}${PREFIX}/bin/$$f"; done
	# installing doc files.
	mkdir -p "${DESTDIR}${DOCPREFIX}"
	cp -f ${DOC} "${DESTDIR}${DOCPREFIX}"
	# installing manual pages for general commands: section 1.
	mkdir -p "${DESTDIR}${MANPREFIX}/man1"
	for m in ${MAN1}; do sed "s/VERSION/${VERSION}/g" < $$m > "${DESTDIR}${MANPREFIX}/man1/$$m"; done

uninstall:
	# removing executable files.
	for f in ${BIN}; do rm -f "${DESTDIR}${PREFIX}/bin/$$f"; done
	# removing doc files.
	for f in ${DOC}; do rm -f "${DESTDIR}${DOCPREFIX}/$$f"; done
	# removing manual pages.
	for m in ${MAN1}; do rm -f "${DESTDIR}${MANPREFIX}/man1/$$m"; done
	-rmdir "${DESTDIR}${DOCPREFIX}"

.PHONY: all check clean dist install uninstall
