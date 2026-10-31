"""Ruby Marshal writer restricted to the mod's primitive factual catalogs."""
from install import number
from archive_reader import Marshal
import math

def decode(v):
    if isinstance(v,bytes):return v.decode('utf8')
    if isinstance(v,list):return [decode(x) for x in v]
    if isinstance(v,dict) and '__hash__' in v:return {decode(k):decode(x) for k,x in v['__hash__']}
    if isinstance(v,dict):return {k:decode(x) for k,x in v.items()}
    return v

def read(data):
    reader=Marshal(data);value=decode(reader.read())
    if reader.pos!=len(data):raise ValueError('Trailing Marshal data')
    return value

class Writer:
    def __init__(self):self.objects=0;self.strings={}
    def dump(self,v):
        if v is None:return b'0'
        if v is True:return b'T'
        if v is False:return b'F'
        if isinstance(v,int):return b'i'+number(v)
        if isinstance(v,str):
            raw=v.encode('utf8')
            if raw in self.strings:return b'@'+number(self.strings[raw])
            self.strings[raw]=self.objects;self.objects+=1
            return b'"'+number(len(raw))+raw
        if isinstance(v,float):
            if not math.isfinite(v):raise ValueError('Non-finite catalog number')
            self.objects+=1;raw=repr(v).encode('ascii');return b'f'+number(len(raw))+raw
        if isinstance(v,list):self.objects+=1;return b'['+number(len(v))+b''.join(self.dump(x) for x in v)
        if isinstance(v,dict):self.objects+=1;return b'{'+number(len(v))+b''.join(self.dump(str(k))+self.dump(x) for k,x in v.items())
        raise ValueError('Non-primitive catalog object')

def write(value):return b'\x04\x08'+Writer().dump(value)
