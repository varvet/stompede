package stompede.stomp;

import org.jruby.Ruby;
import org.jruby.RubyClass;
import org.jruby.RubyObject;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;

import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;

@JRubyClass(name="JavaParser", parent="Object")
public class JavaParser extends RubyObject {
  public JavaParser(Ruby runtime, RubyClass klass) {
    super(runtime, klass);
  }

  @JRubyMethod
  public IRubyObject initialize(ThreadContext context) {
    return context.nil;
  }

}
