#!/bin/bash

set -x

./app <<EOF
[[products]]
name = "Hammer"
sku = 738594937

[[products]]  # empty table within the array

[[products]]
name = "Nail"
sku = 284758393

color = "gray"
EOF

./app <<EOF
shipping.cost={boat=100.0, ml="""
hello
world!""""", cabin=0xdead, sell=true}

[basket]
fruit.apply.color = "green" # comment
date = 00-00-00
points = [ { x = 1, y = 2, z = 3 },
           { x = 7, y = 8, z = 9 },
           { x = 2, y = 4, z = 8 } ]
EOF


./app <<EOF
[offset-date-time]
odt1 = 1979-05-27T07:32:00Z
odt2 = 1979-05-27T00:32:00-07:00
odt3 = 1979-05-27T00:32:00.999999-07:00
odt4 = 1979-05-27 07:32:00Z

[local-date-time]
ldt1 = 1979-05-27T07:32:00
ldt2 = 1979-05-27T00:32:00.999999

[local-date]
ld1 = 1979-05-27

[local-time]
lt1 = 07:32:00
lt2 = 00:32:00.999999
EOF

./app <<EOF
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
