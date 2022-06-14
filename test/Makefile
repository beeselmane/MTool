.PHONY: clean, all

BINDIR ?= bin
CFLAGS ?=
CC ?= clang

ALL_TARGETS := launcher target-aarch64 target-x86_64 pid badcode-x86_64 badcode-aarch64 coredump libdylib.dylib dylib_runner libstub_full.dylib libstub.dylib

all: ${BINDIR} $(addprefix ${BINDIR}/, ${ALL_TARGETS}) 
	@echo "Made all"

clean:
	rm -vf $(addprefix ${BINDIR}/, ${ALL_TARGETS}) 
	rmdir "${BINDIR}"

${BINDIR}:
	mkdir -p "${BINDIR}"

${BINDIR}/target-%: target.c
	${CC} ${CFLAGS} --target=$*-apple-darwin -o $@ $< 

${BINDIR}/launcher: launcher.c
	${CC} ${CFLAGS} -o $@ $<

${BINDIR}/pid: pid.c
	${CC} ${CFLAGS} -o $@ $<

${BINDIR}/badcode-%: coredump/badcode.s
	${CC} --target=$*-apple-darwin -o $@ $<
	codesign -s "-" -f --entitlements coredump/coredump.entitlements $@

${BINDIR}/coredump: coredump/coredump.sh
	cp -v $< $@
	chmod +x $@

${BINDIR}/libdylib.dylib: dylib_initializers/dylib_with_initializers.c
	${CC} ${CFLAGS} -dynamiclib  -o $@ -Wl,-install_name -Wl,@executable_path/$(notdir $@) -Wl,-reexport_framework -Wl,Foundation $< 

${BINDIR}/dylib_runner: dylib_initializers/dylib_runner.c ${BINDIR}/libdylib.dylib
	${CC} ${CFLAGS} -L${BINDIR} -ldylib -o $@ $<

${BINDIR}/libstub_full.dylib: stub_dylib.c
	${CC} ${CFLAGS} -dynamiclib -o $@ $<

${BINDIR}/libstub.dylib: ${BINDIR}/libstub_full.dylib
	strip -c -o $@ $<

