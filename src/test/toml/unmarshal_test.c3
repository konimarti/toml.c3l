module toml::unmarshal_test;

import toml;

import std::io;
import std::math;
import std::collections::object;

const TOML_DOC = `
	# This is a TOML document

	title = "TOML Example"

	[owner]
	name = "Tom Preston-Werner"
	dob = 1979-05-27T07:32:00-08:00

	[database]
	enabled = true
	ports = [ 8000, 8001, 8002 ]
	#data = [ ["delta", "phi"], [3.14] ]
	temp_targets = { cpu = 79.5, _case = 72.0 }

	[servers]

	[servers.alpha]
	ip = "10.0.0.1"
	role = "frontend"

	[servers.beta]
	ip = "10.0.0.2"
	role = "backend"
`;

struct Server {
	String ip;
	String role;
}

struct Servers {
	Server alpha;
	Server beta;
}

struct Owner
{
	String name;
	String dob;
}

struct Targets
{
	double cpu;
	double _case;
}

struct Database
{
	bool enabled;
	Object*[3] ports;
	Targets temp_targets;
}

struct TomlDoc
{
	String title;
	Owner owner;
	Database database;
	Servers servers;
}

fn void! test_unmarshal_toml_doc() @test
{
	toml::parser::Parser scan;	
	scan.init(TOML_DOC, allocator::temp());
	Object* obj = scan.toml()!;

	TomlDoc t;
	toml::@unmarshal_obj(t, obj)!;

	assert(t.title == "TOML Example");
	assert(t.owner.name == "Tom Preston-Werner");
	assert(t.owner.dob == "1979-05-27T07:32:00-08:00");

	assert(t.database.enabled == true);
	assert(t.database.ports[0].is_int() && t.database.ports[0].i == 8000);
	assert(t.database.ports[1].is_int() && t.database.ports[1].i == 8001);
	assert(t.database.ports[2].is_int() && t.database.ports[2].i == 8002);

	assert(math::abs(t.database.temp_targets.cpu - 79.5) < math::FLOAT_EPSILON);
	assert(math::abs(t.database.temp_targets._case - 72.0) < math::FLOAT_EPSILON);

	assert(t.servers.alpha.ip == "10.0.0.1");
	assert(t.servers.alpha.role == "frontend");

	assert(t.servers.beta.ip == "10.0.0.2");
	assert(t.servers.beta.role == "backend");
}
