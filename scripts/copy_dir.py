import shutil
import sys
import os

if len(sys.argv) != 3:
    print("Usage: copy_dir.py <src> <dst>")
    sys.exit(1)

src = sys.argv[1]
dst = sys.argv[2]

if os.path.exists(dst):
    shutil.rmtree(dst)

shutil.copytree(src, dst, dirs_exist_ok=True)
