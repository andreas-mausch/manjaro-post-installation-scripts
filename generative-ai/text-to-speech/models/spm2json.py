#!/usr/bin/env python3
"""Convert a SentencePiece tokenizer.model (Unigram) into HF tokenizer.json.

Only the fields that pockettts.cpp's convert.py inspects are emitted
(model.type, vocab, unk_id, byte_fallback). Needed because the April 2026
kyutai checkpoints ship a SentencePiece tokenizer while convert.py expects
an HF tokenizer.json.
"""
import json, sys
from sentencepiece import sentencepiece_model_pb2 as sp_pb2

src, dst = sys.argv[1], sys.argv[2]
proto = sp_pb2.ModelProto()
with open(src, 'rb') as f:
    proto.ParseFromString(f.read())

vocab = [[p.piece, float(p.score)] for p in proto.pieces]
unk_id = next(i for i, p in enumerate(proto.pieces) if p.piece == '<unk>')
bf = proto.trainer_spec.byte_fallback
print(f"{len(vocab)} pieces, unk_id={unk_id}, byte_fallback={bf}")
if not bf:
    sys.exit("byte_fallback is False - convert.py's assert would fail!")

tok = {
    "version": "1.0",
    "truncation": None, "padding": None, "escaped_whitespace": False,
    "added_tokens": [], "normalizer": None, "pre_tokenizer": None,
    "post_processor": None, "decoder": {"type": "Piece"},
    "model": {"type": "Unigram", "vocab": vocab, "unk_id": unk_id, "byte_fallback": True},
}
with open(dst, 'w', encoding='utf-8') as f:
    json.dump(tok, f, ensure_ascii=False)
print(f"[OK] {dst}")
