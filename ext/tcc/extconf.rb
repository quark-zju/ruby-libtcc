configure_opts = ["--prefix='#{Dir.pwd}/build'", '--disable-static']

# detect cygwin and find the correct compiler
is_cygwin = RUBY_PLATFORM['cygwin']
if is_cygwin
  gcc_path = ENV['PATH'].split(':').map{|x| Dir["#{x}/{i686-pc-mingw32-gcc,mingw32-gcc}"]}.flatten.first
  raise "Cannot find mingw32-gcc" unless gcc_path
  gcc_prefix = File.basename(gcc_path).gsub(/gcc$/, '')
  configure_opts += ['--enable-cygwin', "--cross-prefix=#{gcc_prefix}"]
end


File.write 'Makefile', <<"EOS"
.PHONY: default clean build clean-all install

default: build clean

clean:
	-@cd tcc-0.9.26/ && make clean

clean-all: clean
	-@rm -rf build/ tcc-0.9.26/ tcc-0.9.26.tar.bz2

build: tcc-0.9.26
	cd tcc-0.9.26/ && ./configure #{configure_opts.join(' ')} && make install
	-@chmod go+x build/lib/libtcc.so build/libtcc/libtcc.so.1.0

install:

# In case tcc source does not exist, re-download and patch it.
ifeq ($(wildcard tcc-0.9.26/configure),)
tcc-0.9.26: tcc-0.9.26.patch tcc-0.9.26.tar.bz2
	tar xf tcc-0.9.26.tar.bz2 && patch -d tcc-0.9.26 < tcc-0.9.26.patch

tcc-0.9.26.tar.bz2:
	wget -O $@ http://download.savannah.gnu.org/releases/tinycc/tcc-0.9.26.tar.bz2
endif
EOS
