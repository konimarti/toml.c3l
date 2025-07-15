// c3c compile-run . example/toml-unmarshal.c3
module tomltest;

import std::collections::object;

import std::io;
import toml;

struct Fruit
{
	String name;
	int color;
	double price;
	int items;
	bool fresh;
	Object*[3] ports;
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
	fresh = true
	ports =[ 1, "hello", 3, 4]
	`;

	TomlData td = toml::from_string(s)!!;
	defer td.free();

	TomlConfig config;
	td.unmarshal(&config)!!;

	io::printn(config);
}
