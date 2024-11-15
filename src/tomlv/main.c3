module tomlv;

import std::io;
import toml;

const String USAGE = `
usage: tomlv [-h] [-p]

Validate TOML config files read from stdin.

options:
  -h       show this help message
  -p       print as JSON to stdout
`;

fn void main(String[] args)
{	
	bool verbose;
	foreach (arg : args)
	{
		switch (arg)
		{
			case "-h":
				io::printn(USAGE);
				return;
			case "-p":
				verbose = true;
		}
	}

	Config! c = toml::from_stream(io::stdin());
	if (catch err = c)
	{
		io::eprintfn("  Invalid TOML: %s", err);
		return;
	}
	io::eprintn("\n  TOML file is valid.\n");
	if (verbose) io::printn(c);
	c.free();
}
