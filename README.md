# TOML config in C3

Parse TOML config files.

Compatible with TOML version [v1.0.0](https://toml.io/en/v1.0.0).

It also comes with a TOML validator CLI tool `tomlv`. The validator tool can be
compiled from the project root directory with `c3c build cmd/tomlv.c3 *.c3`.
`tomlv` will validate a TOML config file that is read from stdin.

### Usage

TOML config files can be parsed from either a `String` or a `InStream`
variables.

* Read data from `String s`:
```
Config c = toml::from_string(s)!;
defer c.free();
```

* Read data from `InStream in`:
```
Config c = toml::from_stream(in)!;
defer c.free();
```

* Config values can be acces with a dotted key notation.

In the following TOML example config,
```cpp
[fruit]
color = 0x3AA832
```
the `color` value can be obtained with `c.get("fruit.color")`. The get function
returns a `std::collections::Object`.


### Example

```cpp
module app;

import std::io;
import toml;

fn void! main()
{	
	String input = `
	# toml config file
	title = "TOML example"
	[database]
	ports = [8000, 8001, 8002]`;

	Config c = toml::from_string(input)!;
	defer c.free();

	io::printfn("title: %s", c.get("title")!);
	io::printfn("ports: %s", c.get("database.ports")!);
}
```
