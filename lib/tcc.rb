# Modified based on the version generated by ffi-gen.

require 'ffi'

module TCC
  extend FFI::Library

  # Find libtcc.so
  libtcc_path = File.join(File.dirname(caller[0]), '../ext/tcc/build/lib/libtcc.so')
  raise "Can not find libtcc.so. This gem is probably not built probably." unless File.exists?(libtcc_path)
  ffi_lib libtcc_path

  OUTPUT_MEMORY = 0
  OUTPUT_EXE = 1
  OUTPUT_DLL = 2
  OUTPUT_OBJ = 3
  OUTPUT_PREPROCESS = 4

  class Error < RuntimeError; end

  # High-level, OO-style TCCState. Example:
  #
  #   state = TCC::State.new
  #   state.compile_string(code)
  #   state.run
  #   state.destroy
  #
  # Equivalent plain libtcc code:
  #
  #   state = TCC::new
  #   TCC.compile_string(state, code)
  #   TCC.run(state)
  #   TCC.delete(state)
  class State
    DEFAULT_ERROR_CALLBACK = FFI::Function.new(:void, [:pointer, :string], proc {|_, msg| raise TCC::Error, msg})

    def initialize(output_type = TCC::OUTPUT_MEMORY)
      @state = TCC.send :new
      set_output_type output_type
      set_error_func(nil, DEFAULT_ERROR_CALLBACK)
      ObjectSpace.define_finalizer(self, proc { TCC.delete(@state) unless @state.nil? })
    end

    def compile(code)
      compile_string(code)
    end

    def destroy
      TCC.delete @state
      @state = nil
    end

    def get_function(name, param_types = [], return_type = :void)
      FFI::Function.new(return_type, param_types, get_symbol(name))
    end

    def relocate
      relocate_auto
      self
    end

    private

    def self.delegate_to_libtcc(name)
      define_method(name) do |*params|
        raise TCC::Error, 'Cannot reuse a destroyed TCC::State' unless @state
        # Normalize argv for 'run' method
        params = State::normalize_argv(params) if name == :run
        result = TCC.send name, @state, *params
        # Return self sometimes to make chainning possible
        %w(add compile define set undefine).include?(name.to_s.split('_', 2)[0]) ? self : result
      end
    end
    
    def self.normalize_argv(argv)
      return [0, nil] if argv.nil? || argv == []
      argv = argv[0] while argv.is_a?(Array) && argv.size == 1
      if argv.is_a?(Array) && argv.all? {|s| s.is_a?(String)}
        # Convert [String] to FFI::MemoryPointer
        pointer = FFI::MemoryPointer.new(:pointer, argv.size)
        pointer.write_array_of_pointer(argv.map {|arg| FFI::MemoryPointer.from_string(arg.to_s)})
        [argv.size, pointer]
      else
        # Leave it as-is
        argv
      end
    end
  end

  class RawTCCState < FFI::Struct
    layout :dummy, :char
  end
  
  def self.attach_function(name, symbol, param_types, *_)
    begin
      super
      return if param_types.first != RawTCCState || [:delegate, :relocate].include?(name)
      # Add method to TCC::State to make it OO. Note 'delete' should be called via
      # high-level 'destroy' method. 'relocate' is replaced with 'relocate_auto'.
      State.delegate_to_libtcc name
    rescue FFI::NotFoundError => e
      (class << self; self; end).class_eval { define_method(name) { |*_| raise e } }
    end
  end
  
  
  # create a new TCC compilation context
  # 
  # @method new()
  # @return [RawTCCState] 
  # @scope class
  attach_function :new, :tcc_new, [], RawTCCState
  
  # free a TCC compilation context
  # 
  # @method delete(s)
  # @param [RawTCCState] s 
  # @return [nil] 
  # @scope class
  attach_function :delete, :tcc_delete, [RawTCCState], :void
  
  # set CONFIG_TCCDIR at runtime
  # 
  # @method set_lib_path(s, path)
  # @param [RawTCCState] s 
  # @param [String] path 
  # @return [nil] 
  # @scope class
  attach_function :set_lib_path, :tcc_set_lib_path, [RawTCCState, :string], :void
  
  # set error/warning display callback
  # 
  # @method set_error_func(s, error_opaque, error_func)
  # @param [RawTCCState] s 
  # @param [FFI::Pointer(*Void)] error_opaque 
  # @param [FFI::Pointer(*)] error_func 
  # @return [nil] 
  # @scope class
  attach_function :set_error_func, :tcc_set_error_func, [RawTCCState, :pointer, :pointer], :void
  
  # set options as from command line (multiple supported)
  # 
  # @method set_options(s, str)
  # @param [RawTCCState] s 
  # @param [String] str 
  # @return [Integer] 
  # @scope class
  attach_function :set_options, :tcc_set_options, [RawTCCState, :string], :int
  
  # add include path
  # 
  # @method add_include_path(s, pathname)
  # @param [RawTCCState] s 
  # @param [String] pathname 
  # @return [Integer] 
  # @scope class
  attach_function :add_include_path, :tcc_add_include_path, [RawTCCState, :string], :int
  
  # add in system include path
  # 
  # @method add_sysinclude_path(s, pathname)
  # @param [RawTCCState] s 
  # @param [String] pathname 
  # @return [Integer] 
  # @scope class
  attach_function :add_sysinclude_path, :tcc_add_sysinclude_path, [RawTCCState, :string], :int
  
  # define preprocessor symbol 'sym'. Can put optional value
  # 
  # @method define_symbol(s, sym, value)
  # @param [RawTCCState] s 
  # @param [String] sym 
  # @param [String] value 
  # @return [nil] 
  # @scope class
  attach_function :define_symbol, :tcc_define_symbol, [RawTCCState, :string, :string], :void
  
  # undefine preprocess symbol 'sym'
  # 
  # @method undefine_symbol(s, sym)
  # @param [RawTCCState] s 
  # @param [String] sym 
  # @return [nil] 
  # @scope class
  attach_function :undefine_symbol, :tcc_undefine_symbol, [RawTCCState, :string], :void
  
  # add a file (C file, dll, object, library, ld script). Return -1 if error.
  # 
  # @method add_file(s, filename)
  # @param [RawTCCState] s 
  # @param [String] filename 
  # @return [Integer] 
  # @scope class
  attach_function :add_file, :tcc_add_file, [RawTCCState, :string], :int
  
  # compile a string containing a C source. Return -1 if error.
  # 
  # @method compile_string(s, buf)
  # @param [RawTCCState] s 
  # @param [String] buf 
  # @return [Integer] 
  # @scope class
  attach_function :compile_string, :tcc_compile_string, [RawTCCState, :string], :int
  
  # set output type. MUST BE CALLED before any compilation
  # 
  # @method set_output_type(s, output_type)
  # @param [RawTCCState] s 
  # @param [Integer] output_type 
  # @return [Integer] 
  # @scope class
  attach_function :set_output_type, :tcc_set_output_type, [RawTCCState, :int], :int
  
  # equivalent to -Lpath option
  # 
  # @method add_library_path(s, pathname)
  # @param [RawTCCState] s 
  # @param [String] pathname 
  # @return [Integer] 
  # @scope class
  attach_function :add_library_path, :tcc_add_library_path, [RawTCCState, :string], :int
  
  # the library name is the same as the argument of the '-l' option
  # 
  # @method add_library(s, libraryname)
  # @param [RawTCCState] s 
  # @param [String] libraryname 
  # @return [Integer] 
  # @scope class
  attach_function :add_library, :tcc_add_library, [RawTCCState, :string], :int
  
  # add a symbol to the compiled program
  # 
  # @method add_symbol(s, name, val)
  # @param [RawTCCState] s 
  # @param [String] name 
  # @param [FFI::Pointer(*Void)] val 
  # @return [Integer] 
  # @scope class
  attach_function :add_symbol, :tcc_add_symbol, [RawTCCState, :string, :pointer], :int
  
  # output an executable, library or object file. DO NOT call
  #    tcc_relocate() before.
  # 
  # @method output_file(s, filename)
  # @param [RawTCCState] s 
  # @param [String] filename 
  # @return [Integer] 
  # @scope class
  attach_function :output_file, :tcc_output_file, [RawTCCState, :string], :int
  
  # link and run main() function and return its value. DO NOT call
  #    tcc_relocate() before.
  # 
  # @method run(s, argc, argv)
  # @param [RawTCCState] s 
  # @param [Integer] argc 
  # @param [FFI::Pointer(**CharS)] argv 
  # @return [Integer] 
  # @scope class
  attach_function :run, :tcc_run, [RawTCCState, :int, :pointer], :int
  
  # do all relocations (needed before using tcc_get_symbol())
  # 
  # @method relocate(s1, ptr)
  # @param [RawTCCState] s1 
  # @param [FFI::Pointer(*Void)] ptr 
  # @return [Integer] 
  # @scope class
  attach_function :relocate, :tcc_relocate, [RawTCCState, :pointer], :int
  
  # Same as `tcc_relocate(s1, TCC_RELOCATE_AUTO)`
  # 
  # @method relocate_auto(s1)
  # @param [RawTCCState] s1 
  # @return [Integer] 
  # @scope class
  attach_function :relocate_auto, :tcc_relocate_auto, [RawTCCState], :int
  
  # return symbol value or NULL if not found
  # 
  # @method get_symbol(s, name)
  # @param [RawTCCState] s 
  # @param [String] name 
  # @return [FFI::Pointer(*Void)] 
  # @scope class
  attach_function :get_symbol, :tcc_get_symbol, [RawTCCState, :string], :pointer
  
end

