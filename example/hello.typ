#set page(height: auto)

== A WebAssembly plugin for Typst

#line(length: 100%)

#emph[Typst is capable of interfacing with plugins compiled to WebAssembly.]

#line(length: 100%)

#let p = plugin("zig-out/bin/hello.wasm")

#eval(str(p.hello()), mode: "markup")

#eval(str(p.echo(bytes("1+2"))), mode: "code")
