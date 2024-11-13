module linter;

import std::io;
import toml;

fn void main()
{	
	Config! c = toml::from_stream(io::stdin());
	if (catch err = c)
	{
		io::printfn("Error: %s", err);
		return;
	}
	io::printn("TOML config file can be parsed.");
	c.free();
}
