#!/usr/bin/env ruby

require "mkmf"

$CFLAGS << " -ggdb -O0 -Wextra -DDEBUG_H" # only for development

should_build = true
should_build &&= have_header "ruby.h"
should_build &&= defined?(RUBY_ENGINE) && %w[ruby rbx].include?(RUBY_ENGINE)

if should_build
  create_makefile("stompede/stomp/parser_native")
else
  dummy_makefile(".")
end
