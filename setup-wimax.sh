#! /bin/bash

ifup wmx0
wimaxcu ron
wimaxcu connect network 51
ifconfig wmx0 131.179.136.196
route add default gw 131.179.136.1
