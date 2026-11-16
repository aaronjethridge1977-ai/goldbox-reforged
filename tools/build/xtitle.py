#!/usr/bin/env python3
"""xtitle.py: prints the names of the top-level windows on $DISPLAY, one per line (libX11 through ctypes;
no python-xlib on the PC). Used by windows_test.sh's smoke test to read the build's window title back."""
import ctypes, ctypes.util, sys

x = ctypes.cdll.LoadLibrary(ctypes.util.find_library("X11") or "libX11.so.6")
x.XOpenDisplay.restype = ctypes.c_void_p
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XDefaultRootWindow.restype = ctypes.c_ulong
x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
x.XQueryTree.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong),
	ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)), ctypes.POINTER(ctypes.c_uint)]
x.XFetchName.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_char_p)]
x.XFree.argtypes = [ctypes.c_void_p]

d = x.XOpenDisplay(None)
if not d:
	sys.exit("no display")


def walk(w, depth):
	name = ctypes.c_char_p()
	if x.XFetchName(d, w, ctypes.byref(name)) and name.value:
		print(name.value.decode("utf-8", "replace"))
	if depth > 2:
		return
	root, parent = ctypes.c_ulong(), ctypes.c_ulong()
	kids, n = ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_uint()
	if x.XQueryTree(d, w, ctypes.byref(root), ctypes.byref(parent), ctypes.byref(kids), ctypes.byref(n)):
		for i in range(n.value):
			walk(kids[i], depth + 1)


walk(x.XDefaultRootWindow(d), 0)
