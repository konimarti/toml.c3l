module app;

import std::io;
import std::collections::object;

import toml;

fn void! main()
{	Object* cfg = toml::read_config(io::stdin(), allocator::heap())!;
	defer { cfg.free(); }
	io::printn(cfg);
}
