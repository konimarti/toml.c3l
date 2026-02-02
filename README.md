## TOML parser for C3

A [TOML v1.0.0](https://toml.io/en/v1.0.0) parser and validator for the [C3
programming language](http://c3-lang.org).

* Implements the full TOML v1.0.0 specification.
* Decodes TOML data into structs ([example below](#parse-toml-and-decode-to-struct)).
* Fully passes the official [toml-test suite](https://github.com/toml-lang/toml-test/).
* Includes a command-line TOML validator tool `tomlv` for syntax checking.

### Usage

TOML configuration files can be parsed from a `String`, an `InStream` (e.g.
`File`), or directly from a file path.

Read data from `String s`:
```
TomlData config = toml::from_string(s)!;
```

Read data from `InStream in`:
```
TomlData config = toml::from_stream(in)!;
```

Read data directly from a file path:
```
TomlData config = toml::from_file("test.toml")!;
```

The `toml::from_*` functions accept two additional arguments: a memory
allocator and a flag for error verbosity. The default allocator is `mem`.

To access a configuration value, use `TomlData.get` (or the `[]` operator) with
dotted-key notation.

For example, given:
```cpp
[fruit]
color = 0x3AA832
```
you can read the hex value with:
`config.get("fruit.color");`
or: `config["fruit.color"];`

Both return a pointer of type `std::collections::Object*`.

### Error handling

When parsing errors occur, detailed diagnostics are printed to `stderr`,
including the line, column and error type:

```sh
$ echo "\"a quoted key without a value\"" | build/tomlv
TOML ERROR -- Line 1, Col 31: expected '='
TOML ERROR -- Line 1, Col 31: parser::MISSING_KEYVAL_SEPARATOR
"a quoted key without a value"
                              ^
  Invalid TOML: parser::MISSING_KEYVAL_SEPARATOR
```

Error messages can be silenced by setting the optional `verbose` to `false` in
any of the `toml::from_*` functions.

### Decoding into Structs

Parsed TOML data can be directly decoded into a user-defined struct `MyStruct`using
`toml::decode{MyStruct}`:

```c3
TomlData toml = toml::from_string(s)!!;
MyConfig my_config = toml::decode{MyConfig}(toml)!!;
```

Decoding into arrays is currently only implemented for fixed-sized arrays of
type `Object*`.

For a more detailed example, see below.

### Installation

Add the library as a submodule to your C3 project:

```
git submodule add http://github.com/konimarti/toml.c3l lib
```

Then update your `project.json` to include:

```json
{
    "dependency-search-paths": [ "lib" ],
    "dependencies": [ "toml" ]
}
```

Adjust `dependency-search-paths` if you keep the submodule in a different
directory.

### Running tests

To verify correctness, use the official TOML test suite:

```sh
go install github.com/toml-lang/toml-test/cmd/toml-test@v1.6.0
c3c build tomlv
toml-test -- build/tomlv -j
```

### Examples

#### Parse TOML from String

```c3
module app;

import std::io, toml;

fn void main() => @pool()
{	
    String s = `
    # toml comment
    title = "TOML example"
    [database]
    ports = [8000, 8001, 8002]`;

    TomlData cfg = toml::from_string(s, tmem)!!;

	io::printfn("title: %s", cfg.get("title")!!);
	io::printfn("ports: %s", cfg.get("database.ports")!!);
}
// Output:
// title: "TOML example"
// ports: [8000,8001,8002]

```

#### Parse TOML and decode to struct

```c3
module tomltest;

import std::io, toml;

struct Fruit
{
	String name;
	int    color;
	double price;
	bool   fresh;
}

struct TomlConfig
{
	String title;
	Fruit  fruit;
}

fn void main()
{
	String s = `
	title = "TOML example"

	[fruit]
	name = "apple"
	color = 0xbeef
	price = 1.32
	fresh = true`;

	TomlData toml = toml::from_string(s)!!;
	defer toml.free();

	TomlConfig my_config = toml::decode{TomlConfig}(toml);

	io::printn(my_config);
}
// Output:
// { title: TOML example, fruit: { name: apple, color: 48879, price: 1.320000, fresh: true } }
```
