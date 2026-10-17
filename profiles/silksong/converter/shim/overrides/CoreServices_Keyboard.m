// Minimal fixed US virtual-key translator for our private layout token.
// No Option combinations, dead keys, localization, or arbitrary uchr parsing.
#import <Foundation/Foundation.h>
#include <string.h>
struct UCKeyboardLayout;

__attribute__((visibility("default"))) int32_t UCKeyTranslate(
    const struct UCKeyboardLayout *layout, uint16_t key, uint16_t action, uint32_t modifiers,
    uint32_t keyboardType, uint32_t options, uint32_t *deadState,
    unsigned long capacity, unsigned long *length, uint16_t *output) {
    (void)keyboardType; (void)options;
    if (length) *length = 0;
    if (!layout || !length || !output || !deadState || key >= 128 || action > 3) return -50;
    if (memcmp(layout, "JSAB-US-KEYBOARD-v1", sizeof("JSAB-US-KEYBOARD-v1"))) return -50;
    *deadState = 0;
    // Unsupported Option/Control combinations fail explicitly.
    if (modifiers & (8u | 16u)) return -50;
    static const uint16_t plain[128] = {
        [0]='a',[1]='s',[2]='d',[3]='f',[4]='h',[5]='g',[6]='z',[7]='x',[8]='c',[9]='v',
        [11]='b',[12]='q',[13]='w',[14]='e',[15]='r',[16]='y',[17]='t',
        [18]='1',[19]='2',[20]='3',[21]='4',[22]='6',[23]='5',[24]='=',[25]='9',[26]='7',[27]='-',
        [28]='8',[29]='0',[30]=']',[31]='o',[32]='u',[33]='[',[34]='i',[35]='p',[36]='\r',
        [37]='l',[38]='j',[39]='\'',[40]='k',[41]=';',[42]='\\',[43]=',',[44]='/',[45]='n',[46]='m',
        [47]='.',[48]='\t',[49]=' ',[50]='`',[51]=8,[53]=27,
        [65]='.',[67]='*',[69]='+',[75]='/',[76]=3,[78]='-',[81]='=',
        [82]='0',[83]='1',[84]='2',[85]='3',[86]='4',[87]='5',[88]='6',[89]='7',[91]='8',[92]='9',
        [117]=127,[123]=0xf702,[124]=0xf703,[125]=0xf701,[126]=0xf700
    };
    uint16_t ch = plain[key];
    BOOL shift = (modifiers & 2u) != 0, caps = (modifiers & 4u) != 0;
    if (ch >= 'a' && ch <= 'z') { if (shift != caps) ch -= 'a' - 'A'; }
    else if (shift && key < 65) {
        const char *from = "1234567890=-[];'\\,./`";
        const char *to   = "!@#$%^&*()_+{}:\"|<>?~";
        const char *at = ch && ch < 128 ? strchr(from, (char)ch) : NULL;
        if (at) ch = (uint16_t)to[at - from];
    }
    if (!ch) return 0;
    if (!capacity) return -25340;
    output[0] = ch;
    *length = 1;
    return 0;
}
