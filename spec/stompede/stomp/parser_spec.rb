describe Stompede::Stomp::RubyParser do
  it_behaves_like "a stompede parser"
end

if defined?(Stompede::Stomp::CParser)
  describe Stompede::Stomp::CParser do
    pending "not implemented" do
      it_behaves_like "a stompede parser"
    end
  end
end
