#!/usr/bin/env python3
"""Generate a tiny, deterministic sample PCAP for smoke testing mmt-image.

Writes a classic (little-endian) libpcap file containing a handful of
well-formed Ethernet/IPv4 frames (a DNS query/response and two TCP segments)
so that mmt-probe/mmt-dpi has something real to classify. No external
dependencies — pure stdlib struct packing.

Usage: python3 make-sample-pcap.py [output.pcap]
"""
import struct
import sys

PCAP_MAGIC = 0xA1B2C3D4  # little-endian microsecond-resolution
LINKTYPE_ETHERNET = 1


def ip_checksum(data: bytes) -> int:
    if len(data) % 2:
        data += b"\x00"
    total = 0
    for i in range(0, len(data), 2):
        total += (data[i] << 8) | data[i + 1]
    total = (total >> 16) + (total & 0xFFFF)
    total += total >> 16
    return (~total) & 0xFFFF


def eth(dst: bytes, src: bytes, ethertype: int, payload: bytes) -> bytes:
    return dst + src + struct.pack("!H", ethertype) + payload


def ipv4(src: str, dst: str, proto: int, payload: bytes) -> bytes:
    ver_ihl = 0x45
    tos = 0
    total_len = 20 + len(payload)
    ident = 0
    flags_frag = 0
    ttl = 64
    src_b = bytes(int(x) for x in src.split("."))
    dst_b = bytes(int(x) for x in dst.split("."))
    header = struct.pack(
        "!BBHHHBBH4s4s",
        ver_ihl, tos, total_len, ident, flags_frag, ttl, proto, 0, src_b, dst_b,
    )
    csum = ip_checksum(header)
    header = struct.pack(
        "!BBHHHBBH4s4s",
        ver_ihl, tos, total_len, ident, flags_frag, ttl, proto, csum, src_b, dst_b,
    )
    return header + payload


def udp(sport: int, dport: int, payload: bytes) -> bytes:
    length = 8 + len(payload)
    # checksum 0 is legal for IPv4/UDP
    return struct.pack("!HHHH", sport, dport, length, 0) + payload


def tcp(sport: int, dport: int, seq: int, ack: int, flags: int, payload: bytes) -> bytes:
    offset = (5 << 4)
    return (
        struct.pack("!HHIIBBHHH", sport, dport, seq, ack, offset, flags, 65535, 0, 0)
        + payload
    )


MAC_A = b"\x02\x00\x00\x00\x00\x01"
MAC_B = b"\x02\x00\x00\x00\x00\x02"

# A minimal DNS query for "montimage.eu" and its response.
DNS_Q = (
    b"\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00"
    b"\x09montimage\x02eu\x00\x00\x01\x00\x01"
)
DNS_R = (
    b"\x12\x34\x81\x80\x00\x01\x00\x01\x00\x00\x00\x00"
    b"\x09montimage\x02eu\x00\x00\x01\x00\x01"
    b"\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04\x5d\xb8\xd8\x22"
)

packets = [
    # DNS query  A -> B
    eth(MAC_B, MAC_A, 0x0800, ipv4("10.0.0.1", "10.0.0.2", 17, udp(40000, 53, DNS_Q))),
    # DNS reply  B -> A
    eth(MAC_A, MAC_B, 0x0800, ipv4("10.0.0.2", "10.0.0.1", 17, udp(53, 40000, DNS_R))),
    # TCP SYN    A -> B (port 80)
    eth(MAC_B, MAC_A, 0x0800, ipv4("10.0.0.1", "10.0.0.2", 6, tcp(50000, 80, 1000, 0, 0x02, b""))),
    # TCP SYN-ACK B -> A
    eth(MAC_A, MAC_B, 0x0800, ipv4("10.0.0.2", "10.0.0.1", 6, tcp(80, 50000, 5000, 1001, 0x12, b""))),
    # TCP data with a tiny HTTP GET  A -> B
    eth(MAC_B, MAC_A, 0x0800, ipv4("10.0.0.1", "10.0.0.2", 6,
        tcp(50000, 80, 1001, 5001, 0x18, b"GET / HTTP/1.1\r\nHost: montimage.eu\r\n\r\n"))),
]


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "sample.pcap"
    with open(out, "wb") as f:
        # global header: magic, ver 2.4, thiszone, sigfigs, snaplen, linktype
        f.write(struct.pack("<IHHiIII", PCAP_MAGIC, 2, 4, 0, 0, 262144, LINKTYPE_ETHERNET))
        ts = 1_700_000_000  # fixed timestamp for deterministic output
        for i, pkt in enumerate(packets):
            f.write(struct.pack("<IIII", ts + i, i * 1000, len(pkt), len(pkt)))
            f.write(pkt)
    print(f"wrote {out}: {len(packets)} packets")


if __name__ == "__main__":
    main()
