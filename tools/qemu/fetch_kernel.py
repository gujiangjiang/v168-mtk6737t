#!/usr/bin/env python3
# 为 QEMU 本机测试获取通用 ARM32 内核 (Debian stable linux-image-*-armmp)
#   - 从 Debian 索引解析最新 armmp 内核, 下载 .deb 并校验 sha256
#   - 纯标准库 (urllib/lzma/tarfile), macOS/Linux 均可
# 用法: python3 tools/qemu/fetch_kernel.py <cache_dir>
import hashlib
import io
import lzma
import os
import re
import sys
import tarfile
import urllib.request

MIRROR = "https://deb.debian.org/debian"
INDEX = MIRROR + "/dists/stable/main/binary-armhf/Packages.xz"


def fetch(url: str) -> bytes:
    print(">>> 下载", url)
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def pick_entry(idx_bytes: bytes):
    data = lzma.decompress(idx_bytes).decode("utf-8", "ignore")
    best = None
    for block in data.split("\n\n"):
        m = re.search(r"^Package: (linux-image-\d[^\s]*?-armmp)$", block, re.M)
        if not m:
            continue
        name = m.group(1)
        if "-rt-" in name:
            continue
        key = tuple(int(x) for x in re.match(r"linux-image-(\d+)\.(\d+)\.(\d+)", name).groups())
        ver = re.search(r"^Version: (.*)$", block, re.M).group(1)
        fn = re.search(r"^Filename: (.*)$", block, re.M).group(1)
        sha = re.search(r"^SHA256: (.*)$", block, re.M).group(1)
        sz = int(re.search(r"^Size: (.*)$", block, re.M).group(1))
        if best is None or key > best[0]:
            best = (key, name, ver, fn, sha, sz)
    return best


def ar_find(deb: bytes, prefix: bytes):
    if deb[:8] != b"!<arch>\n":
        raise ValueError("不是 ar 归档 (deb 格式异常)")
    off = 8
    while off + 60 <= len(deb):
        hdr = deb[off:off + 60]
        name = hdr[:16].decode("ascii", "replace").strip()
        size = int(hdr[48:58].decode("ascii").strip())
        data = deb[off + 60:off + 60 + size]
        if name.encode().startswith(prefix):
            return name, data
        off += 60 + size + (size & 1)
    return None, None


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("用法: fetch_kernel.py <cache_dir>")
    cache = sys.argv[1]
    os.makedirs(cache, exist_ok=True)
    dest = os.path.join(cache, "vmlinuz-armmp")

    best = pick_entry(fetch(INDEX))
    if not best:
        sys.exit("错误: Debian 索引中未找到 armmp 内核")
    _, name, ver, fn, sha, sz = best
    print(f">>> 选中 {name} {ver} ({sz / 1e6:.1f}MB)")

    deb = fetch(MIRROR + "/" + fn)
    got = hashlib.sha256(deb).hexdigest()
    if got != sha:
        sys.exit(f"错误: sha256 校验失败\n  期望 {sha}\n  实际 {got}")

    member, data = ar_find(deb, b"data.tar")
    if not member:
        sys.exit("错误: deb 中未找到 data.tar")
    if member.endswith(".xz"):
        tar_bytes = lzma.decompress(data)
    elif member.endswith(".gz"):
        import gzip

        tar_bytes = gzip.decompress(data)
    else:
        sys.exit(f"错误: 未支持的 deb 压缩格式 {member} (需要手动处理)")

    tf = tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:")
    for m in tf.getmembers():
        if re.match(r"\./boot/vmlinuz-", m.name):
            f = tf.extractfile(m)
            if f is None:
                continue
            with open(dest, "wb") as out:
                out.write(f.read())
            os.chmod(dest, 0o755)
            print(f">>> 已提取 {m.name} -> {dest}")
            return
    sys.exit("错误: deb 中未找到 vmlinuz")


if __name__ == "__main__":
    main()
