"""Tiny 65816 disassembler for an ExHiROM image.
usage: dis65816.py ROM SNESADDR(hex, e.g. 407979 or C0:1234) COUNT [m8|m16] [x8|x16]"""
import sys
T = """BRK i8|ORA (d,x)|COP i8|ORA s|TSB d|ORA d|ASL d|ORA [d]|PHP -|ORA iM|ASL A|PHD -|TSB a|ORA a|ASL a|ORA l|
BPL r|ORA (d),y|ORA (d)|ORA (s),y|TRB d|ORA d,x|ASL d,x|ORA [d],y|CLC -|ORA a,y|INC A|TCS -|TRB a|ORA a,x|ASL a,x|ORA l,x|
JSR a|AND (d,x)|JSL l|AND s|BIT d|AND d|ROL d|AND [d]|PLP -|AND iM|ROL A|PLD -|BIT a|AND a|ROL a|AND l|
BMI r|AND (d),y|AND (d)|AND (s),y|BIT d,x|AND d,x|ROL d,x|AND [d],y|SEC -|AND a,y|DEC A|TSC -|BIT a,x|AND a,x|ROL a,x|AND l,x|
RTI -|EOR (d,x)|WDM i8|EOR s|MVP mv|EOR d|LSR d|EOR [d]|PHA -|EOR iM|LSR A|PHK -|JMP a|EOR a|LSR a|EOR l|
BVC r|EOR (d),y|EOR (d)|EOR (s),y|MVN mv|EOR d,x|LSR d,x|EOR [d],y|CLI -|EOR a,y|PHY -|TCD -|JML l|EOR a,x|LSR a,x|EOR l,x|
RTS -|ADC (d,x)|PER R|ADC s|STZ d|ADC d|ROR d|ADC [d]|PLA -|ADC iM|ROR A|RTL -|JMP (a)|ADC a|ROR a|ADC l|
BVS r|ADC (d),y|ADC (d)|ADC (s),y|STZ d,x|ADC d,x|ROR d,x|ADC [d],y|SEI -|ADC a,y|PLY -|TDC -|JMP (a,x)|ADC a,x|ROR a,x|ADC l,x|
BRA r|STA (d,x)|BRL R|STA s|STY d|STA d|STX d|STA [d]|DEY -|BIT iM|TXA -|PHB -|STY a|STA a|STX a|STA l|
BCC r|STA (d),y|STA (d)|STA (s),y|STY d,x|STA d,x|STX d,y|STA [d],y|TYA -|STA a,y|TXS -|TXY -|STZ a|STA a,x|STZ a,x|STA l,x|
LDY iX|LDA (d,x)|LDX iX|LDA s|LDY d|LDA d|LDX d|LDA [d]|TAY -|LDA iM|TAX -|PLB -|LDY a|LDA a|LDX a|LDA l|
BCS r|LDA (d),y|LDA (d)|LDA (s),y|LDY d,x|LDA d,x|LDX d,y|LDA [d],y|CLV -|LDA a,y|TSX -|TYX -|LDY a,x|LDA a,x|LDX a,y|LDA l,x|
CPY iX|CMP (d,x)|REP i8|CMP s|CPY d|CMP d|DEC d|CMP [d]|INY -|CMP iM|DEX -|WAI -|CPY a|CMP a|DEC a|CMP l|
BNE r|CMP (d),y|CMP (d)|CMP (s),y|PEI (d)|CMP d,x|DEC d,x|CMP [d],y|CLD -|CMP a,y|PHX -|STP -|JML [a]|CMP a,x|DEC a,x|CMP l,x|
CPX iX|SBC (d,x)|SEP i8|SBC s|CPX d|SBC d|INC d|SBC [d]|INX -|SBC iM|NOP -|XBA -|CPX a|SBC a|INC a|SBC l|
BEQ r|SBC (d),y|SBC (d)|SBC (s),y|PEA a|SBC d,x|INC d,x|SBC [d],y|SED -|SBC a,y|PLX -|XCE -|JSR (a,x)|SBC a,x|INC a,x|SBC l,x"""
OPS = [e.strip() for e in T.replace('\n','').split('|')]
assert len(OPS)==256, len(OPS)

def snes2file(addr):
    b, a = addr >> 16, addr & 0xffff
    if 0xC0 <= b <= 0xFF: return (b-0xC0)<<16 | a
    if 0x40 <= b <= 0x7D: return 0x400000 + ((b-0x40)<<16 | a)
    if 0x80 <= b <= 0xBF and a >= 0x8000: return (b-0x80)<<16 | a
    if 0x00 <= b <= 0x3F and a >= 0x8000: return 0x400000 + (b<<16 | a)
    return None

def disasm(rom, pc, count, m8=True, x8=True, out=print):
    for _ in range(count):
        fo = snes2file(pc)
        if fo is None or fo >= len(rom): out(f'{pc:06X}  <unmapped>'); return
        op = rom[fo]; mn, _, mode = OPS[op].partition(' ')
        size = {'-':1,'A':1,'i8':2,'d':2,'(d,x)':2,'s':2,'[d]':2,'(d),y':2,'(d)':2,'(s),y':2,'d,x':2,'d,y':2,'[d],y':2,'r':2,
                'a':3,'a,x':3,'a,y':3,'(a)':3,'(a,x)':3,'[a]':3,'R':3,'mv':3,'l':4,'l,x':4}.get(mode)
        if mode=='iM': size = 2 if m8 else 3
        if mode=='iX': size = 2 if x8 else 3
        b = rom[fo:fo+size]; v = int.from_bytes(b[1:], 'little') if size>1 else 0
        if mode in ('-',): arg=''
        elif mode=='A': arg='A'
        elif mode in ('i8','iM','iX'): arg=f'#${v:0{2*(size-1)}X}'
        elif mode=='r': t=(pc+2+((v^0x80)-0x80))&0xffff|(pc&0xff0000); arg=f'${t:06X}'
        elif mode=='R': t=(pc+3+((v^0x8000)-0x8000))&0xffff|(pc&0xff0000); arg=f'${t:06X}'
        elif mode=='mv': arg=f'${b[2]:02X},${b[1]:02X}'
        elif mode=='s': arg=f'${v:02X},S'
        elif mode=='(s),y': arg=f'(${v:02X},S),Y'
        else:
            w = 2 if mode[1:2]=='d' or mode.startswith('d') or mode.startswith('[d') or mode.startswith('(d') else (6 if mode.startswith('l') else 4)
            core = f'${v:0{w}X}'
            arg = mode.replace('d', core, 1) if 'd' in mode and w==2 else mode.replace('a', core, 1) if 'a' in mode else mode.replace('l', core, 1)
            arg = arg.replace(',x', ',X').replace(',y', ',Y')
        if mn=='REP': m8 = m8 and not (v&0x20); x8 = x8 and not (v&0x10)
        if mn=='SEP': m8 = m8 or bool(v&0x20); x8 = x8 or bool(v&0x10)
        flags = ('m' if m8 else 'M') + ('x' if x8 else 'X')
        out(f'{pc:06X} {fo:06X} {flags} {b.hex(" "):<12} {mn} {arg}')
        pc = (pc & 0xff0000) | ((pc + size) & 0xffff)

if __name__ == '__main__':
    rom = open(sys.argv[1],'rb').read()
    pc = int(sys.argv[2].replace(':',''),16); n = int(sys.argv[3])
    m8 = 'm16' not in sys.argv; x8 = 'x16' not in sys.argv
    disasm(rom, pc, n, m8, x8)
