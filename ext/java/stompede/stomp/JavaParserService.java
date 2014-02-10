package stompede.stomp;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyModule;
import org.jruby.runtime.load.BasicLibraryService;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.ObjectAllocator;

public class JavaParserService implements BasicLibraryService {
  public boolean basicLoad(Ruby ruby) {
    RubyModule mStompede = ruby.getModule("Stompede");
    RubyModule mStomp = mStompede.defineModuleUnder("Stomp");
    ruby.defineClassUnder("JavaParser", ruby.getObject(), JAVA_PARSER_ALLOCATOR, mStomp);
    return true;
  }

  private static final ObjectAllocator JAVA_PARSER_ALLOCATOR = new ObjectAllocator() {
    public IRubyObject allocate(Ruby ruby, RubyClass klass) {
      return new JavaParser(ruby, klass);
    }
  };
}
