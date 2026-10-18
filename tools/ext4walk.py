#!/usr/bin/env python3
# 极简 ext4 只读解析器（用于未挂载的 system.img 等）
# 用法:
#   python3 ext4walk.py system.img              -> 列出根目录
#   python3 ext4walk.py system.img /lib/hw      -> 列出指定路径
import struct, sys


class Ext4:
    def __init__(self, path):
        self.f = open(path, 'rb')
        sb = self.readat(1024, 1024)
        self.magic = struct.unpack_from('<H', sb, 56)[0]
        assert self.magic == 0xEF53, 'not ext4'
        self.inodes_count, self.blocks_count = struct.unpack_from('<II', sb, 0)
        self.log_block_size = struct.unpack_from('<I', sb, 24)[0]
        self.blocks_per_group = struct.unpack_from('<I', sb, 32)[0]
        self.inodes_per_group = struct.unpack_from('<I', sb, 40)[0]
        self.inode_size = struct.unpack_from('<H', sb, 88)[0]
        self.feature_incompat = struct.unpack_from('<I', sb, 96)[0]
        self.desc_size = struct.unpack_from('<H', sb, 254)[0] if self.feature_incompat & 0x80 else 32
        if self.desc_size == 0:
            self.desc_size = 64
        self.block_size = 1024 << self.log_block_size

    def readat(self, off, ln):
        self.f.seek(off)
        return self.f.read(ln)

    def group_desc(self, g):
        base = self.block_size * (2 if self.block_size == 1024 else 1)
        d = self.readat(base + g * self.desc_size, self.desc_size)
        it_lo = struct.unpack_from('<I', d, 8)[0]
        it_hi = struct.unpack_from('<I', d, 40)[0] if self.desc_size >= 64 else 0
        return (it_hi << 32) | it_lo

    def inode(self, n):
        g = (n - 1) // self.inodes_per_group
        idx = (n - 1) % self.inodes_per_group
        it = self.group_desc(g)
        off = it * self.block_size + idx * self.inode_size
        d = self.readat(off, self.inode_size)
        mode = struct.unpack_from('<H', d, 0)[0]
        size = struct.unpack_from('<I', d, 4)[0]
        flags = struct.unpack_from('<I', d, 32)[0]
        blocks = d[40:100]
        return mode, size, flags, blocks

    def extents(self, inode_blocks):
        out = []

        def walk(buf):
            magic, entries, maxe, depth, gen = struct.unpack_from('<HHHHI', buf, 0)
            if magic != 0xF30A:
                return
            for i in range(entries):
                e = buf[12 + i * 12:12 + (i + 1) * 12]
                logical, len_lo, start_hi, start_lo = struct.unpack_from('<IHHI', e, 0)
                ln = len_lo & 0x7FFF
                start = (start_hi << 32) | start_lo
                if depth == 0:
                    out.append((logical, ln, start))
                else:
                    walk(self.readat(start * self.block_size, self.block_size))

        walk(inode_blocks)
        return out

    def read_file(self, n, maxsize=None):
        mode, size, flags, blk = self.inode(n)
        if maxsize:
            size = min(size, maxsize)
        data = b''
        for logical, ln, start in self.extents(blk):
            data += self.readat(start * self.block_size, ln * self.block_size)
        return data[:size]

    def listdir(self, n):
        data = self.read_file(n)
        ents = []
        off = 0
        while off < len(data):
            ino, rec, nlen, ftype = struct.unpack_from('<IHBB', data, off)
            if rec == 0:
                break
            name = data[off + 8:off + 8 + nlen].decode('utf-8', 'replace')
            if ino:
                ents.append((ino, name, ftype))
            off += rec
        return ents

    def find(self, path):
        cur = 2
        for p in [x for x in path.split('/') if x]:
            for ino, n, ft in self.listdir(cur):
                if n == p:
                    cur = ino
                    break
            else:
                return None
        return cur


def main():
    img = Ext4(sys.argv[1])
    path = sys.argv[2] if len(sys.argv) > 2 else '/'
    ino = img.find(path)
    if ino is None:
        print('%s MISSING' % path)
        return
    print('== %s ==' % path)
    for ino, name, ft in sorted(img.listdir(ino), key=lambda x: x[1]):
        tp = {'1': 'f', '2': 'd', '7': 'l'}.get(str(ft), str(ft))
        print('   [%s] %s' % (tp, name))


if __name__ == '__main__':
    main()
