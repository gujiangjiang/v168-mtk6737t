#!/usr/bin/env python3
# MTK boot/recovery.img 解包工具
# 用法:
#   python3 unpack_bootimg.py boot.img recovery.img   -> 解包到 ./boot_unpacked ./recovery_unpacked
#   python3 unpack_bootimg.py --info boot.img         -> 只打印头部信息，不解包
import struct, sys, os


def open_img(path):
    with open(path, 'rb') as f:
        data = f.read()
    assert data[:8] == b'ANDROID!', 'not android bootimg: %s' % path
    (magic, kernel_size, kernel_addr, ramdisk_size, ramdisk_addr,
     second_size, second_addr, tags_addr, page_size, header_version,
     os_version, name) = struct.unpack_from('<8sIIIIIIIIII16s', data, 0)
    cmdline = data[64:64 + 512].split(b'\x00')[0].decode('utf-8', 'replace')
    extra = data[608:608 + 1024].split(b'\x00')[0].decode('utf-8', 'replace')
    return dict(data=data, kernel_size=kernel_size, kernel_addr=kernel_addr,
                ramdisk_size=ramdisk_size, ramdisk_addr=ramdisk_addr,
                second_size=second_size, second_addr=second_addr,
                tags_addr=tags_addr, page_size=page_size,
                header_version=header_version, os_version=os_version,
                name=name.split(b'\x00')[0].decode('utf-8', 'replace'),
                cmdline=cmdline, extra=extra)


def info(img):
    print("   kernel_size=0x%x load=0x%x" % (img['kernel_size'], img['kernel_addr']))
    print("   ramdisk_size=0x%x load=0x%x" % (img['ramdisk_size'], img['ramdisk_addr']))
    print("   second_size=0x%x second_addr=0x%x tags=0x%x" % (
        img['second_size'], img['second_addr'], img['tags_addr']))
    print("   page_size=%d header_version=%d os_version=0x%x" % (
        img['page_size'], img['header_version'], img['os_version']))
    print("   name=%s" % img['name'])
    print("   cmdline=%s" % img['cmdline'])
    print("   extra_cmdline=%s" % img['extra'])


def unpack(path, outdir):
    img = open_img(path)
    data = img['data']
    page_size = img['page_size']

    def pages(n):
        return (n + page_size - 1) // page_size

    print("== " + path)
    info(img)
    os.makedirs(outdir, exist_ok=True)
    off = page_size
    kernel = data[off:off + img['kernel_size']]
    off += pages(img['kernel_size']) * page_size
    ramdisk = data[off:off + img['ramdisk_size']]
    off += pages(img['ramdisk_size']) * page_size
    second = data[off:off + img['second_size']]
    off += pages(img['second_size']) * page_size
    open(os.path.join(outdir, 'kernel'), 'wb').write(kernel)
    open(os.path.join(outdir, 'ramdisk'), 'wb').write(ramdisk)
    if second:
        open(os.path.join(outdir, 'second'), 'wb').write(second)
    print("   kernel hdr: %s" % kernel[:20].hex())
    print("   ramdisk hdr: %s" % ramdisk[:8].hex())
    rest = data[off:]
    if rest and not all(b == 0 for b in rest[:2048]):
        open(os.path.join(outdir, 'rest.bin'), 'wb').write(rest)
        print("   rest hdr: %s" % rest[:128].hex())
    print("   total=%d consumed=%d rest=%d" % (len(data), off, len(rest)))


def main():
    args = sys.argv[1:]
    only_info = '--info' in args
    files = [a for a in args if not a.startswith('--')]
    for path in files:
        if only_info:
            print("== " + path)
            info(open_img(path))
        else:
            base = os.path.splitext(os.path.basename(path))[0] + '_unpacked'
            outdir = os.path.join(os.path.dirname(path), base)
            unpack(path, outdir)


if __name__ == '__main__':
    main()
