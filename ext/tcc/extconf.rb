File.write 'Makefile', <<"EOS"
.PHONY: default clean clean-all install

default: build/lib/libtcc.so clean

clean:
	-cd tcc-0.9.26/ && make clean

clean-all: clean
	-rm -rf build/ tcc-0.9.26/ tcc-0.9.26.tar.bz2

build/lib/libtcc.so: tcc-0.9.26
	cd tcc-0.9.26/ && ./configure --prefix=#{Dir.pwd}/build --disable-static && make install

install:

# In case tcc source does not exist, re-download and patch it.
ifeq ($(wildcard tcc-0.9.26/configure),)
tcc-0.9.26: tcc-0.9.26.patch tcc-0.9.26.tar.bz2
	tar xf tcc-0.9.26.tar.bz2 && patch -d tcc-0.9.26 < tcc-0.9.26.patch

tcc-0.9.26.tar.bz2:
	wget -O $@ http://download.savannah.gnu.org/releases/tinycc/tcc-0.9.26.tar.bz2
endif
EOS
