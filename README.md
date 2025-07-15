## TOML config parser for C3

Compatible with TOML version [v1.0.0](https://toml.io/en/v1.0.0).

Parsed TOML config can be decoded into user-defined structs using reflection
(see [example](#parse-toml-and-decode-to-struct)).

It also comes with a TOML validator CLI tool. The validator tool can be
compiled with `c3c build tomlv`. `tomlv` will validate a TOML config file that
is read from stdin.

### Usage

TOML config files can be parsed from a `String`, a `InStream` (such as `File`)
or directly from a file name.

Read data from `String s`:
```
TomlData td = toml::from_string(s)!;
defer td.free();
```

Read data from `InStream in`:
```
TomlData td = toml::from_stream(in)!;
defer td.free();
```

Read data directly from a file name:
```
TomlData td = toml::from_file("test.toml")!;
defer td.free();
```

To obtain a config value from the TOML tables, use the `TomlData.get` funtion and
provide the table and value names in a dotted-key notation.

For example, the `color` value from the TOML config
```cpp
[fruit]
color = 0x3AA832
```
can be obtained with `td.get("fruit.color")`. The return value of `TomlData.get`
is a `std::collections::Object`.


### Installation

Clone the repository with
```git clone http://github.com/konimarti/toml.c3l```
to the `./lib` folder of your C3 project and add the following to
`project.json`:

```json
{
    "dependency-search-paths": [ "lib" ],
    "dependencies": [ "toml" ]
}
```

If you didn't clone it into the `lib` folder, adjust your
`dependency-search-paths` accordingly.


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
