## TOML config parser for C3

Compatible with TOML version [v1.0.0](https://toml.io/en/v1.0.0).

It also comes with a TOML validator CLI tool. The validator tool can be
compiled from the project root directory with `c3c build cmd/tomlv.c3 *.c3`.
`tomlv` will validate a TOML config file that is read from stdin.

### Usage

TOML config files can be parsed from a `String`, a `InStream` (such as `File`)
or directly from a file name.

Read data from `String s`:
```
Config c = toml::from_string(s)!;
defer c.free();
```

Read data from `InStream in`:
```
File f = file::open("test.toml", "r")!;
..
Config c = toml::from_stream(&f)!;
defer c.free();
```

Read data directly from a file name:
```
Config c = toml::from_file("test.toml")!;
defer c.free();
```

To obtain a config value from the TOML tables, use the `Config.get` funtion and
provide the table and value names in a dotted-key notation.

For example, the `color` value from the TOML config
```cpp
[fruit]
color = 0x3AA832
```
can be obtained with `c.get("fruit.color")`.

Note that the return value from `Config.get` is a `std::collections::Object`.


### Example

```cpp
module app;

import std::io;
import toml;

fn void! main()
{	
	String s =
    `# toml config file
	title = "TOML example"
	[database]
	ports = [8000, 8001, 8002]`;

	Config c = toml::from_string(s)!;
	defer c.free();

	io::printfn("title: %s", c.get("title")!);
	io::printfn("ports: %s", c.get("database.ports")!);
}
```
