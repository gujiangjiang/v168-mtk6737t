#!/usr/bin/env python3
# 把目录重新打包成 Android initramfs（cpio newc，可 gzip）
# 用法: python3 repack_ramdisk.py <rootdir> <out.cpio[.gz]>
# 说明: uid/gid 归 0, mtime 归 0, 目录条目与符号链接按 lstat 生成, 输出可复现
import os, sys, stat, gzip


def cpio_newc_entry(name, mode, data=b'', ino=0, nlink=1):
    namez = name.encode() + b'\x00'
    hdr = b'070701'
    fields = [ino, mode, 0, 0, nlink, 0, len(data), 0, 0, 0, 0, len(namez), 0]
    hdr += b''.join(b'%08X' % f for f in fields)
    entry = hdr + namez
    entry += b'\x00' * ((4 - len(entry) % 4) % 4)
    entry += data
    entry += b'\x00' * ((4 - len(entry) % 4) % 4)
    return entry


def build(rootdir, outpath):
    entries = []
    ino = 1
    rootdir = os.path.abspath(rootdir)

    def add(path, arcname, mode, data=b''):
        nonlocal ino
        entries.append(cpio_newc_entry(arcname, mode, data, ino=ino))
        ino += 1

    add(rootdir, '.', stat.S_IFDIR | 0o755)
    for dirpath, dirnames, filenames in os.walk(rootdir):
        dirnames.sort()
        filenames.sort()
        for n in dirnames:
            p = os.path.join(dirpath, n)
            rel = './' + os.path.relpath(p, rootdir)
            st = os.lstat(p)
            add(p, rel, stat.S_IFDIR | (st.st_mode & 0o7777))
        for n in filenames:
            p = os.path.join(dirpath, n)
            rel = './' + os.path.relpath(p, rootdir)
            st = os.lstat(p)
            if stat.S_ISLNK(st.st_mode):
                target = os.readlink(p).encode()
                add(p, rel, stat.S_IFLNK | 0o777, target)
            elif stat.S_ISREG(st.st_mode):
                with open(p, 'rb') as f:
                    data = f.read()
                add(p, rel, stat.S_IFREG | (st.st_mode & 0o7777), data)
    entries.append(cpio_newc_entry('TRAILER!!!', 0))
    blob = b''.join(entries)
    if outpath.endswith('.gz'):
        with gzip.GzipFile(outpath, 'wb', compresslevel=9, mtime=0) as f:
            f.write(blob)
    else:
        with open(outpath, 'wb') as f:
            f.write(blob)
    print('%s: %d entries, cpio %d bytes' % (outpath, len(entries) - 1, len(blob)))


if __name__ == '__main__':
    build(sys.argv[1], sys.argv[2])
