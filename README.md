libtcc-ruby
===========

[Ruby](http://www.ruby-lang.org/) wrapper for the library provided by [Tiny C Compiler (TCC)](http://bellard.org/tcc/).

Why?
----
Ruby is still slow:

```bash
$ ruby-2.0.0 -rbenchmark -e 'p Benchmark.measure{(1..10000000).inject(:+)}.real'
0.720332997
$ ruby-2.0.0 -rbenchmark -e 'p Benchmark.measure{i, s = 10000000, 0; s, i = s+i, i-1 while i>0}.real'
0.440345689

$ rbx-2.1.1 -rbenchmark -e 'p Benchmark.measure{(1..10000000).inject(:+)}.real'
2.6974117755889893
$ rbx-2.1.1 -rbenchmark -e 'p Benchmark.measure{i, s = 10000000, 0; s, i = s+i, i-1 while i>0}.real'
1.8986756801605225

$ jruby-1.7.3 --fast -rbenchmark -e 'p Benchmark.measure{(1..10000000).inject(:+)}.real'
0.818000078201294
$ jruby-1.7.3 --fast -rbenchmark -e 'p Benchmark.measure{i, s = 10000000, 0; s, i = s+i, i-1 while i > 0}.real'
0.8040001392364502

$ echo 'local i, s = 10000000, 0; while i > 0 do; s, i = s + i, i - 1; end' | time lua-5.2.2
lua  0.42s user 0.00s system 99% cpu 0.429 total
$ echo "local i, s = 10000000, 0; while i > 0 do\ns, i = s + i, i - 1; end" | time luajit-2.0.2
luajit  0.03s user 0.00s system 91% cpu 0.033 total

$ echo 'long s,i=10000001;main(){for(;i--;s+=i);}' | tcc-0.9.26 - && time ./a.out
./a.out  0.07s user 0.00s system 98% cpu 0.071 total

$ echo 'long s,i=10000001;main(){for(;i--;s+=i);}' | gcc-4.8.2 -xc - && time ./a.out
./a.out  0.03s user 0.00s system 96% cpu 0.034 total
$ echo 'long s,i=10000001;main(){for(;i--;s+=i);}' | gcc-4.8.2 -O2 -xc - && time ./a.out
./a.out  0.01s user 0.00s system 83% cpu 0.016 total
```

Although tcc generated code runs slower than gcc, it is much smaller, easier to build, still much faster than Ruby, has the ability to compile and run C code without
writing external files. Besides, libtcc API is simple and friendly so I'd like to start from it.
If you want to use a more powerful compiler like gcc or want to use C++ in Ruby, check [RubyInline](https://github.com/seattlerb/rubyinline). It can compile inline
C/C++ or other language code to standard Ruby libraries (shared objects) storing in a temperatory place, then load and use them.

Requirement
-----------
* ffi 1.9.x
* Ruby 1.9 compatible implementation (MRI Ruby, JRuby, Rubinius, etc.)
* C compiler, make, etc. (Build dependencies)

Installation
------------

```bash
gem install tcc
```

This project ships with a custom version of tcc. So it is not necessary to install libtcc system-wide.

Usage
-----
If you are in a hurry, go to examples below.

To learn about original libtcc API, check [libtcc.h](ext/tcc/tcc-0.9.26/libtcc.h) (It's short!). This project use [ruby-ffi](https://github.com/ffi/ffi) to make
native library and Ruby work together (Tested in MRI Ruby 2.0.0, JRuby 1.7.3 and Rubinius 2.1.1, under Linux). Check [ruby-ffi wiki](https://github.com/ffi/ffi/wiki) for details.

`TCC` has all original libtcc APIs, exposed using ffi interface. However they are C so code directly using them may be strange compared to other Ruby code.
`TCC::State` is built on top of the APIs, which is easier to use. You probably want to use and only use it.

Differences between `TCC::State` and original libtcc API (besides that `TCC::State` is more OO):

* `TCC::State` is more "Object-Oriented".
* `compile` is an alias for `compile_string`. It returns `TCC::State` itself.
* `realloc` doesn't need an argument. It will always allocate and manage memory internally and returns `TCC::State` itself.
* `run` accepts an array of string as `argv` (Using libtcc directly via ffi requires constructing `FFI::Pointer` manually).
* `get_function` makes constructing a `FFI::Function` slightly easier.
* Methods start with `add`, `define`, `set`, `undefine` return current `TCC::State` instead of an integer. This allows methods chainning.
* A custom error handler is registered and `TCC::Error` will be raised on error. So free yourself and just ignore some integer return values :)
* With a finalizer defined, no necessary to manually call `destroy` or `delete` to prevent memory leak.

Examples:

```ruby
require 'tcc'

# A quick one-line example
TCC::State.new.compile('main(){puts("Hello");return 2;}').run
# Hello
# => 2 (`run` returns exit code)


# Macros and runtime arguments
state = TCC::State.new
state.define_symbol('R', 'return r;')
state.compile('r;main(i,s)char**s;{for(;i--;)r+=atoi(s[i]);R}')
state.run(['10', '20', '30', '40']) # => 100
state.destroy # Optionally. Ruby GC can properly free internal memory without this.


# Write the executable to disk instead of keeping it in memory
state = TCC::State.new(TCC::OUTPUT_EXE)
state.compile('main(){puts("Hello");exit(0);}')
state.output_file('a.out')
system './a.out' # Hello


# Define a C function or variable and call or access it from Ruby side
state = TCC::State.new
state.compile 'int c; long plus(long a, char* b) { return a + atol(b) + c; }'
state.relocate # This is necessary before `get_function` or `get_symbol`,
               # but should not be used before `run`. Read libtcc.h for details.
plus = state.get_function 'plus', [:long, :string], :long # Check ffi wiki for available types
plus.call(120, '0800') # => 920
c = state.get_symbol('c') # <FFI::Pointer>
c.read_int # => 0
c.write_int(3)
plus.call(120, '0800') # => 923


# Call Ruby method from C code (using the chainning style)
TCC::State.new \
  .add_symbol('mult', FFI::Function.new(:int, [:int, :int], proc {|a, b| a * b })) \
  .compile('int main() {return mult(2, 3);}').run # => 6


# A longer example, sorting an array of custom struct in C
class Record < FFI::Struct
  layout :id, :int,
         :name, [:char, 28]
end

state = TCC::State.new.compile(<<'!').relocate
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

typedef struct {
  int  id;
  char name[28];
} Record;

static int cmp(const void *p1, const void *p2) {
  int d1 = ((Record*) p1)->id - ((Record*) p2)->id;
  if (d1 != 0) return d1;
  return strcmp(((Record*) p1)->name, ((Record*) p2)->name);
}

void sort_records(Record records[], size_t n) {
  qsort((void*)records, n, sizeof(Record), cmp);
}
!

N = 20
records = FFI::MemoryPointer.new(Record, N)
N.times.map {|i| Record.new(records[i]).tap{|r| r[:id], r[:name] = rand(1..12), "Name-#{rand.to_s[2, 7]}"}}

print_records = proc { puts N.times.map {|i| r = Record.new(records[i]); [r[:id], r[:name]] * "\t"}}

puts 'Unsorted:'
print_records.call
state.get_function('sort_records', [:pointer, :size_t], :void).call(records, N)

puts 'Sorted:'
print_records.call


# TCC::Error is raised if `TCC::State` encounters an error
state = TCC::State.new
state.compile('int a;')
state.compile('int a;') # TCC::Error: <string>:1: error: 'a' defined twice
state.destroy
state.compile('int a;') # TCC::Error: Cannot reuse a destroyed TCC::State


# Use low-level TCC API directly
raw_state = TCC.new
TCC.set_output_type(raw_state, TCC::OUTPUT_MEMORY)
TCC.compile_string raw_state, <<'!'
int main(int argc, char *argv[]) {
    int r = 0, i;
    for (i = 0; i < argc; ++i) r += atoi(argv[i]);
    return r;
}
!
argv = %w(10 20 12)
pointer = FFI::MemoryPointer.new(:pointer, argv.size).tap do |p|
    p.write_array_of_pointer %w(10 20 12).map{|s| FFI::MemoryPointer.from_string(s)}
end
TCC.run(raw_state, argv.size, pointer) # => 42
TCC.compile_string raw_state, 'main(){}' # => -1, indicates an error. No `TCC::Error` raised
pointer.free
TCC.delete(raw_state) # This is necessary
```

Known Issues
------------
Not tested in OS other than Linux yet. Feel free to send pull requests. Also feel free to contact me if you'd
like to have a collaborator access to make big changes or move this project to another place for better maintaince.

License
-------
### libtcc-ruby
libtcc-ruby excluding [the tcc part](ext/tcc/tcc-0.9.26) is licensed under [BSD 3-Clause License](LICENSE).

### tcc
tcc is licensed under [GNU Lesser General Public License](ext/tcc/tcc-0.9.26/COPYING).
