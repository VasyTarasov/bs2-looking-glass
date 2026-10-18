from pathlib import Path
import struct

class Marshal:
    def __init__(self, data):
        self.data, self.pos, self.objects, self.symbols = data, 2, [], []
        assert data[:2] == b'\x04\x08'
    def take(self, n):
        result = self.data[self.pos:self.pos+n]
        assert len(result) == n
        self.pos += n
        return result
    def num(self):
        n = int.from_bytes(self.take(1), 'little', signed=True)
        if n == 0: return 0
        if n > 4: return n-5
        if n < -4: return n+5
        if n > 0: return int.from_bytes(self.take(n), 'little')
        raw = self.take(-n)
        return int.from_bytes(raw + b'\xff'*(4+n), 'little', signed=True)
    def blob(self): return self.take(self.num())
    def register(self, obj):
        self.objects.append(obj)
        return obj
    def read(self):
        t = self.take(1)
        if t == b'0': return None
        if t == b'T': return True
        if t == b'F': return False
        if t == b'i': return self.num()
        if t == b':':
            s = self.blob().decode('utf8', errors='replace')
            self.symbols.append(s)
            return s
        if t == b';': return self.symbols[self.num()]
        if t == b'@': return self.objects[self.num()]
        if t == b'"': return self.register(self.blob())
        if t == b'[':
            result = self.register([])
            for _ in range(self.num()): result.append(self.read())
            return result
        if t == b'I':
            result = self.read()
            for _ in range(self.num()): self.read(); self.read()
            return result
        if t == b'o':
            name = self.read()
            result = self.register({'__class__': name})
            for _ in range(self.num()):
                key = self.read(); result[key] = self.read()
            return result
        if t in (b'{', b'}'):
            result = self.register({'__hash__': []})
            for _ in range(self.num()): result['__hash__'].append([self.read(), self.read()])
            if t == b'}': result['__default__'] = self.read()
            return result
        if t == b'f':
            return self.register(float(self.blob().split(b'\x00',1)[0]))
        if t == b'l':
            sign = self.take(1)
            n = int.from_bytes(self.take(2*self.num()), 'little')
            return self.register(n if sign == b'+' else -n)
        if t == b'u':
            name = self.read()
            return self.register({'__class__':name,'__userdata__':self.blob()})
        raise ValueError(f'Unsupported tag {t!r} at {self.pos-1}')

def clean(value):
    if isinstance(value, bytes): return value.decode('utf8', errors='replace')
    if isinstance(value, list): return [clean(x) for x in value]
    if isinstance(value, dict): return {k:clean(v) for k,v in value.items()}
    return value

class ArchiveReader:
    def __init__(self, path):
        self.path = Path(path)
    def read(self, wanted):
        with self.path.open('rb') as f:
            assert f.read(8)==b'RGSSAD\x00\x03'
            key=(struct.unpack('<I',f.read(4))[0]*9+3)&0xffffffff
            names=[]
            target=None
            while True:
                offset,size,file_key,nlen=[n^key for n in struct.unpack('<4I',f.read(16))]
                if offset==0: break
                assert 0<nlen<4096
                raw=f.read(nlen)
                kb=struct.pack('<I',key)
                name=bytes(b^kb[i%4] for i,b in enumerate(raw)).decode('utf8')
                names.append(name)
                if name.replace('\\','/')==wanted: target=(offset,size,file_key)
            assert target, wanted
            offset,size,file_key=target
            f.seek(offset)
            encrypted=f.read(size)
        result=bytearray(size)
        for i in range(0,size,4):
            kb=struct.pack('<I',file_key)
            for j,b in enumerate(encrypted[i:i+4]): result[i+j]=b^kb[j]
            file_key=(file_key*7+3)&0xffffffff
        return bytes(result)
    
