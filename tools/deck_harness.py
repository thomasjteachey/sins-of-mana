"""Headless libretro driver for the Steam Deck's own Snes9x core (runs ON the Deck).

Loads a ROM and a RetroArch save state, plays scripted input, writes screenshots,
serialized states and a per-frame log of the bar code's RAM. Nothing is written
outside the output directory; RetroArch's own files are only read.

Usage (on the Deck):
  python3 deck_harness.py CORE ROM STATE OUTDIR step step ...
Steps:
  up:300          hold buttons (joined with +) for N frames, e.g. a:2, up+a:10
  w60             wait N frames (no buttons)
  shot:name       PNG of the current frame
  save:name       serialized core state (Snes9x snapshot) to OUTDIR/name.s9x
  every:N         also take a PNG every N frames (0 = off)
  castshots:N     while any enemy is casting/acting (state not 01), take a PNG every N frames
  keephate:S=V    every frame, set the hate of the enemy in entity slot S to V (0 = off)
  keeprec:S:OFF=HEX[@N]  every frame (or the next N frames), write the bytes HEX at the record
                  of entity slot S + OFF (hex), e.g. keeprec:1:C5=880008 (stat changes),
                  keeprec:0:92=0000@8 (HP 0 for 8 frames)
  lum:1           also log every frame's mean brightness (and button presses) to OUTDIR/lum.txt
  stats:1         count per frame and summarize at the end (log.txt, "STATS"): sprite builder runs (the
                  bar engine's counter $7E:2840), frames that end in the idle task, frames that end with
                  the controlled character's task waiting for its turn, and how long hit messages
                  (type $40) sit unread in a task's queue
Core options: environment variable HARNESS_OPTS="key=value,key=value" (e.g.
snes9x_overclock_cycles=max); the options the core offers are logged at the start.
"""
import ctypes as C, os, struct, sys, zlib

CORE, ROM, STATE, OUT = sys.argv[1:5]
STEPS = sys.argv[5:]
os.makedirs(OUT, exist_ok=True)
LOG = open(os.path.join(OUT, 'log.txt'), 'w')


def log(msg):
    LOG.write(msg + '\n')
    LOG.flush()


lib = C.CDLL(CORE)

ENV = C.CFUNCTYPE(C.c_bool, C.c_uint, C.c_void_p)
VIDEO = C.CFUNCTYPE(None, C.c_void_p, C.c_uint, C.c_uint, C.c_size_t)
AUDIO = C.CFUNCTYPE(None, C.c_int16, C.c_int16)
AUDIOB = C.CFUNCTYPE(C.c_size_t, C.c_void_p, C.c_size_t)
POLL = C.CFUNCTYPE(None)
STATEF = C.CFUNCTYPE(C.c_int16, C.c_uint, C.c_uint, C.c_uint, C.c_uint)


class GameInfo(C.Structure):
    _fields_ = [('path', C.c_char_p), ('data', C.c_void_p), ('size', C.c_size_t), ('meta', C.c_char_p)]


class Variable(C.Structure):
    _fields_ = [('key', C.c_char_p), ('value', C.c_char_p)]


SYSDIR = C.c_char_p(OUT.encode())
pixfmt = [0]
frame = {'data': None, 'w': 0, 'h': 0, 'pitch': 0}
held = set()
BUTTONS = {'b': 0, 'y': 1, 'select': 2, 'start': 3, 'up': 4, 'down': 5, 'left': 6, 'right': 7,
           'a': 8, 'x': 9, 'l': 10, 'r': 11}


OPTS = dict(kv.split('=', 1) for kv in os.environ.get('HARNESS_OPTS', '').split(',') if '=' in kv)
OPT_VALUES = {k: C.c_char_p(v.encode()) for k, v in OPTS.items()}


def env_cb(cmd, data):
    cmd &= 0xFFFF
    if cmd == 15:                                   # GET_VARIABLE
        var = C.cast(data, C.POINTER(Variable))[0]
        key = var.key.decode() if var.key else ''
        if key in OPT_VALUES:
            C.cast(data, C.POINTER(Variable))[0].value = OPT_VALUES[key].value
            return True
        return False
    if cmd == 52:                                   # GET_CORE_OPTIONS_VERSION: 0 = use SET_VARIABLES
        C.cast(data, C.POINTER(C.c_uint))[0] = 0
        return True
    if cmd == 16:                                   # SET_VARIABLES: log what the core offers
        arr = C.cast(data, C.POINTER(Variable))
        i = 0
        while arr[i].key:
            if b'overclock' in arr[i].key or b'slowdown' in (arr[i].value or b'').lower():
                log('option %s: %s' % (arr[i].key.decode(), (arr[i].value or b'').decode(errors='replace')))
            i += 1
        log('options set: %s' % (OPTS or 'defaults'))
        return True
    if cmd == 10:                                   # SET_PIXEL_FORMAT
        pixfmt[0] = C.cast(data, C.POINTER(C.c_uint))[0]
        return True
    if cmd in (9, 31):                              # GET_SYSTEM_DIRECTORY / GET_SAVE_DIRECTORY
        C.cast(data, C.POINTER(C.c_char_p))[0] = SYSDIR.value
        return True
    if cmd == 3:                                    # GET_CAN_DUPE
        C.cast(data, C.POINTER(C.c_bool))[0] = True
        return True
    if cmd == 17:                                   # GET_VARIABLE_UPDATE
        C.cast(data, C.POINTER(C.c_bool))[0] = False
        return True
    return False


def video_cb(data, w, h, pitch):
    if data:
        frame.update(data=C.string_at(data, pitch * h), w=w, h=h, pitch=pitch)


def input_state_cb(port, device, index, bid):
    return 1 if (port == 0 and device == 1 and bid in held) else 0


cbs = [ENV(env_cb), VIDEO(video_cb), AUDIO(lambda l, r: None), AUDIOB(lambda d, n: n), POLL(lambda: None),
       STATEF(input_state_cb)]
lib.retro_set_environment(cbs[0])
lib.retro_set_video_refresh(cbs[1])
lib.retro_set_audio_sample(cbs[2])
lib.retro_set_audio_sample_batch(cbs[3])
lib.retro_set_input_poll(cbs[4])
lib.retro_set_input_state(cbs[5])
lib.retro_init()
rom = open(ROM, 'rb').read()
rombuf = C.create_string_buffer(rom, len(rom))
gi = GameInfo(ROM.encode(), C.cast(rombuf, C.c_void_p), len(rom), None)
lib.retro_load_game.restype = C.c_bool
assert lib.retro_load_game(C.byref(gi)), 'load_game failed'


def state_mem(path):
    d = open(path, 'rb').read()
    if d[:8] == b'#RZIPv\x01#':
        out, i = bytearray(), 20
        while i < len(d):
            n = struct.unpack('<I', d[i:i + 4])[0]
            out += zlib.decompress(d[i + 4:i + 4 + n])
            i += 4 + n
        d = bytes(out)
    if d[:8] == b'RASTATE\x01':
        i = 8
        while i < len(d):
            cid, size = d[i:i + 4], struct.unpack('<I', d[i + 4:i + 8])[0]
            if cid == b'MEM ':
                return d[i + 8:i + 8 + size]
            i += 8 + size
    return d


mem = state_mem(STATE)
lib.retro_unserialize.restype = C.c_bool
ok = lib.retro_unserialize(C.c_char_p(mem), len(mem))
log('unserialize %s (%d bytes): %s' % (os.path.basename(STATE), len(mem), ok))
lib.retro_get_memory_data.restype = C.c_void_p
lib.retro_get_memory_size.restype = C.c_size_t
WRAM = lib.retro_get_memory_data(2)
WSIZE = lib.retro_get_memory_size(2)
log('wram %x size %d pixfmt %d' % (WRAM or 0, WSIZE, pixfmt[0]))


def rd8(a):
    return C.c_uint8.from_address(WRAM + a).value


def rd16(a):
    return rd8(a) | (rd8(a + 1) << 8)


def png(name):
    if not frame['data']:
        return
    w, h, p, d = frame['w'], frame['h'], frame['pitch'], frame['data']
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        row = d[y * p:y * p + w * (2 if pixfmt[0] == 2 else 4)]
        if pixfmt[0] == 2:
            for x in range(w):
                v = row[2 * x] | (row[2 * x + 1] << 8)
                raw += bytes((((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31))
        else:
            for x in range(w):
                raw += bytes((row[4 * x + 2], row[4 * x + 1], row[4 * x]))

    def chunk(t, b):
        c = struct.pack('>I', len(b)) + t + b
        return c + struct.pack('>I', zlib.crc32(t + b) & 0xFFFFFFFF)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(bytes(raw), 6)) + chunk(b'IEND', b'')
    open(os.path.join(OUT, name + '.png'), 'wb').write(data)


def save(name):
    n = lib.retro_serialize_size()
    buf = C.create_string_buffer(n)
    lib.retro_serialize.restype = C.c_bool
    if lib.retro_serialize(buf, n):
        open(os.path.join(OUT, name + '.s9x'), 'wb').write(buf.raw)


fno = 0
stats_on = False
ST = {'frames': 0, 'builds': 0, 'idle': 0, 'pwait': 0, 'msgs': {}, 'waits': []}
last_counter = None


def frame_stats():
    """Per-frame counters for stats:1 (see the usage)."""
    global last_counter
    ST['frames'] += 1
    c = rd16(0x2840)
    if last_counter is not None:
        ST['builds'] += (c - last_counter) & 0xFFFF
    last_counter = c
    cur = rd16(0x10064)
    if cur and rd8(0x10004 + cur) == 0x02:             # the idle task (id 2) is running
        ST['idle'] += 1
    rec = rd16(0x2040)
    pid = rd8(0x10002 + rec) if rec else None
    live = set()
    for tk in range(0x0C00, 0x0F80, 0x20):
        t = 0x10000 + tk
        if not rd8(t + 2):
            continue
        if pid is not None and rd8(t + 4) == pid and rd8(t + 2) == 0x02:
            ST['pwait'] += 1
        m, n = rd16(t + 0x0C), 0
        while m and n < 40:
            if rd8(0x10003 + m) == 0x40:
                live.add((tk, m))
                ST['msgs'].setdefault((tk, m), fno)
            m, n = rd16(0x10000 + m), n + 1
    for k in [k for k in ST['msgs'] if k not in live]:
        ST['waits'].append(fno - ST['msgs'].pop(k))


def stats_line():
    w = sorted(ST['waits'])
    med = w[len(w) // 2] if w else 0
    p90 = w[int(len(w) * 0.9)] if w else 0
    return ('STATS frames %d, sprite builds %d (%.1f%% frames without), idle at frame end %d, your task '
            'waiting %d, hit messages %d unread for avg %.1f med %d p90 %d max %d frames' %
            (ST['frames'], ST['builds'], 100.0 * max(0, ST['frames'] - ST['builds']) / max(1, ST['frames']),
             ST['idle'], ST['pwait'], len(w), sum(w) / max(1, len(w)), med, p90, w[-1] if w else 0))


every = 0
castshots = 0
keephate = {}
keeprec = []                     # [slot, offset, bytes, frames left (-1 = always)]
last_line = None
lum_on = False
LUM = None


def frame_lum():
    """Mean brightness (0-255) of the last frame, sampled every 8th pixel of every 4th line."""
    w, h, p, d = frame['w'], frame['h'], frame['pitch'], frame['data']
    if not d:
        return -1
    tot = n = 0
    for y in range(0, h, 4):
        o = y * p
        if pixfmt[0] == 2:
            for x in range(0, w, 8):
                v = d[o + 2 * x] | (d[o + 2 * x + 1] << 8)
                tot += ((v >> 11) & 31) * 8 + ((v >> 5) & 63) * 4 + (v & 31) * 8
                n += 3
        else:
            for x in range(0, w, 8):
                tot += d[o + 4 * x] + d[o + 4 * x + 1] + d[o + 4 * x + 2]
                n += 3
    return tot / n


def wr8(a, v):
    C.c_uint8.from_address(WRAM + a).value = v


def frame_log():
    """One line per frame when something changes: entities (side 2) with state and bars."""
    global last_line
    ents = []
    for s in range(16):
        rec = rd16(0x2040 + s * 2)
        if not rec:
            continue
        side = rd8(0x10000 + rec + 1)
        if side != 2:
            continue
        st = rd8(0x10000 + rec)
        hp = rd16(0x10000 + rec + 0x92)
        hate = rd8(0x10000 + rec + 0x120)
        obj = rd16(0x10000 + rec + 4)
        x = rd16(0x10000 + obj + 0x83) if obj else 0
        y = rd16(0x10000 + obj + 0x87) if obj else 0
        cb0, cb1 = rd16(0x2800 + s * 4), rd16(0x2802 + s * 4)   # cast book: timer, steps << 12 | length
        cb = 'out@%04X' % cb1 if cb0 == 0xFFFF else '%04X:T%d/s%d' % (cb0, cb1 & 0xFFF, cb1 >> 12)
        ents.append('s%d st%02X hp%d h%d o%04X %d,%d cb%s' % (s, st, hp, hate, obj, x, y, cb))
    bars = []
    for k in range(8):
        own = rd16(0x2848 + k * 2)
        if own:
            bars.append('%d:%04X c%04X %d,%d' % (k, own, rd16(0x2858 + k * 2), rd16(0x2868 + k * 2), rd16(0x2878 + k * 2)))
    line = 'E[%s] B[%s] seen%02X act%d bg%02X' % (' | '.join(ents), ' '.join(bars), rd16(0x2888), rd16(0x2846),
                                                   rd8(0x10805))   # game's BGMODE copy: 09 = HUD on BG3
    if line != last_line:
        log('f%d %s' % (fno, line))
        last_line = line
    return any((rd8(0x10000 + rd16(0x2040 + s * 2)) not in (0x00, 0x01)) for s in range(3, 16)
               if rd16(0x2040 + s * 2) and rd8(0x10000 + rd16(0x2040 + s * 2) + 1) == 2)


def run_frame():
    global fno
    for slot, v in keephate.items():
        rec = rd16(0x2040 + slot * 2)
        if rec and v:
            wr8(0x10000 + rec + 0x120, v)
    for k in keeprec:
        rec = rd16(0x2040 + k[0] * 2)
        if rec and k[3] != 0:
            for i, b in enumerate(k[2]):
                wr8(0x10000 + rec + k[1] + i, b)
            if k[3] > 0:
                k[3] -= 1
    lib.retro_run()
    fno += 1
    if lum_on:
        pressed = '+'.join(sorted(k for k, v in BUTTONS.items() if v in held)) or '-'
        LUM.write('%d %.1f %s' % (fno, frame_lum(), pressed) + chr(10))
    casting = frame_log()
    if stats_on:
        frame_stats()
    if every and fno % every == 0:
        png('f%05d' % fno)
    if castshots and casting and fno % castshots == 0:
        png('c%05d' % fno)


for step in STEPS:
    if step.startswith('shot:'):
        png(step[5:])
    elif step.startswith('save:'):
        save(step[5:])
    elif step.startswith('every:'):
        every = int(step[6:])
    elif step.startswith('castshots:'):
        castshots = int(step[10:])
    elif step.startswith('stats:'):
        stats_on = step[6:] == '1'
    elif step.startswith('lum:'):
        lum_on = step[4:] == '1'
        if lum_on and LUM is None:
            LUM = open(os.path.join(OUT, 'lum.txt'), 'w')
    elif step.startswith('keephate:'):
        slot, v = step[9:].split('=')
        keephate[int(slot)] = int(v)
    elif step.startswith('keeprec:'):
        where, v = step[8:].split('=')
        slot, off = where.split(':')
        n = -1
        if '@' in v:
            v, n = v.split('@')
            n = int(n)
        keeprec.append([int(slot), int(off, 16), bytes.fromhex(v), n])
    elif step.startswith('w') and step[1:].isdigit():
        held.clear()
        for _ in range(int(step[1:])):
            run_frame()
    else:
        keys, n = step.split(':')
        held.clear()
        held.update(BUTTONS[k] for k in keys.split('+'))
        for _ in range(int(n)):
            run_frame()
        held.clear()
if stats_on:
    log(stats_line())
log('done at frame %d' % fno)
if LUM:
    LUM.close()
