module app;

import std::io;
import toml;

fn void! main()
{
	toml::scanner::Scanner scan;	
	scan.init(io::stdin(), allocator::temp());
	io::printn(scan.toml()!!);
}
