# TOML parser for C3

A [TOML v1.0.0] parse and validator for the [C3 programming language](http://c3-lang.org)..

* Implements the full TOML v1.0.0 specification.
* Decodes TOML data into structs ([example below](#parse-toml-and-decode-to-struct)).
* Fully passes the official [toml-test suite](https://github.com/toml-lang/toml-test/).
* Includes a command-line TOML validator tool (`tomlv`) for syntax checking.

### Usage

TOML configuration files can be parsed from a `String`, an `InStream` (e.g.
`File`), or directly from a file path.

Read data from `String s`:
```
TomlData td = toml::from_string(s)!;
```

Read data from `InStream in`:
```
TomlData td = toml::from_stream(in)!;
```

Read data directly from a file path:
```
TomlData td = toml::from_file("test.toml")!;
```

To access a configuration value, use `TomlData.get` (or overloaded `[]`
operator) with dotted-key notation.

For example, given:
```cpp
[fruit]
color = 0x3AA832
```
you can read the value with:
`td.get("fruit.color");`
or: `td["fruit.color"];`

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
any `toml::from_*` function.

### Decoding into Structs

Parsed TOML data can directly unmarshalled into a user-defined struct using the 
`TomlData.unmarshal` macro:

```cpp
TomlData td = toml::from_string(s)!!;
defer td.free();

MyConfig config;
td.unmarshal(&config)!!;
```

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
directory..

### Running tests

To verify correctness, use the official TOML test suite:

```sh
go install github.com/toml-lang/toml-test/cmd/toml-test@v1.6.0
c3c build tomlv
toml-test -- build/tomlv -j
```

### Examples

#### Parse TOML from String

```cpp
module app;

import std::io;
import toml;

fn void main()
{	
	String s = ` 
    # toml config file
	title = "TOML example"
	[database]
	ports = [8000, 8001, 8002]`;

	TomlData td = toml::from_string(s)!!;
	defer td.free();

	io::printfn("title: %s", td.get("title")!!);
	io::printfn("ports: %s", td.get("database.ports")!!);
}
// Output:
// title: "TOML example"
// ports: [8000,8001,8002]

```

#### Parse TOML and decode to struct

```cpp
module tomltest;

import std::io;
import toml;

struct Fruit
{
	String name;
	int color;
	double price;
	int items;
	bool fresh;
}

struct TomlConfig
{
	String title;
	Fruit fruit;
}

fn void main()
{	
	String s = `
	title = "TOML example"

	[fruit]
	name = "apple"
	color = 0xbeef
	price = 1.32
	items = 4
	fresh = true`;

	TomlData td = toml::from_string(s)!!;
	defer td.free();

	TomlConfig config;
	td.unmarshal(&config)!!;
	
	io::printn(config);
}
// Output:
// { title: TOML example, fruit: { name: apple, color: 48879, price: 1.320000, items: 4, fresh: true } }
```
