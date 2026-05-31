"""M10 candidate compression algorithms.

Contract per algo (a dict entry in ALGOS):
    name      : str
    feasible  : "easy" | "medium" | "hard" | "reference"
    train(bodies)               -> model            (any object; None ok)
    model_size(model)           -> int  (bytes shipped to the watch)
    compress(body_str, model)   -> bytes            (the stored/sent blob)
    decompress(blob, model)     -> (bytes, ops)     (FAITHFUL buffer-based decode,
                                                      ops = watchdog cost proxy)

`decompress` must mirror what the Monkey C decoder would do: accumulate into a
bytearray buffer and decode once. `ops` counts the dominant decoder operations
(bit reads, table appends, byte copies) so it is independent of Python speed.

Round-trip gate (in bakeoff.py): decompress(compress(body)) == body utf-8, for ALL N.
"""
import gzip
import zlib
import heapq
from collections import Counter

import zstandard as zstd


# ----------------------------------------------------------------------------
# bit I/O helpers
# ----------------------------------------------------------------------------
class BitWriter:
    def __init__(self):
        self.bits = bytearray()
        self.cur = 0
        self.n = 0

    def write(self, value, nbits):
        for i in range(nbits - 1, -1, -1):
            self.cur = (self.cur << 1) | ((value >> i) & 1)
            self.n += 1
            if self.n == 8:
                self.bits.append(self.cur)
                self.cur = 0
                self.n = 0

    def getvalue(self):
        if self.n:
            self.bits.append(self.cur << (8 - self.n))
            self.cur = 0
            self.n = 0
        return bytes(self.bits)


class BitReader:
    """Bit reader that also counts bit-reads (watchdog op proxy)."""
    def __init__(self, data):
        self.data = data
        self.pos = 0          # bit position
        self.ops = 0

    def read_bit(self):
        byte = self.data[self.pos >> 3]
        bit = (byte >> (7 - (self.pos & 7))) & 1
        self.pos += 1
        self.ops += 1
        return bit

    def read(self, nbits):
        v = 0
        for _ in range(nbits):
            v = (v << 1) | self.read_bit()
        return v


# ----------------------------------------------------------------------------
# canonical Huffman (used by D, E2, and the +Huffman LZSS variant)
# ----------------------------------------------------------------------------
def huff_code_lengths(freqs):
    """freqs: dict symbol->count. Returns dict symbol->code_length (canonical)."""
    if len(freqs) == 1:
        # single symbol -> 1-bit code
        return {list(freqs)[0]: 1}
    heap = [[w, i, sym] for i, (sym, w) in enumerate(freqs.items())]
    heapq.heapify(heap)
    cnt = len(heap)
    lengths = {sym: 0 for sym in freqs}
    nodes = {}  # internal node id -> (left, right)
    next_id = -1
    forest = [(w, i, ("leaf", sym)) for w, i, sym in heap]
    heapq.heapify(forest)
    while len(forest) > 1:
        w1, _, a = heapq.heappop(forest)
        w2, _, b = heapq.heappop(forest)
        nodes[next_id] = (a, b)
        heapq.heappush(forest, (w1 + w2, cnt, ("node", next_id)))
        cnt += 1
        next_id -= 1
    root = forest[0][2]

    def walk(node, depth):
        kind, val = node
        if kind == "leaf":
            lengths[val] = max(1, depth)
        else:
            l, r = nodes[val]
            walk(l, depth + 1)
            walk(r, depth + 1)
    walk(root, 0)
    return lengths


def canonical_codes(lengths):
    """lengths: dict symbol->len. Returns (codes dict sym->(code,len), maxlen)."""
    items = sorted(lengths.items(), key=lambda kv: (kv[1], kv[0]))
    codes = {}
    code = 0
    prev_len = None
    for sym, ln in items:
        if prev_len is not None:
            code = (code + 1) << (ln - prev_len)
        codes[sym] = (code, ln)
        prev_len = ln
    maxlen = max(lengths.values())
    return codes, maxlen


def build_decode_table(lengths):
    """Build a canonical fast-decode structure: for each length, the first code
    and the sorted symbols, mirroring a Monkey C canonical decoder."""
    items = sorted(lengths.items(), key=lambda kv: (kv[1], kv[0]))
    by_len = {}
    code = 0
    prev_len = None
    for sym, ln in items:
        if prev_len is not None:
            code = (code + 1) << (ln - prev_len)
        by_len.setdefault(ln, {"first": None, "syms": []})
        if by_len[ln]["first"] is None:
            by_len[ln]["first"] = code
        by_len[ln]["syms"].append(sym)
        prev_len = ln
    return by_len, max(lengths.values())


def huff_decode_symbol(reader, by_len, maxlen):
    """Read one canonical-Huffman symbol. Mirrors a Monkey C bit-walk."""
    code = 0
    ln = 0
    while ln < maxlen + 1:
        code = (code << 1) | reader.read_bit()
        ln += 1
        info = by_len.get(ln)
        if info is not None and info["first"] is not None:
            offset = code - info["first"]
            if 0 <= offset < len(info["syms"]):
                return info["syms"][offset]
    raise ValueError("bad huffman stream")


# ----------------------------------------------------------------------------
# A. raw UTF-8
# ----------------------------------------------------------------------------
def raw_train(bodies):
    return None

def raw_compress(body, model):
    return body.encode("utf-8")

def raw_decompress(blob, model):
    return bytes(blob), len(blob)


# ----------------------------------------------------------------------------
# B. gzip / zlib+dict (reference)
# ----------------------------------------------------------------------------
def gzip_compress(body, model):
    return gzip.compress(body.encode("utf-8"), compresslevel=9)

def gzip_decompress(blob, model):
    out = gzip.decompress(blob)
    return out, len(out)


def zlibdict_train(bodies):
    # zlib dictionary is a <=32KB prefix; build from common content (concat heads).
    buf = bytearray()
    for b in bodies:
        buf += b.encode("utf-8")
        if len(buf) >= 32768:
            break
    return bytes(buf[-32768:])

def zlibdict_compress(body, model):
    c = zlib.compressobj(9, zlib.DEFLATED, -15, 9, zlib.Z_DEFAULT_STRATEGY, model)
    return c.compress(body.encode("utf-8")) + c.flush()

def zlibdict_decompress(blob, model):
    d = zlib.decompressobj(-15, model)
    out = d.decompress(blob) + d.flush()
    return out, len(out)


# ----------------------------------------------------------------------------
# C. zstd + trained dictionary (reference ceiling)
# ----------------------------------------------------------------------------
def zstd_train(bodies, dict_size=65536):
    samples = [b.encode("utf-8") for b in bodies]
    d = zstd.train_dictionary(dict_size, samples)
    return d

def zstd_compress(body, model):
    c = zstd.ZstdCompressor(level=19, dict_data=model)
    return c.compress(body.encode("utf-8"))

def zstd_decompress(blob, model):
    d = zstd.ZstdDecompressor(dict_data=model)
    out = d.decompress(blob)
    return out, len(out)

def zstd_model_size(model):
    return len(model.as_bytes())


# ----------------------------------------------------------------------------
# D. order-0 byte Huffman (corpus-trained canonical table) — FEASIBLE
# ----------------------------------------------------------------------------
EOF = 256

def huffD_train(bodies):
    freqs = Counter()
    for b in bodies:
        freqs.update(b.encode("utf-8"))
    freqs[EOF] = len(bodies)              # one EOF per article
    for s in range(256):
        freqs[s] = freqs.get(s, 0) + 1    # keep table total (rare bytes decodable)
    lengths = huff_code_lengths(dict(freqs))
    codes, _ = canonical_codes(lengths)
    by_len, maxlen = build_decode_table(lengths)
    return {"codes": codes, "by_len": by_len, "maxlen": maxlen, "lengths": lengths}

def huffD_model_size(model):
    # ship one code-length byte per symbol (canonical reconstructs codes).
    return len(model["lengths"])

def huffD_compress(body, model):
    codes = model["codes"]
    w = BitWriter()
    for byte in body.encode("utf-8"):
        c, ln = codes[byte]
        w.write(c, ln)
    c, ln = codes[EOF]
    w.write(c, ln)
    return w.getvalue()

def huffD_decompress(blob, model):
    r = BitReader(blob)
    by_len = model["by_len"]
    maxlen = model["maxlen"]
    out = bytearray()
    while True:
        sym = huff_decode_symbol(r, by_len, maxlen)
        if sym == EOF:
            break
        out.append(sym)
    return bytes(out), r.ops + len(out)


# ----------------------------------------------------------------------------
# byte-level BPE (shared by E1, E2) — FEASIBLE (pure table expansion decode)
# ----------------------------------------------------------------------------
def _bpe_train_tokenizer(bodies, vocab_size):
    from tokenizers import Tokenizer, models, trainers, pre_tokenizers, decoders
    tok = Tokenizer(models.BPE(unk_token=None))
    tok.pre_tokenizer = pre_tokenizers.ByteLevel(add_prefix_space=False)
    tok.decoder = decoders.ByteLevel()
    trainer = trainers.BpeTrainer(
        vocab_size=vocab_size,
        special_tokens=[],
        initial_alphabet=pre_tokenizers.ByteLevel.alphabet(),
        show_progress=False,
    )
    tok.train_from_iterator(bodies, trainer)
    return tok

def _byte_decoder_map():
    # inverse of GPT-2 byte<->unicode map used by tokenizers ByteLevel
    bs = list(range(ord("!"), ord("~") + 1)) + list(range(ord("\xa1"), ord("\xac") + 1)) + \
         list(range(ord("\xae"), ord("\xff") + 1))
    cs = bs[:]
    n = 0
    for b in range(256):
        if b not in bs:
            bs.append(b)
            cs.append(256 + n)
            n += 1
    return {chr(c): b for b, c in zip(bs, cs)}

def bpe_train(bodies, vocab_size):
    tok = _bpe_train_tokenizer(bodies, vocab_size)
    inv = _byte_decoder_map()
    vocab = tok.get_vocab()  # token_str -> id
    id_to_bytes = {}
    for tstr, i in vocab.items():
        id_to_bytes[i] = bytes(inv[ch] for ch in tstr)
    V = len(id_to_bytes)
    nbits = max(1, (V - 1).bit_length())
    return {"tok": tok, "id_to_bytes": id_to_bytes, "V": V, "nbits": nbits}

def bpe_model_size(model):
    # id->bytes expansion table (the only thing the watch needs to decode),
    # stored as concatenated token bytes + one length byte per token.
    return sum(len(v) for v in model["id_to_bytes"].values()) + model["V"]

def _bpe_ids(body, model):
    return model["tok"].encode(body).ids

def _bpe_decode_ids(ids, model):
    table = model["id_to_bytes"]
    out = bytearray()
    ops = 0
    for tid in ids:
        out += table[tid]      # one table-expansion append per token
        ops += 1
    return bytes(out), ops + len(out)

# E1: fixed-width codes
def bpeE1_compress(body, model):
    ids = _bpe_ids(body, model)
    w = BitWriter()
    nbits = model["nbits"]
    w.write(len(ids), 24)              # token count header (<=16M)
    for tid in ids:
        w.write(tid, nbits)
    return w.getvalue()

def bpeE1_decompress(blob, model):
    r = BitReader(blob)
    n = r.read(24)
    nbits = model["nbits"]
    ids = [r.read(nbits) for _ in range(n)]
    out, ops = _bpe_decode_ids(ids, model)
    return out, ops + r.ops

# E2: Huffman over token ids
def bpeE2_train(bodies, vocab_size):
    model = bpe_train(bodies, vocab_size)
    freqs = Counter()
    for b in bodies:
        freqs.update(_bpe_ids(b, model))
    for i in model["id_to_bytes"]:
        freqs[i] = freqs.get(i, 0) + 1
    lengths = huff_code_lengths(dict(freqs))
    codes, _ = canonical_codes(lengths)
    by_len, maxlen = build_decode_table(lengths)
    model["codes"] = codes
    model["by_len"] = by_len
    model["maxlen"] = maxlen
    model["lengths"] = lengths
    return model

def bpeE2_model_size(model):
    # id->bytes table + one code-length byte per token id
    return bpe_model_size(model) + len(model["lengths"])

def bpeE2_compress(body, model):
    ids = _bpe_ids(body, model)
    codes = model["codes"]
    w = BitWriter()
    w.write(len(ids), 24)
    for tid in ids:
        c, ln = codes[tid]
        w.write(c, ln)
    return w.getvalue()

def bpeE2_decompress(blob, model):
    r = BitReader(blob)
    n = r.read(24)
    by_len, maxlen = model["by_len"], model["maxlen"]
    ids = [huff_decode_symbol(r, by_len, maxlen) for _ in range(n)]
    out, ops = _bpe_decode_ids(ids, model)
    return out, ops + r.ops


# ----------------------------------------------------------------------------
# G. LZSS small-window + shared dict (+ optional Huffman) — MEDIUM/HARD
# ----------------------------------------------------------------------------
WINDOW = 4096           # 12-bit offsets
MIN_MATCH = 3
MAX_MATCH = 18          # 4-bit length (3..18)

def lzss_train(bodies, dict_size=4096):
    buf = bytearray()
    for b in bodies:
        buf += b.encode("utf-8")
        if len(buf) >= dict_size:
            break
    return bytes(buf[-dict_size:])

CHAIN_DEPTH = 64        # max candidates examined per position (encoder effort)

def _lzss_tokens(data, dictionary):
    """Greedy LZSS over (dict + data) using a 3-byte hash chain for speed.
    Encoder-side only; the watch merely decodes. Yields ('lit',byte) or
    ('match',off,length)."""
    history = bytearray(dictionary)
    history += data
    base = len(dictionary)
    H = len(history)
    heads = {}                 # 3-byte key -> most recent position
    prev = [-1] * H            # chain: position -> previous position with same key
    tokens = []

    def key_at(p):
        return (history[p] << 16) | (history[p + 1] << 8) | history[p + 2]

    # seed the dictionary positions into the chains
    p = 0
    while p + 3 <= base:
        k = key_at(p)
        prev[p] = heads.get(k, -1)
        heads[k] = p
        p += 1

    i = base
    while i < H:
        best_len = 0
        best_off = 0
        maxl = min(MAX_MATCH, H - i)
        if maxl >= MIN_MATCH:
            k = key_at(i)
            cand = heads.get(k, -1)
            limit = i - WINDOW
            depth = 0
            while cand >= 0 and cand >= limit and depth < CHAIN_DEPTH:
                if history[cand + best_len] == history[i + best_len]:
                    l = 0
                    while l < maxl and history[cand + l] == history[i + l]:
                        l += 1
                    if l > best_len:
                        best_len = l
                        best_off = i - cand
                        if l == maxl:
                            break
                cand = prev[cand]
                depth += 1
        if best_len >= MIN_MATCH:
            tokens.append(("match", best_off, best_len))
            adv = best_len
        else:
            tokens.append(("lit", history[i]))
            adv = 1
        # register the consumed positions into the hash chains
        end = i + adv
        while i < end and i + 3 <= H:
            k = key_at(i)
            prev[i] = heads.get(k, -1)
            heads[k] = i
            i += 1
        i = end
    return tokens

_LZSS_MEMO = {}

def lzss_compress(body, model):
    data = body.encode("utf-8")
    cache_key = (data, model)
    blob = _LZSS_MEMO.get(cache_key)
    if blob is not None:
        return blob
    tokens = _lzss_tokens(data, model)
    w = BitWriter()
    w.write(len(data), 24)            # output length header
    for t in tokens:
        if t[0] == "lit":
            w.write(0, 1)
            w.write(t[1], 8)
        else:
            w.write(1, 1)
            w.write(t[1] - 1, 12)     # offset 1..4096 -> 0..4095
            w.write(t[2] - MIN_MATCH, 4)
    blob = w.getvalue()
    _LZSS_MEMO[cache_key] = blob
    return blob

def lzss_decompress(blob, model):
    r = BitReader(blob)
    n = r.read(24)
    history = bytearray(model)
    base = len(history)
    ops = 0
    while len(history) - base < n:
        flag = r.read_bit()
        if flag == 0:
            history.append(r.read(8))
            ops += 1
        else:
            off = r.read(12) + 1
            ln = r.read(4) + MIN_MATCH
            start = len(history) - off
            for k in range(ln):
                history.append(history[start + k])   # byte copy (overlap-safe)
            ops += ln
    out = bytes(history[base:])
    return out, ops + r.ops

# G+Huffman: entropy-code the LZSS byte stream
def lzssH_train(bodies, dict_size=4096):
    dictionary = lzss_train(bodies, dict_size)
    freqs = Counter()
    for b in bodies:
        blob = lzss_compress(b, dictionary)
        freqs.update(blob)
    for s in range(256):
        freqs[s] = freqs.get(s, 0) + 1
    lengths = huff_code_lengths(dict(freqs))
    codes, _ = canonical_codes(lengths)
    by_len, maxlen = build_decode_table(lengths)
    return {"dict": dictionary, "codes": codes, "by_len": by_len, "maxlen": maxlen, "lengths": lengths}

def lzssH_model_size(model):
    return len(model["dict"]) + len(model["lengths"])

def lzssH_compress(body, model):
    blob = lzss_compress(body, model["dict"])
    codes = model["codes"]
    w = BitWriter()
    w.write(len(blob), 24)
    for byte in blob:
        c, ln = codes[byte]
        w.write(c, ln)
    return w.getvalue()

def lzssH_decompress(blob, model):
    r = BitReader(blob)
    n = r.read(24)
    by_len, maxlen = model["by_len"], model["maxlen"]
    inner = bytearray()
    for _ in range(n):
        inner.append(huff_decode_symbol(r, by_len, maxlen))
    out, ops = lzss_decompress(bytes(inner), model["dict"])
    return out, ops + r.ops


# ----------------------------------------------------------------------------
# registry
# ----------------------------------------------------------------------------
def _const(model):  # default model_size for ref algos with no shipped model
    return 0

ALGOS = [
    dict(name="A raw-utf8", feasible="easy", train=raw_train, model_size=_const,
         compress=raw_compress, decompress=raw_decompress),
    dict(name="B gzip", feasible="reference", train=lambda b: None, model_size=_const,
         compress=gzip_compress, decompress=gzip_decompress),
    dict(name="B zlib+dict32k", feasible="reference", train=zlibdict_train,
         model_size=lambda m: len(m), compress=zlibdict_compress, decompress=zlibdict_decompress),
    dict(name="C zstd+dict64k", feasible="reference", train=lambda b: zstd_train(b, 65536),
         model_size=zstd_model_size, compress=zstd_compress, decompress=zstd_decompress),
    dict(name="D huffman0", feasible="easy", train=huffD_train, model_size=huffD_model_size,
         compress=huffD_compress, decompress=huffD_decompress),
    dict(name="E1 bpe2048-fixed", feasible="easy", train=lambda b: bpe_train(b, 2048),
         model_size=bpe_model_size, compress=bpeE1_compress, decompress=bpeE1_decompress),
    dict(name="E2 bpe2048-huff", feasible="easy", train=lambda b: bpeE2_train(b, 2048),
         model_size=bpeE2_model_size, compress=bpeE2_compress, decompress=bpeE2_decompress),
    dict(name="G lzss+dict", feasible="medium", train=lambda b: lzss_train(b, 4096),
         model_size=lambda m: len(m), compress=lzss_compress, decompress=lzss_decompress),
    dict(name="G lzss+dict+huff", feasible="medium", train=lambda b: lzssH_train(b, 4096),
         model_size=lzssH_model_size, compress=lzssH_compress, decompress=lzssH_decompress),
]
