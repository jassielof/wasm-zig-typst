//! Minimum supported Typst version: 0.8.0

#set page(height: auto)

== WebAssembly plugin (Zig + typst_wasm_minimal_protocol)

#line(length: 100%)

#let p = plugin("zig-out/bin/hello.wasm")

#{
  assert.eq(str(p.hello()), "*Hello* from `hello.wasm` written in Zig!")
  assert.eq(str(p.echo(bytes("1+2"))), "1+21+2")
  assert.eq(str(p.sum_two(bytes("40"), bytes("2"))), "42")
  assert.eq(str(p.concatenate(bytes("hello"), bytes("world"))), "hello*world")
  assert.eq(str(p.shuffle(bytes("s1"), bytes("s2"), bytes("s3"))), "s3-s1-s2")
  assert.eq(str(p.returns_ok()), "This is an `Ok`")
  // p.returns_err() // Typst reports the plugin error at compile time
}
