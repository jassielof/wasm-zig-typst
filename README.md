# typst_wasm_minimal_protocol (Zig)

Small Zig module for Typst plugins.

## Usage

### Dependency

This package is `wasm_minimal_protocol`, and exposes a single module with the same name.

### Examples

- [examples/hello](examples/hello/) — build `hello.wasm`, run `typst compile hello.typ`

```sh
cd examples/hello
zig build
typst compile hello.typ
```

## Credits

- <https://github.com/nimpylib/wasm-minimal-protocol>
- <https://github.com/peterhellberg/typ>
- <https://github.com/typst-community/wasm-minimal-protocol>

## License

See [LICENSE.txt](LICENSE.txt).
