#include <ruby.h>

#if DEBUG_H
#  define DEBUG(fmt, ...) do { fprintf(stderr, fmt "\n", ##__VA_ARGS__); } while(0)
#else
#  define DEBUG(...)
#endif

#define UNUSED(x) (void)(x)
#define MARK_LEN (p - mark)
#define READ(obj, prop) rb_funcall((obj), rb_intern((prop)), 0)
#define MARK_STR_NEW rb_str_new(mark, MARK_LEN)

#define true 1
#define false 0

%%{
  machine message;

  action mark {
    mark = p;
  }

  action mark_message {
    message = rb_funcall(cMessage, rb_intern("new"), 2, Qnil, Qnil);
    message_size = 0;
  }

  action write_command {
    VALUE command = rb_str_new(mark, p - mark);
    rb_funcall(message, rb_intern("write_command"), 1, command);
    mark = NULL;
  }

  action mark_key {
    mk = MARK_STR_NEW;
    mark = NULL;
  }

  action write_header {
    VALUE value = MARK_STR_NEW;
    mark = NULL;

    rb_funcall(message, rb_intern("write_header"), 2, mk, value);
    mk = Qnil;
  }

  action finish_headers {
    VALUE length = rb_funcall(message, rb_intern("content_length"), 0);
    if (FIXNUM_P(length)) {
      content_length = FIX2LONG(length);
    } else {
      content_length = -1;
    }
  }

  action write_body {
    VALUE body = MARK_STR_NEW;
    mark = NULL;
    rb_funcall(message, rb_intern("write_body"), 1, body);
  }

  action consume_null {
    ((content_length != -1) && (MARK_LEN < content_length))
  }

  action consume_octet {
    ((content_length == -1) || (MARK_LEN < content_length))
  }

  action check_message_size {
    message_size += 1;
    //raise MessageSizeExceeded if message_size > max_message_size
  }

  action finish_message {
    rb_yield(message);
    message = Qnil;
  }

  include message_common "parser_common.rl";

  write data noprefix;
}%%

VALUE cMessage = Qnil;

/* Parse a chunk of data.
 *
 * @param [String] data
 * @param [Parser] state
 * @param [Integer] offset (0)
 *
 * @return [
 */
VALUE stompede_parse(VALUE self, VALUE data, VALUE state, VALUE offset) {
  UNUSED(self);
  UNUSED(state);
  UNUSED(offset);

  char *p = RSTRING_PTR(data) + FIX2LONG(offset);
  char *pe = RSTRING_PTR(data) + RSTRING_LEN(data);
  int cs = READ(state, "current_state");
  char *mark = NULL;

  VALUE message = Qnil;
  VALUE mk = Qnil;
  long content_length = -1;
  long message_size = -1;
  long max_message_size = FIX2LONG(READ(state, "max_message_size"));

  %% write exec;

  return Qnil;
}

void Init_c_parser(void) {
  VALUE mStompede = rb_const_get(rb_cObject, rb_intern("Stompede"));
  VALUE mStomp = rb_const_get(mStompede, rb_intern("Stomp"));
  VALUE cParser = rb_define_class_under(mStomp, "CParser", rb_cObject);

  cMessage = rb_const_get(mStomp, rb_intern("Message"));

  rb_define_singleton_method(cParser, "parse", stompede_parse, 3);
}
