module tomlv;

import std::io;
import toml;

fn void main()
{	
	Config! c = toml::from_stream(io::stdin());
	if (catch err = c)
	{
		io::printfn("invalid TOML: %s", err);
		return;
	}
	io::printn("TOML config is valid.");
	c.free();
}
