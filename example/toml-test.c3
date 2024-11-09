module app;

import std::io;
import toml;

fn void! main()
{
	io::printn(toml::read_config(io::stdin(), allocator::temp()))!;
}
