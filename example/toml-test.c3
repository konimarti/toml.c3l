module tomltest;

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
