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

typedef struct {
  long long max_message_size;

  const char *chunk;
  const char *p;
  int cs;
  size_t mark;
  const char *mark_key;
  VALUE mark_message;
  size_t mark_message_size;
  size_t mark_message_content_length;
} parser_state_t;

VALUE cMessage = Qnil;

static void parser_free(parser_state_t *state) {
  // TODO: free memory inside struct!
  xfree(state);
}

static void parser_mark(parser_state_t *state) {
  rb_gc_mark(state->mark_message);
}

static VALUE parser_alloc(VALUE klass) {
  parser_state_t *state = ALLOC(parser_state_t);
  state->mark_message = Qtrue;
  return Data_Wrap_Struct(klass, parser_mark, parser_free, state);
}

static VALUE parser_initialize(int argc, VALUE *argv, VALUE self) {
  VALUE max_message_size;
  // rb_scan_args(argc, argv, "01", &max_message_size);
}

static VALUE parser_message(VALUE self) {
  parser_state_t *state;
  Data_Get_Struct(self, parser_state_t, state);
  return state->mark_message;
}

void Init_c_parser(void) {
  VALUE mStompede = rb_const_get(rb_cObject, rb_intern("Stompede"));
  VALUE mStomp = rb_const_get(mStompede, rb_intern("Stomp"));
  cMessage = rb_const_get(mStomp, rb_intern("Message"));

  VALUE cParser = rb_define_class_under(mStomp, "CParser", rb_cObject);
  rb_define_alloc_func(cParser, parser_alloc);

  rb_define_method(cParser, "initialize", parser_initialize, -1);
  rb_define_method(cParser, "state_check", parser_message, 0);
}
