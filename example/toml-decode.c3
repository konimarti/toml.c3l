// c3c compile-run . example/toml-unmarshal.c3
module tomltest;
import std::io, toml, std::collections;

struct Fruit
{
	String name;
	int    color;
	double price;
	int    items;
	bool   fresh;
}

struct TomlConfig
{
	String title;
	Fruit  fruit;
}

fn void main()
{
	String s = `
	title = "TOML example"

	[fruit]
	name = "apple"
	color = 0xbeef
	price = 3.14566437474
	items = 5
	fresh = true`;

	TomlData toml = toml::from_string(s)!!;
	defer toml.free();

	TomlConfig my_config = toml::decode{TomlConfig}(toml)!!;

	io::printn(my_config);
}
