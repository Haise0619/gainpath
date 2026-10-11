"""Read the bundled TFLite FlatBuffer tensor contract without loading native ML.

Uses only Python's standard library. Runtime adapters must independently verify
the same shapes/types before inference. No inference or biometric data here.
"""
import hashlib
import json
import pathlib
import struct


def inspect(path):
    data = path.read_bytes()
    if data[4:8] != b'TFL3':
        raise ValueError('Not a TFLite FlatBuffer')

    def u32(offset):
        return struct.unpack_from('<I', data, offset)[0]

    def field(table, index):
        vtable = table - struct.unpack_from('<i', data, table)[0]
        length = struct.unpack_from('<H', data, vtable)[0]
        slot = 4 + 2 * index
        delta = struct.unpack_from('<H', data, vtable + slot)[0] if slot < length else 0
        return table + delta if delta else None

    def indirect(offset):
        return offset + u32(offset)

    def vector(table, index, tables=False):
        slot = field(table, index)
        if slot is None:
            return []
        start = indirect(slot)
        return [indirect(start + 4 + 4 * n) if tables else u32(start + 4 + 4 * n)
                for n in range(u32(start))]

    def string(table, index):
        slot = field(table, index)
        if slot is None:
            return ''
        start = indirect(slot)
        return data[start + 4:start + 4 + u32(start)].decode('utf8')

    model = u32(0)
    graph = vector(model, 2, True)[0]
    tensors = vector(graph, 0, True)

    def tensor(index):
        table = tensors[index]
        slot = field(table, 1)
        kind = data[slot] if slot else 0
        return {'index': index, 'name': string(table, 3), 'shape': vector(table, 0),
                'dtype': {0: 'float32', 1: 'float16', 2: 'int32', 3: 'uint8'}.get(kind, str(kind))}

    return {'asset': path.name, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
            'inputs': [tensor(n) for n in vector(graph, 1)],
            'outputs': [tensor(n) for n in vector(graph, 2)]}


if __name__ == '__main__':
    directory = pathlib.Path(__file__).resolve().parents[1] / 'assets' / 'models'
    print(json.dumps([inspect(path) for path in sorted(directory.glob('*.tflite'))], indent=2))
