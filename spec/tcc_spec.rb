require 'spec_helper'
require 'tcc'

describe TCC do
  def compile(code)
    TCC::State.new.compile(code)
  end

  it 'can compile and run' do
    compile('main(){return 42;}').run.should == 42
  end

  it 'can pass argv' do
    compile('s;main(int i,char*argv[]){int s=0;while(i--)s+=atoi(argv[i]);return s;}')
      .run(['10', '20', '30'])
      .should == 60
  end

  it 'raises an error if compile fails' do
    lambda { compile('+') }.should raise_error(TCC::Error)
  end

  it 'allows to call function from Ruby code' do
    f = compile('int f(int a, char*s){return a+atoi(s);}').relocate.get_function('f', [:int, :string], :int)
    f.call(1, '20').should == 21
  end
end
