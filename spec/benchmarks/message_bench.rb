require_relative "../bench_helper"

bench("Message#to_str minimal", Stompede::Stomp::Message.new("CONNECT", nil), &:to_str)
bench("Message#to_str with headers", Stompede::Stomp::Message.new("CONNECT", { "heart-beat" => "0,0" }, nil), &:to_str)

bench("Message#to_str with small body", Stompede::Stomp::Message.new("CONNECT", "body"), &:to_str)
bench("Message#to_str with headers and small body", Stompede::Stomp::Message.new("CONNECT", { "content-length" => "4" }, "body"), &:to_str)

large_body = "b" * (Stompede::Stomp::Parser.max_message_size - 50) # make room for headers
large_binary = "b\x00" * ((Stompede::Stomp::Parser.max_message_size / 2) - 50) # make room for headers
bench("Message#to_str with large body", Stompede::Stomp::Message.new("CONNECT", large_body), &:to_str)
bench("Message#to_str with headers and large body", Stompede::Stomp::Message.new("CONNECT", { "content-length" => "#{large_binary.bytesize}" }, large_binary), &:to_str)
