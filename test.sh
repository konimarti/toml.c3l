#!/bin/bash

set -xe

c3c compile-run ./example/toml-test.c3 . <<EOF
shipping.cost={boat=100.0, ml="""
hello
world!""""", cabin=0xdead, sell=true}

[basket]
fruit.apply.color = [1.2, 'literal', "quotedstring", true, [1 #shesd
	,2
		# comment
		,3,]]
date = 00-00-00
points = [ { x = 1, y = 2, z = 3 },
           { x = 7, y = 8, z = 9 },
           { x = 2, y = 4, z = 8 } ]
EOF

c3c compile-run ./example/toml-test.c3 . <<EOF
[[products]]
name = "Hammer"
sku = 738594937

[[products]]  # empty table within the array

[[products]]
name = "Nail"
sku = 284758393

color = "gray"
EOF
