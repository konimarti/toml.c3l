// c3c compile-run . example/toml-unmarshal.c3
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

fn void! main()
{	
	String s = `
	title = "TOML example"

	[fruit]
	name = "apple"
	color = 0xbeef
	price = 1.32
	items = 4
	fresh = true`;

	Config c = toml::from_string(s)!;
	defer c.free();

	TomlConfig t;
	c.@decode(t)!;
	
	io::printn(t);
}
