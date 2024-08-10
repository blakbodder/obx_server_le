from distutils.core import setup, Extension

setup(name="L2CAP_le", version="1.0",
     ext_modules = [
        Extension("_L2CAP_le" , ["l2cap_le_py.c" ],
        include_dirs = [ "/usr/include/lib/bluetooth" ],
        library_dirs = [ "/usr/lib/arm-linux-gnueabinf" ],
        libraries = [ "bluetooth"] )
     ]
)
