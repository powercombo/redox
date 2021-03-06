PREFIX=$(ROOT)/prefix

PREFIX_BINUTILS_PATH=$(PREFIX)/binutils-install/bin
PREFIX_FREESTANDING_PATH=$(PREFIX_BINUTILS_PATH):$(PREFIX)/gcc-freestanding-install/bin
PREFIX_PATH=$(PREFIX_BINUTILS_PATH):$(PREFIX)/gcc-install/bin

prefix: $(PREFIX)/gcc-install
	touch "$@"

$(PREFIX)/binutils.tar.bz2:
	mkdir -p "$(@D)"
	wget -O $@.partial "https://gitlab.redox-os.org/redox-os/binutils-gdb/-/archive/master/binutils-gdb-master.tar.bz2"
	mv $@.partial $@

$(PREFIX)/binutils: $(PREFIX)/binutils.tar.bz2
	mkdir -p "$@.partial"
	tar --extract --file "$<" --directory "$@.partial" --strip-components=1
	mv "$@.partial" "$@"
	touch "$@"

$(PREFIX)/binutils-install: $(PREFIX)/binutils
	rm -rf "$<-build" "$@"
	mkdir -p "$<-build" "$@"
	cd "$<-build" && \
	"$</configure" --target="$(TARGET)" --disable-werror --prefix="$@" && \
	make all -j `nproc` && \
	make install -j `nproc`
	touch "$@"

$(PREFIX)/gcc.tar.bz2:
	mkdir -p "$(@D)"
	wget -O $@.partial "https://gitlab.redox-os.org/redox-os/gcc/-/archive/redox/gcc-redox.tar.bz2"
	mv "$@.partial" "$@"

$(PREFIX)/gcc: $(PREFIX)/gcc.tar.bz2
	mkdir -p "$@.partial"
	tar --extract --file "$<" --directory "$@.partial" --strip-components=1
	cd "$@.partial" && ./contrib/download_prerequisites
	mv "$@.partial" "$@"
	touch "$@"

$(PREFIX)/gcc-freestanding-install: $(PREFIX)/gcc
	rm -rf "$<-freestanding-build" "$@"
	mkdir -p "$<-freestanding-build" "$@"
	cd "$<-freestanding-build" && \
	export PATH="$(PREFIX_BINUTILS_PATH):$$PATH" && \
	"$</configure" --target="$(TARGET)" --prefix="$@" --disable-nls --enable-languages=c,c++ --without-headers && \
	make all-gcc -j `nproc` && \
	make all-target-libgcc -j `nproc` && \
	make install-gcc -j `nproc` && \
	make install-target-libgcc -j `nproc`
	touch "$@"

$(PREFIX)/relibc-install: $(PREFIX)/binutils-install $(PREFIX)/gcc-freestanding-install
	rm -rf "$@"
	cd relibc && \
	export PATH="$(PREFIX_FREESTANDING_PATH):$$PATH" && \
	rustup target add "$(TARGET)" && \
	make all && \
	make DESTDIR="$@/usr" install
	touch "$@"

$(PREFIX)/gcc-install: $(PREFIX)/gcc | $(PREFIX)/relibc-install
	rm -rf "$<-build" "$@"
	mkdir -p "$<-build" "$@"
	cd "$<-build" && \
	export PATH="$(PREFIX_FREESTANDING_PATH):$$PATH" && \
	"$</configure" --target="$(TARGET)" --disable-werror --prefix="$@" --with-sysroot="$(PREFIX)/relibc-install" --disable-nls --enable-languages=c,c++ && \
	make all-gcc -j `nproc` && \
	make all-target-libgcc -j `nproc` && \
	make install-gcc -j `nproc` && \
	make install-target-libgcc -j `nproc` && \
	make all-target-libstdc++-v3 -j `nproc` && \
	make install-target-libstdc++-v3 -j `nproc`
	touch "$@"
