module tomltest;

import std::io;
import toml;

fn void main()
{	
	String s =
	`# toml config file
	title = "TOML example"

	[database]
	ports = [8000, 8001, 8002]`;

	Config c = toml::from_string(s)!!;
	defer c.free();

	io::printfn("title: %s", c.get("title")!!);
	io::printfn("ports: %s", c.get("database.ports")!!);
}
