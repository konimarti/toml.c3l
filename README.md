## TOML config parser for C3

Compatible with TOML version [v1.0.0](https://toml.io/en/v1.0.0).

It also comes with a TOML validator CLI tool. The validator tool can be
compiled with `c3c build tomlv`. `tomlv` will validate a TOML config file that
is read from stdin.

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
Config c = toml::from_stream(in)!;
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
can be obtained with `c.get("fruit.color")`. The return value of `Config.get`
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


### Example

```cpp
module app;

import std::io;
import toml;

fn void! main()
{	
	String s = ` 
    # toml config file
	title = "TOML example"
	[database]
	ports = [8000, 8001, 8002]`;

	Config c = toml::from_string(s)!;
	defer c.free();

	io::printfn("title: %s", c.get("title")!);
	io::printfn("ports: %s", c.get("database.ports")!);
}
```
