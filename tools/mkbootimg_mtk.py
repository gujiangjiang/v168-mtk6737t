#!/usr/bin/env python3
# MTK/AOSP v0 bootimg 打包器（本机 MT6737T 参数已预设）
# 用法:
#   python3 mkbootimg_mtk.py --kernel kernel --ramdisk ramdisk.gz --out recovery.img \
#       --cmdline "bootopt=64S3,32N2,32N2" [--name 1505127327]
import struct, hashlib, sys, os, argparse


def parse_int(v):
    return int(v, 0)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--kernel', required=True)
    ap.add_argument('--ramdisk', required=True)
    ap.add_argument('--second', default=None)
    ap.add_argument('--out', required=True)
    ap.add_argument('--page-size', type=parse_int, default=2048)
    ap.add_argument('--kernel-addr', type=parse_int, default=0x40008000)
    ap.add_argument('--ramdisk-addr', type=parse_int, default=0x44000000)
    ap.add_argument('--second-addr', type=parse_int, default=0x40f00000)
    ap.add_argument('--tags-addr', type=parse_int, default=0x4e000000)
    ap.add_argument('--os-version', type=parse_int, default=0)
    ap.add_argument('--header-version', type=parse_int, default=0)
    ap.add_argument('--name', default='')
    ap.add_argument('--cmdline', default='bootopt=64S3,32N2,32N2')
    args = ap.parse_args()

    kernel = open(args.kernel, 'rb').read()
    ramdisk = open(args.ramdisk, 'rb').read()
    second = open(args.second, 'rb').read() if args.second else b''
    page = args.page_size

    def pad(data):
        r = len(data) % page
        return data + (b'\x00' * (page - r) if r else b'')

    sha = hashlib.sha1()
    sha.update(kernel)
    sha.update(struct.pack('I', len(kernel)))
    sha.update(ramdisk)
    sha.update(struct.pack('I', len(ramdisk)))
    sha.update(second)
    sha.update(struct.pack('I', len(second)))
    img_id = sha.digest() + b'\x00' * 12

    name = args.name.encode()[:16].ljust(16, b'\x00')
    cmdline = args.cmdline.encode()[:512].ljust(512, b'\x00')
    header = struct.pack('<8sIIIIIIIIII16s', b'ANDROID!', len(kernel), args.kernel_addr,
                         len(ramdisk), args.ramdisk_addr, len(second), args.second_addr,
                         args.tags_addr, page, args.header_version, args.os_version, name)
    header += cmdline + img_id + b'\x00' * 1024
    header = header.ljust(page, b'\x00')

    out = header + pad(kernel) + pad(ramdisk) + (pad(second) if second else b'')
    with open(args.out, 'wb') as f:
        f.write(out)
    print('wrote %s (%d bytes = %.2f MB), kernel %d, ramdisk %d' % (
        args.out, len(out), len(out) / 1048576, len(kernel), len(ramdisk)))


if __name__ == '__main__':
    main()
