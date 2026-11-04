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


def env_cb(cmd, data):
    cmd &= 0xFFFF
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
        ents.append('s%d st%02X hp%d h%d o%04X %d,%d cb%d/%d' % (s, st, hp, hate, obj, x, y,
                    rd16(0x2800 + s * 4), rd16(0x2802 + s * 4)))
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
log('done at frame %d' % fno)
if LUM:
    LUM.close()
