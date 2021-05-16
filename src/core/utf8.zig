//Copyright © 2020-2021 Mehmet Kaan Uluç <kaanuluc@protonmail.com>
//
//This software is provided 'as-is', without any express or implied
//warranty. In no event will the authors be held liable for any damages
//arising from the use of this software.
//
//Permission is granted to anyone to use this software for any purpose,
//including commercial applications, and to alter it and redistribute it
//freely, subject to the following restrictions:
//
//1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would
//   be appreciated but is not required.
//
//2. Altered source versions must be plainly marked as such, and must not
//   be misrepresented as being the original software.
//
//3. This notice may not be removed or altered from any source
//   distribution.

const std = @import("std");

// source: https://github.com/raysan5/raylib/blob/cba412cc313e4f95eafb3fba9303400e65c98984/src/str.c#L1615
pub fn nextCodepoint(str: []const u8, bytesprocessed: *i32) i32 {
    var code: i32 = 0x3f; // codepoint (defaults to '?');
    var octet: i32 = @intCast(i32, str[0]); // the first UTF8 octet

    bytesprocessed.* = 1;

    if (octet <= 0x7f) {
        // Only one octet (ASCII range x00-7F)
        code = str[0];
    } else if ((octet & 0xe0) == 0xc0) {
        // Two octets
        // [0]xC2-DF    [1]UTF8-tail(x80-BF)
        var octet1 = str[1];

        if ((octet1 == 0) or ((octet1 >> 6) != 2)) {
            bytesprocessed.* = 2;
            return code;
        } // Unexpected sequence

        if ((octet >= 0xc2) and (octet <= 0xdf)) {
            code = ((octet & 0x1f) << 6) | (octet1 & 0x3f);
            bytesprocessed.* = 2;
        }
    } else if ((octet & 0xf0) == 0xe0) {
        // Three octets
        var octet1 = str[1];
        var octet2: u8 = 0;

        if ((octet1 == 0) or ((octet1 >> 6) != 2)) {
            bytesprocessed.* = 2;
            return code;
        } // Unexpected sequence

        octet2 = str[2];

        if ((octet2 == 0) or ((octet2 >> 6) != 2)) {
            bytesprocessed.* = 3;
            return code;
        } // Unexpected sequence

        //
        //  [0]xE0    [1]xA0-BF       [2]UTF8-tail(x80-BF)
        //  [0]xE1-EC [1]UTF8-tail    [2]UTF8-tail(x80-BF)
        //  [0]xED    [1]x80-9F       [2]UTF8-tail(x80-BF)
        //  [0]xEE-EF [1]UTF8-tail    [2]UTF8-tail(x80-BF)
        //

        if (((octet == 0xe0) and !((octet1 >= 0xa0) and (octet1 <= 0xbf))) or
            ((octet == 0xed) and !((octet1 >= 0x80) and (octet1 <= 0x9f))))
        {
            bytesprocessed.* = 2;
            return code;
        }

        if ((octet >= 0xe0) and (0 <= 0xef)) {
            code = ((octet & 0xf) << 12) | ((octet1 & 0x3f) << 6) | (octet2 & 0x3f);
            bytesprocessed.* = 3;
        }
    } else if ((octet & 0xf8) == 0xf0) {
        // Four octets
        if (octet > 0xf4)
            return code;

        var octet1 = str[1];
        var octet2: u8 = 0;
        var octet3: u8 = 0;

        if ((octet1 == 0) or ((octet1 >> 6) != 2)) {
            bytesprocessed.* = 2;
            return code;
        } // Unexpected sequence

        octet2 = str[2];

        if ((octet2 == 0) or ((octet2 >> 6) != 2)) {
            bytesprocessed.* = 3;
            return code;
        } // Unexpected sequence

        octet3 = str[3];

        if ((octet3 == 0) or ((octet3 >> 6) != 2)) {
            bytesprocessed.* = 4;
            return code;
        } // Unexpected sequence

        //
        //  [0]xF0       [1]x90-BF       [2]UTF8-tail  [3]UTF8-tail
        //  [0]xF1-F3    [1]UTF8-tail    [2]UTF8-tail  [3]UTF8-tail
        //  [0]xF4       [1]x80-8F       [2]UTF8-tail  [3]UTF8-tail
        //

        if (((octet == 0xf0) and !((octet1 >= 0x90) and (octet1 <= 0xbf))) or
            ((octet == 0xf4) and !((octet1 >= 0x80) and (octet1 <= 0x8f))))
        {
            bytesprocessed.* = 2;
            return code;
        } // Unexpected sequence

        if (octet >= 0xf0) {
            code = ((octet & 0x7) << 18) | ((octet1 & 0x3f) << @truncate(u3, 12)) |
                ((octet2 & 0x3f) << 6) | (octet3 & 0x3f);
            bytesprocessed.* = 4;
        }
    }

    // codepoints after U+10ffff are invalid
    if (code > 0x10ffff) code = 0x3f;

    return code;
}
