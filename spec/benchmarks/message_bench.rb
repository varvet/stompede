require_relative "../bench_helper"

bench("Message#to_str minimal", Stompede::Stomp::Message.new("CONNECT", nil), &:to_str)
bench("Message#to_str with headers", Stompede::Stomp::Message.new("CONNECT", { "heart-beat" => "0,0" }, nil), &:to_str)
bench("Message#to_str with small body", Stompede::Stomp::Message.new("CONNECT", "body"), &:to_str)
bench("Message#to_str with headers and small body", Stompede::Stomp::Message.new("CONNECT", { "content-length" => "4" }, "body"), &:to_str)
