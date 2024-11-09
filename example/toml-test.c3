module app;

import std::io;
import toml;

fn void! main()
{
	toml::parser::Parser p;	
	p.init(io::stdin(), allocator::temp());
	io::printn(p.toml()!!);
}
