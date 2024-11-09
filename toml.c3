module toml;

import std::io;
import std::collections::object;

fn Object*! read_config(InStream in, Allocator allocator = allocator::heap())
{
	return toml::parser::Parser{}.init(in, allocator).toml();
}

