module toml;

import std::collections::object;

fn Object*! read_config(String s, Allocator allocator = allocator::heap())
{
	return toml::parser::Parser{}.init(s, allocator).toml();
}

