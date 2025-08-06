module tomltest;

import std::io;
import toml;

fn void main() => @assert_leak(true)
{
	String s =
	`# toml config file
	title = "TOML example"

	[database]
	ports = [8000, 8001, 8002]`;

	TomlData td = toml::from_string(s)!!;
	defer td.free();

	io::printfn("title: %s", td["title"]!!);
	io::printfn("ports: %s", td["database.ports"]!!);
}
