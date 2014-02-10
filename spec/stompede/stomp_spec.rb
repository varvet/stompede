describe Stompede::Stomp::RubyParser do
  it_behaves_like "a stompede parser"
end

if defined?(Stompede::Stomp::CParser)
  describe Stompede::Stomp::CParser do
    it_behaves_like "a stompede parser"
  end
end

if defined?(Stompede::Stomp::JavaParser)
  describe Stompede::Stomp::JavaParser do
    pending "implementation" do
      it_behaves_like "a stompede parser"
    end
  end
end
