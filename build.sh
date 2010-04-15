#!/bin/bash
gcc server.c -o server `pkg-config --cflags --libs lua5.1` -pthread