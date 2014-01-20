#include <ruby.h>

#if DEBUG_H
#  define DEBUG printf
#else
#  define DEBUG(...) //
#endif

/* Parse a chunk of data.
 *
 * @param [String] data
 * @param [Parser] state
 * @param [Integer] offset (0)
 *
 * @return [
 */
VALUE stompede_parse(VALUE data, VALUE state, VALUE offset) {
  return Qnil;
}

void Init_parser_native(void) {
  VALUE mStompede = rb_const_get(rb_cObject, rb_intern("Stompede"));
  VALUE mStomp = rb_const_get(mStompede, rb_intern("Stomp"));
  VALUE cParser = rb_define_class_under(mStomp, "Parser", rb_cObject);

  // rb_define_singleton_method(cParser, "parse", stompede_parse, 3);
}
