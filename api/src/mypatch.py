import jieba
import jieba.posseg
import pydub.utils
from dowhen import do, goto, when


def mypatch():
    # Fix pydub
    when(
        pydub.utils,
        (299, r"for token in extra_info[stream['index']]:"),
    ).goto((318, r"return info")).do(
        r"""
for token in extra_info[stream['index']]:
    m = re.match(r'([su]([0-9]{1,2})p?) \(([0-9]{1,2}) bit\)$', token)
    m2 = re.match(r'([su]([0-9]{1,2})p?)( \(default\))?$', token)
    if m:
        set_property(stream, 'sample_fmt', m.group(1))
        set_property(stream, 'bits_per_sample', int(m.group(2)))
        set_property(stream, 'bits_per_raw_sample', int(m.group(3)))
    elif m2:
        set_property(stream, 'sample_fmt', m2.group(1))
        set_property(stream, 'bits_per_sample', int(m2.group(2)))
        set_property(stream, 'bits_per_raw_sample', int(m2.group(2)))
    elif re.match(r'(flt)p?( \(default\))?$', token):
        set_property(stream, 'sample_fmt', token)
        set_property(stream, 'bits_per_sample', 32)
        set_property(stream, 'bits_per_raw_sample', 32)
    elif re.match(r'(dbl)p?( \(default\))?$', token):
        set_property(stream, 'sample_fmt', token)
        set_property(stream, 'bits_per_sample', 64)
        set_property(stream, 'bits_per_raw_sample', 64)
"""
    )

    # Fix jieba
    when(
        jieba,
        (44, r're_skip_default = re.compile("(\r\n|\s)", re.U)'),
    ).goto((49, r"def setLogLevel(log_level):")).do(
        r"""
re_han_default = re.compile(r"([\u4E00-\u9FD5a-zA-Z0-9+#&\._%\-]+)", re.U)
re_skip_default = re.compile(r"(\r\n|\s)", re.U)
"""
    )

    # Fix jieba.posseg
    when(
        jieba.posseg,
        (16, r're_skip_detail = re.compile("([\.0-9]+|[a-zA-Z0-9]+)")'),
    ).goto((20, r're_eng = re.compile("[a-zA-Z0-9]+")')).do(
        r"""
re_skip_detail = re.compile(r"([\.0-9]+|[a-zA-Z0-9]+)")
re_han_internal = re.compile(r"([\u4E00-\u9FD5a-zA-Z0-9+#&\._]+)")
re_skip_internal = re.compile(r"(\r\n|\s)")
"""
    )
