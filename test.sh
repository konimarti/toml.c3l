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

c3c compile-run ./example/toml-test.c3 . <<EOF
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
