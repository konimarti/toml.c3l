# TOML config in C3

Parse TOML config files according to the [toml spec](https://toml.io/en/v1.0.0).

### Install

Add the path to the `toml.c3l` folder to `dependency-search-paths` and
`toml` to `dependencies` in your `project.json` file:

```json
{
    "dependency-search-paths": ["lib", "<path_to_toml.c3l_folder>"],
    "dependencies": ["toml"]
}
```

### Examples

```
c3c compile-run example/toml-test.c3 . <<EOF
# This is a TOML document

title = "TOML Example"

[owner]
name = "Tom Preston-Werner"
dob = 1979-05-27T07:32:00-08:00

[database]
enabled = true
ports = [ 8000, 8001, 8002 ]
data = [ ["delta", "phi"], [3.14] ]
temp_targets = { cpu = 79.5, case = 72.0 }

[servers]

[servers.alpha]
ip = "10.0.0.1"
role = "frontend"

[servers.beta]
ip = "10.0.0.2"
role = "backend"
EOF
```
