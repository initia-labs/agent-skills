import sys
from bech32_utils import bech32_decode, convert_bits

def to_hex(address):
    hrp, data = bech32_decode(address)
    if data is None:
        return "Invalid address"
    decoded = convert_bits(data, 5, 8, False)
    if decoded is None:
        return "Conversion failed"
    return "0x" + bytes(decoded).hex()

if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(to_hex(sys.argv[1]))
    else:
        print("Usage: python3 to_hex.py <address>")
