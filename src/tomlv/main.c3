module tomlv;

import std::io;
import toml;

const String USAGE = `
usage: tomlv [-h] [-j]

Validate TOML config files read from stdin.

options:
  -h       show this help message
  -j       print as tagged JSON to stdout
`;

fn int main(String[] args)
{
	bool json;
	foreach (arg : args)
	{
		switch (arg)
		{
			case "-h":
				io::printn(USAGE);
				return 0;
			case "-j":
				json = true;
		}
	}

	TomlData? td = toml::from_stream(io::stdin());
	if (catch err = td)
	{
		io::eprintfn("  Invalid TOML: %s", err);
		return 1;
	}
	defer td.free();

	if (json)
	{
		io::printn(td);
	}
	else
	{
		io::eprintn("\n  TOML file is valid.\n");
	}

	return 0;
}
