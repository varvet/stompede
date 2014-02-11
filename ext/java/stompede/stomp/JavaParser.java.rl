package stompede.stomp;

import org.jruby.Ruby;
import org.jruby.RubyModule;
import org.jruby.RubyClass;
import org.jruby.RubyObject;
import org.jruby.RubyFixnum;
import org.jruby.RubyString;
import org.jruby.exceptions.RaiseException;

import org.jruby.runtime.ThreadContext;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.Block;

import org.jruby.anno.JRubyClass;
import org.jruby.anno.JRubyMethod;

%%{
  machine message;

  action mark {
    mark = p;
  }

  action mark_message {
    mark_message = context.runtime.getClassFromPath("Stompede::Stomp::Message").callMethod("new", context.nil, context.nil);
    /*mark_message_size = 0;*/
  }

  action write_command {
    mark_message.callMethod(context, "write_command", RubyString.newString(context.runtime, data, mark, p - mark));
    mark = -1;
  }

  action mark_key {
    /*mark_key = MARK_STR_NEW();*/
    /*mark = NULL;*/
  }

  action write_header {
    /*rb_funcall(mark_message, g_write_header, 2, mark_key, MARK_STR_NEW());*/
    /*mark_key = Qnil;*/
    /*mark = NULL;*/
  }

  action finish_headers {
    /*VALUE length = rb_funcall(mark_message, g_content_length, 0);*/
    /*if ( ! NIL_P(length)) {*/
    /*  mark_content_length = NUM2LONG(length);*/
    /*} else {*/
    /*  mark_content_length = -1;*/
    /*}*/
  }

  action write_body {
    /*rb_funcall(mark_message, g_write_body, 1, MARK_STR_NEW());*/
    /*mark = NULL;*/
  }

  action consume_null {
    false
    /*((mark_content_length != -1) && (MARK_LEN < mark_content_length))*/
  }

  action consume_octet {
    true
    /*((mark_content_length == -1) || (MARK_LEN < mark_content_length))*/
  }

  action check_message_size {
    /*mark_message_size += 1;*/
    /*if (mark_message_size > max_message_size) {*/
    /*  rb_raise(eMessageSizeExceeded, "");*/
    /*}*/
  }

  action finish_message {
    block.yield(context, mark_message);
    mark_message = null;
  }

  include message_common "parser_common.rl";
}%%

@JRubyClass(name="JavaParser", parent="Object")
public class JavaParser extends RubyObject {
  %% write data noprefix;

  private long maxMessageSize;

  public JavaParser(Ruby runtime, RubyClass klass) {
    super(runtime, klass);
  }

  @JRubyMethod
  public IRubyObject initialize(ThreadContext context) {
    RubyModule mStomp = context.runtime.getClassFromPath("Stompede::Stomp");
    return initialize(context, mStomp.callMethod("max_message_size"));
  }

  @JRubyMethod(argTypes = {RubyFixnum.class})
  public IRubyObject initialize(ThreadContext context, IRubyObject maxMessageSize) {
    this.maxMessageSize = ((RubyFixnum) maxMessageSize).getLongValue();
    return context.nil;
  }

  @JRubyMethod(argTypes = {RubyString.class})
  public IRubyObject parse(ThreadContext context, IRubyObject chunk, Block block) {
    byte data[] = ((RubyString) chunk).getBytes();
    int p = 0;
    int pe = data.length;
    int cs = start;

    IRubyObject mark_message = null;
    int mark = -1;

    %% write exec;

    if (cs == error) {
      // RaiseException error = context.runtime.getClassFromPath("Stompede::Stomp").callMethod("build_parse_error");
      // throw error;
    }

    return context.nil;
  }
}
