#include <ruby.h>

#if DEBUG_H
#  define DEBUG(fmt, ...) do { fprintf(stderr, fmt "\n", ##__VA_ARGS__); } while(0)
#else
#  define DEBUG(...)
#endif

#define UNUSED(x) (void)(x)
#define MARK_LEN (p - mark)
#define MARK_STR_NEW() rb_external_str_new(mark, MARK_LEN)

#define true 1
#define false 0

typedef struct {
  VALUE error;

  size_t max_message_size;

  const char *chunk;
  const char *p;
  int cs;
  const char *mark;
  VALUE mark_key;
  VALUE mark_message;
  size_t mark_message_size;
  long mark_content_length;
} parser_state_t;

VALUE mStomp = Qnil;
VALUE cMessage = Qnil;
ID g_new;
ID g_write_command;
ID g_write_header;
ID g_write_body;
ID g_content_length;
ID g_build_parse_error;
ID g_max_message_size;

%%{
  machine message;

  action mark {
    mark = p;
  }

  action mark_message {
    mark_message = rb_funcall(cMessage, g_new, 2, Qnil, Qnil);
    mark_message_size = 0;
  }

  action write_command {
    rb_funcall(mark_message, g_write_command, 1, MARK_STR_NEW());
    mark = NULL;
  }

  action mark_key {
    mark_key = MARK_STR_NEW();
    mark = NULL;
  }

  action write_header {
    rb_funcall(mark_message, g_write_header, 2, mark_key, MARK_STR_NEW());
    mark_key = Qnil;
    mark = NULL;
  }

  action finish_headers {
    VALUE length = rb_funcall(mark_message, g_content_length, 0);
    if ( ! NIL_P(length)) {
      mark_content_length = NUM2LONG(length);
    } else {
      mark_content_length = -1;
    }
  }

  action write_body {
    rb_funcall(mark_message, g_write_body, 1, MARK_STR_NEW());
    mark = NULL;
  }

  action consume_null {
    ((mark_content_length != -1) && (MARK_LEN < mark_content_length))
  }

  action consume_octet {
    ((mark_content_length == -1) || (MARK_LEN < mark_content_length))
  }

  action check_message_size {
    mark_message_size += 1;
  }

  action finish_message {
    rb_yield(mark_message);
    mark_message = Qnil;
  }

  include message_common "parser_common.rl";

  write data noprefix;
}%%

static void parser_free(parser_state_t *state) {
  // TODO: free memory inside struct!
  xfree(state);
}

static void parser_mark(parser_state_t *state) {
  rb_gc_mark(state->error);
  rb_gc_mark(state->mark_key);
  rb_gc_mark(state->mark_message);
}

static VALUE parser_alloc(VALUE klass) {
  parser_state_t *state = ALLOC(parser_state_t);
  return Data_Wrap_Struct(klass, parser_mark, parser_free, state);
}

static VALUE parser_initialize(int argc, VALUE *argv, VALUE self) {
  parser_state_t *state;
  Data_Get_Struct(self, parser_state_t, state);

  VALUE max_message_size;
  rb_scan_args(argc, argv, "01", &max_message_size);

  if (max_message_size == Qnil) {
    max_message_size = rb_funcall(mStomp, g_max_message_size, 0);
  }

  state->error = Qnil;
  state->max_message_size = FIX2LONG(max_message_size);
  state->chunk = NULL;
  state->p = NULL;
  state->cs = start;
  state->mark = NULL;
  state->mark_key = Qnil;
  state->mark_message = Qnil;
  state->mark_message_size = 0;
  state->mark_content_length = 0;

  return self;
}

static VALUE parser_parse(VALUE self, VALUE chunk) {
  parser_state_t *state;
  Data_Get_Struct(self, parser_state_t, state);

  if (NIL_P(state->error)) {
    /*
    if state.chunk
      p = state.chunk.bytesize
      chunk = state.chunk << chunk
    else
      p = 0
    end

    pe = chunk.bytesize # special
    */

    // size_t max_message_size = state->max_message_size;
    const char *p = RSTRING_PTR(chunk);
    const char *pe = p + RSTRING_LEN(chunk);

    int cs = state->cs;
    const char *mark = state->mark;
    VALUE mark_key = state->mark_key;
    VALUE mark_message = state->mark_message;
    size_t mark_message_size = state->mark_message_size;
    long mark_content_length = state->mark_content_length;

    %% write exec;

    /*
    if mark
      state.p = chunk.bytesize
      state.chunk = chunk
    else
      state.p = 0
      state.chunk = nil
    end
    */

    state->cs = cs;
    state->mark = mark;
    state->mark_key = mark_key;
    state->mark_message = mark_message;
    state->mark_message_size = mark_message_size;
    state->mark_content_length = mark_content_length;

    if (cs == error) {
      long index = p - RSTRING_PTR(chunk);
      state->error = rb_funcall(mStomp, g_build_parse_error, 2, chunk, LONG2NUM(index));
    }
  }

  if ( ! NIL_P(state->error)) {
    rb_exc_raise(state->error);
  }

  return Qnil;
}

void Init_c_parser(void) {
  VALUE mStompede = rb_const_get(rb_cObject, rb_intern("Stompede"));

  mStomp = rb_const_get(mStompede, rb_intern("Stomp"));
  cMessage = rb_const_get(mStomp, rb_intern("Message"));

  g_new = rb_intern("new");
  g_write_command = rb_intern("write_command");
  g_write_header = rb_intern("write_header");
  g_write_body = rb_intern("write_body");
  g_content_length = rb_intern("content_length");
  g_build_parse_error = rb_intern("build_parse_error");
  g_max_message_size = rb_intern("max_message_size");

  VALUE cParser = rb_define_class_under(mStomp, "CParser", rb_cObject);
  rb_define_alloc_func(cParser, parser_alloc);

  rb_define_method(cParser, "initialize", parser_initialize, -1);
  rb_define_method(cParser, "parse", parser_parse, 1);
}
